/**
 * RadioKitCloud.cpp
 * Cloud relay transport implementation for RadioKit.
 *
 * Architecture:
 *   - Outbound WebSocket client (WSS/WS) to relay server
 *   - Type-byte prefix on every binary frame (same as RadioKitWiFi)
 *   - JSON control messages for registration and heartbeat
 *   - Exponential backoff reconnect (1s → 60s max)
 *   - Heartbeat ping every 30s
 *
 * Requires ESP32 + arduinoWebSockets library.
 * Guarded by: #if defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)
 */

#include "RadioKitCloud.h"
#include "../RadioKitProtocol.h"
#include "../RadioKitConfig.h"
#include "../RadioKitLib.h"
#include "RadioKitFS.h"
#include "RadioKitOTA.h"
#include "RadioKitSettings.h"
#include <string.h>

RadioKitCloud RadioKitCloudInstance;

// ── Timing constants ──────────────────────────────────────────────────────────
#define RK_CLOUD_TIMEOUT_MS       15000    // 15s no packet → disconnected
#define RK_CLOUD_PING_INTERVAL_MS 30000    // Heartbeat ping every 30s
#define RK_CLOUD_RECONNECT_MIN    1        // Initial reconnect delay (seconds)
#define RK_CLOUD_RECONNECT_MAX    60       // Max reconnect delay (seconds)

// ── Framed send buffer ────────────────────────────────────────────────────────
#define RK_CLOUD_FRAMED_BUF_SIZE  16388

RadioKitCloud::RadioKitCloud()
    : _registered(false)
    , _lastPingMs(0)
    , _lastReconnectMs(0)
    , _reconnectDelaySec(RK_CLOUD_RECONNECT_MIN)
    , _wsConnected(false)
    , _lastPacketMs(0)
{
    _packetCb = nullptr;
    _fsCb = nullptr;
    _otaCb = nullptr;
    _settingsCb = nullptr;
    memset(_host, 0, sizeof(_host));
    memset(_account, 0, sizeof(_account));
    memset(_deviceName, 0, sizeof(_deviceName));
    _port = 443;
}

void RadioKitCloud::setCloudUrl(const char* url) {
    if (!url || url[0] == '\0') return;

    // Parse: "host:port" or "wss://host:port" or "ws://host:port"
    const char* protocol = strstr(url, "://");
    const char* start = protocol ? protocol + 3 : url;

    const char* colon = strchr(start, ':');
    if (colon) {
        size_t hostLen = colon - start;
        if (hostLen > sizeof(_host) - 1) hostLen = sizeof(_host) - 1;
        memcpy(_host, start, hostLen);
        _host[hostLen] = '\0';
        _port = (uint16_t)atoi(colon + 1);
    } else {
        size_t hostLen = strlen(start);
        if (hostLen > sizeof(_host) - 1) hostLen = sizeof(_host) - 1;
        memcpy(_host, start, hostLen);
        _host[hostLen] = '\0';
        _port = 443;
    }
}

void RadioKitCloud::setAccount(const char* account) {
    if (account) {
        strncpy(_account, account, sizeof(_account) - 1);
    }
}

void RadioKitCloud::begin(const char* name, RK_PacketCallback cb) {
    _packetCb = cb;

    if (name) {
        strncpy(_deviceName, name, sizeof(_deviceName) - 1);
    }

    if (_host[0] == '\0') {
        RadioKit.print("Cloud: No relay URL configured — transport disabled\n");
        Serial.println("Cloud: No relay URL configured — transport disabled");
        return;
    }

#if defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)
    RadioKit.printf("Cloud: Connecting to relay at %s:%u...\n", _host, _port);
    Serial.printf("Cloud: Connecting to relay at %s:%u...\n", _host, _port);

    // Use SSL for port 443, plain WS otherwise
    if (_port == 443) {
        _ws.beginSSL(_host, _port, "/");
    } else {
        _ws.begin(_host, _port, "/");
    }

    _ws.onEvent([this](WStype_t type, uint8_t* payload, size_t length) {
        _onWsEvent(type, payload, length);
    });

    // Note: We manage reconnect ourselves in update() with exponential backoff.
    // Do NOT call setReconnectInterval() — it would conflict with our logic.

    _lastReconnectMs = millis();
    _reconnectDelaySec = RK_CLOUD_RECONNECT_MIN;
#else
    (void)cb;
    RadioKit.print("Cloud: Transport not available on this platform\n");
    Serial.println("Cloud: Transport not available on this platform");
#endif
}

void RadioKitCloud::setFsCallback(RK_FsPacketCallback cb) {
    _fsCb = cb;
}

void RadioKitCloud::setOtaCallback(RK_OtaPacketCallback cb) {
    _otaCb = cb;
}

void RadioKitCloud::setSettingsCallback(RK_SettingsPacketCallback cb) {
    _settingsCb = cb;
}

void RadioKitCloud::setPrintCallback(RK_PrintPacketCallback cb) {
    _printCb = cb;
}

#if defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)

void RadioKitCloud::_sendRegister() {
    if (_deviceName[0] == '\0' || _account[0] == '\0') {
        RadioKit.print("Cloud: Cannot register — device name or account not set\n");
        Serial.println("Cloud: Cannot register — device name or account not set");
        return;
    }

    // Build JSON: {"type":"register","name":"...","account":"..."}
    char buf[256];
    int len = snprintf(buf, sizeof(buf),
        "{\"type\":\"register\",\"name\":\"%s\",\"account\":\"%s\"}",
        _deviceName, _account);
    if (len > 0) {
        _ws.sendTXT(buf, (size_t)len);
        RadioKit.printf("Cloud: Sent register for '%s' account='%s'\n", _deviceName, _account);
        Serial.printf("Cloud: Sent register for '%s' account='%s'\n", _deviceName, _account);
    }
}

void RadioKitCloud::_handleText(uint8_t* payload, size_t length) {
    // arduinoWebSockets null-terminates WStype_TEXT payloads, so we can
    // safely use strstr for quick JSON field matching (no parser needed).
    const char* json = (const char*)payload;
    (void)length;

    // Quick field checks using strstr
    if (strstr(json, "\"type\":\"registered\"")) {
        _registered = true;
        _reconnectDelaySec = RK_CLOUD_RECONNECT_MIN;  // Reset backoff
        _lastPacketMs = millis();
        RadioKit.print("Cloud: Registered successfully\n");
        Serial.printf("Cloud: Registered successfully (sid: ...)\n");
        return;
    }

    if (strstr(json, "\"type\":\"client_joined\"")) {
        _lastPacketMs = millis();
        RadioKit.print("Cloud: Client joined — ready for PWD_AUTH\n");
        Serial.println("Cloud: Client joined — ready for PWD_AUTH");
        return;
    }

    if (strstr(json, "\"type\":\"pong\"")) {
        _lastPacketMs = millis();
        return;
    }

    if (strstr(json, "\"type\":\"device_status\"")) {
        _lastPacketMs = millis();
        return;
    }

    if (strstr(json, "\"type\":\"error\"")) {
        RadioKit.printf("Cloud: Server error: %s\n", json);
        Serial.printf("Cloud: Server error: %s\n", json);
        return;
    }
}

void RadioKitCloud::_onWsEvent(WStype_t type, uint8_t* payload, size_t length) {
    switch (type) {
        case WStype_DISCONNECTED:
            _wsConnected = false;
            _registered = false;
            _lastPacketMs = 0;
            // Serial-only to avoid spamming the print buffer during reconnect loop
            Serial.println("Cloud: Disconnected from relay");
            break;

        case WStype_CONNECTED:
            _wsConnected = true;
            _lastPacketMs = millis();
            RadioKit.printf("Cloud: Connected to %s:%u\n", _host, _port);
            Serial.printf("Cloud: Connected to %s:%u\n", _host, _port);
            _sendRegister();
            break;

        case WStype_BIN:
            _lastPacketMs = millis();
            _feedBytes(payload, length);
            break;

        case WStype_TEXT:
            _lastPacketMs = millis();
            _handleText(payload, length);
            break;

        case WStype_ERROR:
            RadioKit.print("Cloud: WebSocket error\n");
            Serial.printf("Cloud: WebSocket error\n");
            break;

        case WStype_FRAGMENT_TEXT_START:
        case WStype_FRAGMENT_BIN_START:
            break;

        default:
            break;
    }
}

void RadioKitCloud::_feedBytes(const uint8_t* data, size_t len) {
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
        }        case RK_SETTINGS_START_BYTE: { // 0xDD
            uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_settingsRxFeedByte(frameData[i], subCmd, payload, payloadLen)) {
                    if (_settingsCb) _settingsCb(subCmd, payload, payloadLen);
                }
            }
            break;
        }
        case RK_PRINT_START_BYTE: { // 0xEE
            const uint8_t* payload; uint16_t payloadLen;
            for (size_t i = 0; i < frameLen; i++) {
                if (rk_printRxFeedByte(frameData[i], payload, payloadLen)) {
                    if (_printCb) _printCb(payload, payloadLen);
                }
            }
            break;
        }
        default:
            break;
        }
    }

void RadioKitCloud::update() {
    _ws.loop();

    unsigned long now = millis();

    // Heartbeat ping every 30s when connected and registered
    if (_wsConnected && _registered && (now - _lastPingMs > RK_CLOUD_PING_INTERVAL_MS)) {
        _lastPingMs = now;
        _ws.sendTXT("{\"type\":\"ping\"}");
    }

    // Timeout detection
    if (_wsConnected && (now - _lastPacketMs) > RK_CLOUD_TIMEOUT_MS) {
        // Serial-only to avoid spamming the print buffer during reconnect loop
        Serial.println("Cloud: Timeout — no packets for 15s, disconnecting");
        _ws.disconnect();
        _wsConnected = false;
        _registered = false;
    }

    // Reconnect with exponential backoff
    if (!_wsConnected && _host[0] != '\0') {
        unsigned long elapsed = (now - _lastReconnectMs) / 1000;
        if (elapsed >= _reconnectDelaySec) {
            _lastReconnectMs = now;
            // Serial-only to avoid spamming the print buffer during reconnect loop
            Serial.printf("Cloud: Reconnecting (backoff=%us)...\n", _reconnectDelaySec);

            if (_port == 443) {
                _ws.beginSSL(_host, _port, "/");
            } else {
                _ws.begin(_host, _port, "/");
            }

            // Exponential backoff: double each attempt, cap at max
            _reconnectDelaySec *= 2;
            if (_reconnectDelaySec > RK_CLOUD_RECONNECT_MAX) {
                _reconnectDelaySec = RK_CLOUD_RECONNECT_MAX;
            }
        }
    }
}

void RadioKitCloud::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_wsConnected || !_registered) return;

    // Cap total framed size
    if (len + 1 > RK_CLOUD_FRAMED_BUF_SIZE) {
        len = RK_CLOUD_FRAMED_BUF_SIZE - 1;
    }

    // Determine type byte from the frame's start byte
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

    // Build framed message: [type(1)][original_frame]
    _framedBuf[0] = typeByte;
    memcpy(_framedBuf + 1, buf, len);

    _ws.sendBIN(_framedBuf, 1 + len);
}

bool RadioKitCloud::isConnected() const {
    return _wsConnected && _registered && (millis() - _lastPacketMs) < RK_CLOUD_TIMEOUT_MS;
}

int8_t RadioKitCloud::getRssi() {
    return 0;  // Cloud relay RSSI not meaningful
}

#else // !defined(RK_ENABLE_CLOUD) || !defined(RK_ENABLE_WIFI)

void RadioKitCloud::update() {}
void RadioKitCloud::sendPacket(const uint8_t* buf, uint16_t len) { (void)buf; (void)len; }
bool RadioKitCloud::isConnected() const { return false; }
int8_t RadioKitCloud::getRssi() { return 0; }

#endif // defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)
