/**
 * RadioKitWiFi.cpp
 * WiFi transport implementation for RadioKit.
 *
 * Architecture:
 *   - WebSocket server on port 5555 (always the same port in AP and STA modes)
 *   - Type-byte prefix appended to every binary WebSocket frame
 *   - mDNS advertising as _radiokit._tcp
 *   - AP mode fallback when STA unavailable, with background retry every 60s
 *
 * Requires ESP32 + arduinoWebSockets library.
 */

#include "RadioKitWiFi.h"
#include "../RadioKitProtocol.h"
#include "../RadioKitConfig.h"
#include "RadioKitFS.h"
#include "RadioKitOTA.h"
#include "RadioKitSettings.h"
#include <string.h>

RadioKitWiFi RadioKitWiFiInstance;

// ── Timing constants ──────────────────────────────────────────────────────────
#define RK_WIFI_TIMEOUT_MS       5000     // 5s no packet → disconnected
#define RK_WIFI_STA_TIMEOUT_MS   15000    // 15s STA connection timeout
#define RK_WIFI_STA_RETRY_MS     60000    // Retry STA every 60s in AP mode
#define RK_WIFI_WS_PORT          5555     // WebSocket server port

// ── Framed send buffer (type byte + max frame) ────────────────────────────────
// Max FS payload is 16384. Add 1 type byte + 3 bytes margin.
#define RK_WIFI_FRAMED_BUF_SIZE  16388

RadioKitWiFi::RadioKitWiFi()
    : _apMode(false)
    , _wsConnected(false)
    , _lastPacketMs(0)
    , _lastStaRetryMs(0)
    , _connPwd(nullptr)
#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)
    , _server(nullptr)
#endif
{
    _packetCb = nullptr;
    _fsCb = nullptr;
    _otaCb = nullptr;
    _settingsCb = nullptr;
    memset(_deviceName, 0, sizeof(_deviceName));
    memset(_staSsid, 0, sizeof(_staSsid));
    memset(_staPwd, 0, sizeof(_staPwd));
    memset(_localIpBuf, 0, sizeof(_localIpBuf));
}

void RadioKitWiFi::setCredentials(const char* staSsid, const char* staPassword) {
    if (staSsid) {
        strncpy(_staSsid, staSsid, sizeof(_staSsid) - 1);
    }
    if (staPassword) {
        strncpy(_staPwd, staPassword, sizeof(_staPwd) - 1);
    }
}

void RadioKitWiFi::setApPassword(const char* pwd) {
    _connPwd = pwd;
}

void RadioKitWiFi::begin(const char* name, RK_PacketCallback cb) {
    _packetCb = cb;

    // Cache device name for mDNS
    if (name) {
        strncpy(_deviceName, name, sizeof(_deviceName) - 1);
    }

#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)
    // Determine mode based on STA credentials
    if (_staSsid[0] != '\0') {
        // Try STA first
        Serial.printf("WiFi: Attempting STA connection to '%s'...\n", _staSsid);
        WiFi.mode(WIFI_STA);
        if (_connectSta(_staSsid, _staPwd)) {
            // STA connected — start WebSocket server
            _apMode = false;
            _server = new WebSocketsServer(RK_WIFI_WS_PORT);
            _server->begin();
            _server->onEvent([this](uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
                _onWsEvent(num, type, payload, length);
            });
            _initMdns("sta");
            Serial.printf("WiFi: STA connected, WebSocket server on %s:%d\n",
                WiFi.localIP().toString().c_str(), RK_WIFI_WS_PORT);
            return;
        }
        // STA failed — fall through to AP mode with background retry
        Serial.println("WiFi: STA connection failed — starting AP mode with background retry");
    }

    // AP mode
    _startAp();
#else
    (void)cb;
    Serial.println("WiFi: Transport not available on this platform");
#endif
}

void RadioKitWiFi::setFsCallback(RK_FsPacketCallback cb) {
    _fsCb = cb;
}

void RadioKitWiFi::setOtaCallback(RK_OtaPacketCallback cb) {
    _otaCb = cb;
}

void RadioKitWiFi::setSettingsCallback(RK_SettingsPacketCallback cb) {
    _settingsCb = cb;
}

#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)

void RadioKitWiFi::_startAp() {
    // AP SSID: "RK_<device_name>" truncated to 32 chars
    char apSsid[33];
    snprintf(apSsid, sizeof(apSsid), "RK_%s", _deviceName);
    apSsid[32] = '\0';

    if (_connPwd && strlen(_connPwd) >= 8) {
        WiFi.softAP(apSsid, _connPwd);   // WPA2
        Serial.printf("WiFi: AP started — SSID='%s' (WPA2)\n", apSsid);
    } else {
        WiFi.softAP(apSsid);             // OPEN
        Serial.printf("WiFi: AP started — SSID='%s' (OPEN — no password or < 8 chars)\n", apSsid);
    }

    _apMode = true;
    WiFi.mode(WIFI_AP_STA);  // AP + background STA retry

    // Start WebSocket server
    _server = new WebSocketsServer(RK_WIFI_WS_PORT);
    _server->begin();
    _server->onEvent([this](uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
        _onWsEvent(num, type, payload, length);
    });

    _initMdns("ap");
}

bool RadioKitWiFi::_connectSta(const char* ssid, const char* password) {
    WiFi.begin(ssid, password);
    unsigned long start = millis();
    while (millis() - start < RK_WIFI_STA_TIMEOUT_MS) {
        if (WiFi.status() == WL_CONNECTED) {
            return true;
        }
        delay(100);
    }
    return false;
}

void RadioKitWiFi::_initMdns(const char* mode) {
    MDNS.end();
    if (MDNS.begin("radiokit")) {
        MDNS.addService("_radiokit", "_tcp", RK_WIFI_WS_PORT);
        MDNS.addServiceTxt(String("_radiokit"), String("_tcp"), String("name"), String(_deviceName));
        MDNS.addServiceTxt(String("_radiokit"), String("_tcp"), String("mode"), String(mode));

        String ipStr = _apMode ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
        MDNS.addServiceTxt(String("_radiokit"), String("_tcp"), String("ip"), ipStr);
    }
}

void RadioKitWiFi::_onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
    (void)num;

    switch (type) {
        case WStype_DISCONNECTED:
            _wsConnected = false;
            _lastPacketMs = 0;
            rk_rxReset();
            rk_fsRxReset();
            rk_otaRxReset();
            rk_settingsRxReset();
            Serial.println("WiFi: WebSocket client disconnected");
            break;

        case WStype_CONNECTED:
            _wsConnected = true;
            _lastPacketMs = millis();
            Serial.println("WiFi: WebSocket client connected");
            break;

        case WStype_BIN:
            _lastPacketMs = millis();
            _feedBytes(payload, length);
            break;

        case WStype_TEXT:
            break;

        default:
            break;
    }
}

void RadioKitWiFi::_feedBytes(const uint8_t* data, size_t len) {
    if (len < 1) return;

    uint8_t protocolType = data[0];
    const uint8_t* frameData = data + 1;
    size_t frameLen = len - 1;

    switch (protocolType) {
        case RK_START_BYTE: { // 0x55
            uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_rxFeedByte(frameData[i], cmd, payload, payloadLen)) {
                    if (_packetCb) _packetCb(cmd, payload, payloadLen);
                }
            }
            break;
        }
        case RK_FS_START_BYTE: { // 0xAA
            uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_fsRxFeedByte(frameData[i], subCmd, payload, payloadLen)) {
                    if (_fsCb) _fsCb(subCmd, payload, payloadLen);
                }
            }
            break;
        }
        case RK_OTA_START_BYTE: { // 0xBB
            uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_otaRxFeedByte(frameData[i], subCmd, payload, payloadLen)) {
                    if (_otaCb) _otaCb(subCmd, payload, payloadLen);
                }
            }
            break;
        }
        case RK_SETTINGS_START_BYTE: { // 0xDD
            uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_settingsRxFeedByte(frameData[i], subCmd, payload, payloadLen)) {
                    if (_settingsCb) _settingsCb(subCmd, payload, payloadLen);
                }
            }
            break;
        }
        default:
            break;
    }
}

void RadioKitWiFi::update() {
    if (_server) _server->loop();

    // Background STA retry (AP mode only, keep AP active)
    if (_apMode && _staSsid[0] != '\0') {
        unsigned long now = millis();
        if (now - _lastStaRetryMs > RK_WIFI_STA_RETRY_MS) {
            _lastStaRetryMs = now;

            Serial.printf("WiFi: Retrying STA connection to '%s'...\n", _staSsid);
            WiFi.mode(WIFI_AP_STA);

            if (_connectSta(_staSsid, _staPwd)) {
                WiFi.softAPdisconnect(true);
                WiFi.mode(WIFI_STA);
                _initMdns("sta");
                _apMode = false;
                Serial.printf("WiFi: STA connected after retry, IP=%s\n",
                    WiFi.localIP().toString().c_str());
            }
        }
    }
}

void RadioKitWiFi::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_wsConnected) return;

    // Cap total framed size to prevent stack overflow
    if (len + 1 > RK_WIFI_FRAMED_BUF_SIZE) {
        len = RK_WIFI_FRAMED_BUF_SIZE - 1;
    }

    // Determine type byte from the frame's start byte
    uint8_t typeByte;
    if (buf[0] == RK_FS_START_BYTE) {
        typeByte = RK_FS_START_BYTE;
    } else if (buf[0] == RK_OTA_START_BYTE) {
        typeByte = RK_OTA_START_BYTE;
    } else if (buf[0] == RK_SETTINGS_START_BYTE) {
        typeByte = RK_SETTINGS_START_BYTE;
    } else {
        typeByte = RK_START_BYTE;
    }

    // Build framed message: [type(1)][original_frame] in pre-allocated buffer
    _framedBuf[0] = typeByte;
    memcpy(_framedBuf + 1, buf, len);

    if (_server) _server->broadcastBIN(_framedBuf, 1 + len);
}

bool RadioKitWiFi::isConnected() const {
    return _wsConnected && (millis() - _lastPacketMs) < RK_WIFI_TIMEOUT_MS;
}

int8_t RadioKitWiFi::getRssi() {
    if (_apMode) return 0;
    return WiFi.RSSI();
}

const char* RadioKitWiFi::getLocalIp() const {
    if (_apMode) {
        snprintf(_localIpBuf, sizeof(_localIpBuf), "%s",
                 WiFi.softAPIP().toString().c_str());
    } else {
        snprintf(_localIpBuf, sizeof(_localIpBuf), "%s",
                 WiFi.localIP().toString().c_str());
    }
    return _localIpBuf;
}

#else // !ESP32 or !RADIOKIT_ENABLE_WIFI

void RadioKitWiFi::update() {}
void RadioKitWiFi::sendPacket(const uint8_t* buf, uint16_t len) { (void)buf; (void)len; }
bool RadioKitWiFi::isConnected() const { return false; }
int8_t RadioKitWiFi::getRssi() { return 0; }
const char* RadioKitWiFi::getLocalIp() const { return "0.0.0.0"; }

#endif // ESP32 && RADIOKIT_ENABLE_WIFI
