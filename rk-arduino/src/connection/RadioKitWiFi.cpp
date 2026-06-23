/**
 * RadioKitWiFi.cpp
 * WiFi transport implementation for RadioKit.
 *
 * Architecture:
 *   - WebSocket server on port 5555 (always the same port in AP and STA modes)
 *   - AP mode: always open (no WPA2). Auth via PWD_AUTH protocol within 30s.
 *   - Type-byte prefix appended to every binary WebSocket frame
 *   - mDNS advertising as _radiokit._tcp
 *   - AP mode fallback when STA unavailable, with background retry every 60s
 *   - Per-client auth tracking: each WS client must auth within 30s or be disconnected
 *
 * Requires ESP32 + arduinoWebSockets library.
 */

#include "RadioKitWiFi.h"
#include "../RadioKitProtocol.h"
#include "../RadioKitConfig.h"
#include "../RadioKitLib.h"
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
    , _lastStaRetryMs(0)
#if defined(RK_ENABLE_WIFI)
    , _server(nullptr)
    , _activeClientCount(0)
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
#if defined(RK_ENABLE_WIFI)
    for (int i = 0; i < RK_WIFI_MAX_CLIENTS; i++) {
        _clients[i].active = false;
        _clients[i].connectTime = 0;
        _clients[i].authLevel = RK_WIFI_AUTH_NONE;
    }
#endif
}

void RadioKitWiFi::setCredentials(const char* staSsid, const char* staPassword) {
    if (staSsid) {
        strncpy(_staSsid, staSsid, sizeof(_staSsid) - 1);
    }
    if (staPassword) {
        strncpy(_staPwd, staPassword, sizeof(_staPwd) - 1);
    }
}

void RadioKitWiFi::begin(const char* name, RK_PacketCallback cb) {
    _packetCb = cb;

    // Cache device name for mDNS
    if (name) {
        strncpy(_deviceName, name, sizeof(_deviceName) - 1);
    }

#if defined(RK_ENABLE_WIFI)
    // Determine mode based on STA credentials
    if (_staSsid[0] != '\0') {
        // Try STA first
        RadioKit.printf("WiFi: Attempting STA connection to '%s'...\n", _staSsid);
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
            RadioKit.printf("WiFi: STA connected, WebSocket server on %s:%d\n",
                WiFi.localIP().toString().c_str(), RK_WIFI_WS_PORT);
            Serial.printf("WiFi: STA connected, WebSocket server on %s:%d\n",
                WiFi.localIP().toString().c_str(), RK_WIFI_WS_PORT);
            return;
        }
        // STA failed — fall through to AP mode with background retry
        RadioKit.print("WiFi: STA connection failed — starting AP mode with background retry\n");
        Serial.println("WiFi: STA connection failed — starting AP mode with background retry");
    }

    // AP mode
    _startAp();
#else
    (void)cb;
    RadioKit.print("WiFi: Transport not available on this platform\n");
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

void RadioKitWiFi::setPrintCallback(RK_PrintPacketCallback cb) {
    _printCb = cb;
}

#if defined(RK_ENABLE_WIFI)

uint8_t RadioKitWiFi::getClientAuthLevel(uint8_t clientNum) const {
    if (clientNum >= RK_WIFI_MAX_CLIENTS) return 0;
    return _clients[clientNum].authLevel;
}


void RadioKitWiFi::_startAp() {
    // AP SSID: "RK_<device_name>" truncated to 32 chars
    char apSsid[33];
    snprintf(apSsid, sizeof(apSsid), "RK_%s", _deviceName);
    apSsid[32] = '\0';

    // ALWAYS open AP — no WPA2 password. Auth is done via PWD_AUTH protocol
    // at the WebSocket level (0xDD settings channel, sub-command 0x06).
    // Clients have 30 seconds to authenticate or they are disconnected.
    WiFi.softAP(apSsid);
    RadioKit.printf("WiFi: AP started — SSID='%s' (OPEN — auth via PWD_AUTH)\n", apSsid);
    Serial.printf("WiFi: AP started — SSID='%s' (OPEN — auth via PWD_AUTH)\n", apSsid);

    _apMode = true;
    WiFi.mode(WIFI_AP_STA);  // AP + background STA retry

    // Reset per-client auth state
    for (int i = 0; i < RK_WIFI_MAX_CLIENTS; i++) {
        _clients[i].active = false;
        _clients[i].connectTime = 0;
        _clients[i].authLevel = RK_WIFI_AUTH_NONE;
    }
    _activeClientCount = 0;

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
    unsigned long lastPrint = 0;
    while (millis() - start < RK_WIFI_STA_TIMEOUT_MS) {
        if (WiFi.status() == WL_CONNECTED) {
            return true;
        }
        if (millis() - lastPrint > 1000) {
            lastPrint = millis();
            Serial.printf("WiFi: status=%d\n", WiFi.status());
        }
        delay(100);
    }
    Serial.printf("WiFi: STA connection timeout. Final status=%d\n", WiFi.status());
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
    switch (type) {
        case WStype_DISCONNECTED:
            if (num < RK_WIFI_MAX_CLIENTS) {
                _clients[num].active = false;
                _clients[num].connectTime = 0;
                _clients[num].authLevel = RK_WIFI_AUTH_NONE;
                _activeClientCount--;
                if (_activeClientCount < 0) _activeClientCount = 0;
            }
            RadioKit.printf("WiFi: WebSocket client %d disconnected\n", num);
            Serial.printf("WiFi: WebSocket client %d disconnected\n", num);
            break;

        case WStype_CONNECTED:
            if (num < RK_WIFI_MAX_CLIENTS) {
                if (!_clients[num].active) {
                    _activeClientCount++;
                }
                _clients[num].active = true;
                _clients[num].connectTime = millis();
                // Pre-authenticate if no password is set on the device
                if (RadioKit.hasFullAccess()) {
                    _clients[num].authLevel = RK_WIFI_AUTH_DEVICE;
                } else {
                    _clients[num].authLevel = RK_WIFI_AUTH_NONE;
                }
            }
            if (_clients[num].authLevel == RK_WIFI_AUTH_DEVICE) {
                RadioKit.printf("WiFi: WebSocket client %d connected (pre-authenticated)\n", num);
                Serial.printf("WiFi: WebSocket client %d connected (pre-authenticated)\n", num);
            } else {
                RadioKit.printf("WiFi: WebSocket client %d connected (auth required)\n", num);
                Serial.printf("WiFi: WebSocket client %d connected (auth required)\n", num);
            }
            break;

        case WStype_BIN:
            // Update client's last activity for auth timeout tracking
            if (num < RK_WIFI_MAX_CLIENTS) {
                _clients[num].connectTime = millis();  // refresh for keep-alive
            }
            _feedBytes(num, payload, length);
            break;

        case WStype_TEXT:
            break;

        default:
            break;
    }
}

void RadioKitWiFi::_feedBytes(uint8_t clientNum, const uint8_t* data, size_t len) {
    if (len < 1) return;

    uint8_t protocolType = data[0];
    const uint8_t* frameData = data + 1;
    size_t frameLen = len - 1;

    // ── PWD_AUTH interception for per-client auth tracking ──────────────
    // Intercept 0xDD frames with sub-command PWD_AUTH (0x06) so we can
    // track which client authenticated at what level. The actual auth
    // logic is still handled by RadioKitClass via _settingsCb, but we
    // need to capture the response to update per-client state.
    //
    // Frame format: [0xDD][SUB_CMD][LEN_LO][LEN_HI][PAYLOAD...]
    // frameData starts at the 0xDD start byte.
    if (protocolType == RK_SETTINGS_START_BYTE && frameLen >= 2) {
        uint8_t subCmd = (frameLen >= 2) ? frameData[1] : 0;

        if (subCmd == RK_SETTINGS_CMD_PWD_AUTH) {
            if (frameLen >= 5) {
                // frameData[0]=0xDD, [1]=SUB_CMD, [2]=LEN_LO, [3]=LEN_HI, [4..]=PAYLOAD
                uint16_t payloadLen = (uint16_t)frameData[2] | ((uint16_t)frameData[3] << 8);
                const uint8_t* settingsPayload = frameData + 4;
                uint16_t settingsPayloadLen = payloadLen - RK_SETTINGS_HEADER_SIZE;

                if (settingsPayloadLen >= 1) {
                    uint8_t pwdLen = settingsPayload[0];
                    if (pwdLen <= RADIOKIT_MAX_PWD && settingsPayloadLen >= 1 + pwdLen) {
                        char pwdBuf[RADIOKIT_MAX_PWD + 1];
                        memcpy(pwdBuf, &settingsPayload[1], pwdLen);
                        pwdBuf[pwdLen] = '\0';

                        uint8_t authResult = RadioKit.authenticate(pwdBuf);

                        // Track per-client auth level
                        if (clientNum < RK_WIFI_MAX_CLIENTS) {
                            if (authResult == RK_PWD_AUTH_DEVICE) {
                                _clients[clientNum].authLevel = RK_WIFI_AUTH_DEVICE;
                                _clients[clientNum].connectTime = millis();
                            } else if (authResult == RK_PWD_AUTH_USER) {
                                _clients[clientNum].authLevel = RK_WIFI_AUTH_USER;
                                _clients[clientNum].connectTime = millis();
                            }
                        }

                        uint8_t respSub = RK_SETTINGS_RESP_PWD_AUTH_ACK;
                        uint8_t respPayload = authResult;
                        uint16_t respLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
                            respSub, &respPayload, 1);
                        _sendToClient(clientNum, rk_settingsTxBuf(), respLen);

                        RadioKit.printf("WiFi: Client %d PWD_AUTH result=0x%02X\n", clientNum, authResult);
                        Serial.printf("WiFi: Client %d PWD_AUTH result=0x%02X\n", clientNum, authResult);
                        return;
                    }
                }
            }
            uint8_t status = RK_SETTINGS_PWD_DENIED;
            uint16_t frameLen2 = rk_settingsBuildFrame(rk_settingsTxBuf(),
                RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
            _sendToClient(clientNum, rk_settingsTxBuf(), frameLen2);
            return;
        }

        // For non-PWD_AUTH settings frames, check per-client auth
        if (subCmd != RK_SETTINGS_CMD_GET_FEATURES &&
            subCmd != RK_SETTINGS_CMD_GET_DEVICE_INFO &&
            subCmd != RK_SETTINGS_CMD_GET_TELEMETRY &&
            subCmd != RK_SETTINGS_CMD_BLE_INFO &&
            subCmd != RK_SETTINGS_CMD_GET_CHIP_INFO &&
            subCmd != RK_SETTINGS_CMD_PWD_AUTH) {
            if (clientNum >= RK_WIFI_MAX_CLIENTS || _clients[clientNum].authLevel == RK_WIFI_AUTH_NONE) {
                uint8_t status = RK_SETTINGS_PWD_DENIED;
                uint16_t frameLen2 = rk_settingsBuildFrame(rk_settingsTxBuf(),
                    RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
                _sendToClient(clientNum, rk_settingsTxBuf(), frameLen2);
                return;
            }
        }

        if (_settingsCb) {
            uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_settingsRxFeedByte(frameData[i], cmd, payload, payloadLen)) {
                    _settingsCb(cmd, payload, payloadLen);
                }
            }
        }
        return;
    }

    // ── Widget protocol (0x55/0xEE) ────────────────────────────────────
    // Widget frames are forwarded regardless of auth level. The global
    // _onPacket handler enforces auth for non-GET_CONF commands.
    if (protocolType == RK_START_BYTE) {
        uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
        for (size_t i = 0; i < frameLen; i++) {
            if (rk_rxFeedByte(frameData[i], cmd, payload, payloadLen)) {
                if (_packetCb) _packetCb(cmd, payload, payloadLen);
            }
        }
        return;
    }

    // ── Print protocol (0xEE) — unidirectional, no auth needed ──────────
    // The app never sends 0xEE frames to the device, but we handle it
    // silently to avoid orphan bytes confusing the parser.
    if (protocolType == RK_PRINT_START_BYTE) {
        const uint8_t* payload; uint16_t payloadLen;
        for (size_t i = 0; i < frameLen; i++) {
            if (rk_printRxFeedByte(frameData[i], payload, payloadLen)) {
                if (_printCb) _printCb(payload, payloadLen);
            }
        }
        return;
    }

    // ── FS protocol (0xAA) — requires device-level auth ─────────────────
    if (protocolType == RK_FS_START_BYTE) {
        if (clientNum < RK_WIFI_MAX_CLIENTS && _clients[clientNum].authLevel < RK_WIFI_AUTH_DEVICE) {
            uint8_t err = RK_FS_ERR_ACCESS_DENIED;
            uint8_t ackResp = 0x80;
            uint16_t frameLen2 = rk_fsBuildFrame(rk_fsTxBuf(), ackResp, &err, 1);
            _sendToClient(clientNum, rk_fsTxBuf(), frameLen2);
            return;
        }
        uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
        for (size_t i = 0; i < frameLen; i++) {
            if (rk_fsRxFeedByte(frameData[i], subCmd, payload, payloadLen)) {
                if (_fsCb) _fsCb(subCmd, payload, payloadLen);
            }
        }
        return;
    }

    // ── OTA protocol (0xBB) — requires device-level auth ────────────────
    if (protocolType == RK_OTA_START_BYTE) {
        if (clientNum < RK_WIFI_MAX_CLIENTS && _clients[clientNum].authLevel < RK_WIFI_AUTH_DEVICE) {
            uint8_t err = RK_OTA_ERR_INVALID_STATE;
            uint16_t frameLen2 = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
            _sendToClient(clientNum, rk_otaTxBuf(), frameLen2);
            return;
        }
        uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
        for (size_t i = 0; i < frameLen; i++) {
            if (rk_otaRxFeedByte(frameData[i], subCmd, payload, payloadLen)) {
                if (_otaCb) _otaCb(subCmd, payload, payloadLen);
            }
        }
        return;
    }
}

void RadioKitWiFi::update() {
    if (_server) _server->loop();

    unsigned long now = millis();

    // ── Per-client auth timeout ─────────────────────────────────────────
    for (int i = 0; i < RK_WIFI_MAX_CLIENTS; i++) {
        if (_clients[i].active && _clients[i].authLevel == RK_WIFI_AUTH_NONE) {
            unsigned long elapsed = now - _clients[i].connectTime;
            if (elapsed > RK_WIFI_AUTH_TIMEOUT_MS) {
                RadioKit.printf("WiFi: Client %d auth timeout (%lu ms) — disconnecting\n",
                    i, elapsed);
                Serial.printf("WiFi: Client %d auth timeout (%lu ms) — disconnecting\n",
                    i, elapsed);
                _disconnectClient(i);
            }
        }
    }

    // Background STA retry (AP mode only, keep AP active)
    if (_apMode && _staSsid[0] != '\0') {
        if (now - _lastStaRetryMs > RK_WIFI_STA_RETRY_MS) {
            _lastStaRetryMs = now;

            RadioKit.printf("WiFi: Retrying STA connection to '%s'...\n", _staSsid);
            Serial.printf("WiFi: Retrying STA connection to '%s'...\n", _staSsid);
            WiFi.mode(WIFI_AP_STA);

            if (_connectSta(_staSsid, _staPwd)) {
                WiFi.softAPdisconnect(true);
                WiFi.mode(WIFI_STA);
                _initMdns("sta");
                _apMode = false;
                RadioKit.printf("WiFi: STA connected after retry, IP=%s\n",
                    WiFi.localIP().toString().c_str());
                Serial.printf("WiFi: STA connected after retry, IP=%s\n",
                    WiFi.localIP().toString().c_str());
            }
        }
    }
}

void RadioKitWiFi::_sendToClient(uint8_t clientNum, const uint8_t* buf, uint16_t len) {
    if (!_server) return;
    if (clientNum >= RK_WIFI_MAX_CLIENTS) return;
    if (!_clients[clientNum].active) return;

    if (len + 1 > RK_WIFI_FRAMED_BUF_SIZE) {
        len = RK_WIFI_FRAMED_BUF_SIZE - 1;
    }

    uint8_t typeByte;
    if (buf[0] == RK_FS_START_BYTE) {
        typeByte = RK_FS_START_BYTE;
    } else if (buf[0] == RK_OTA_START_BYTE) {
        typeByte = RK_OTA_START_BYTE;
    } else if (buf[0] == RK_SETTINGS_START_BYTE) {
        typeByte = RK_SETTINGS_START_BYTE;
    } else if (buf[0] == RK_PRINT_START_BYTE) {
        typeByte = RK_PRINT_START_BYTE;
    } else {
        typeByte = RK_START_BYTE;
    }

    _framedBuf[0] = typeByte;
    memcpy(_framedBuf + 1, buf, len);

    _server->sendBIN(clientNum, _framedBuf, 1 + len);
}

void RadioKitWiFi::_disconnectClient(uint8_t clientNum) {
    if (!_server) return;
    if (clientNum >= RK_WIFI_MAX_CLIENTS) return;

    _server->disconnect(clientNum);

    if (_clients[clientNum].active) {
        _clients[clientNum].active = false;
        _clients[clientNum].connectTime = 0;
        _clients[clientNum].authLevel = RK_WIFI_AUTH_NONE;
        _activeClientCount--;
        if (_activeClientCount < 0) _activeClientCount = 0;
    }
}

void RadioKitWiFi::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_server) return;

    // Cap total framed size
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

    // Broadcast to all active, authenticated clients
    for (int i = 0; i < RK_WIFI_MAX_CLIENTS; i++) {
        if (_clients[i].active) {
            _server->sendBIN(i, _framedBuf, 1 + len);
        }
    }
}

bool RadioKitWiFi::isConnected() const {
    // Consider connected if any client is active and authenticated
    for (int i = 0; i < RK_WIFI_MAX_CLIENTS; i++) {
        if (_clients[i].active && _clients[i].authLevel != RK_WIFI_AUTH_NONE) {
            return true;
        }
    }
    return false;
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

#else // !defined(RK_ENABLE_WIFI)

void RadioKitWiFi::update() {}
void RadioKitWiFi::sendPacket(const uint8_t* buf, uint16_t len) { (void)buf; (void)len; }
bool RadioKitWiFi::isConnected() const { return false; }
int8_t RadioKitWiFi::getRssi() { return 0; }
const char* RadioKitWiFi::getLocalIp() const { return "0.0.0.0"; }
uint8_t RadioKitWiFi::getClientAuthLevel(uint8_t clientNum) const { (void)clientNum; return 0; }

#endif // defined(RK_ENABLE_WIFI)
