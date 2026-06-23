/**
 * RadioKitWiFi.h
 * WiFi transport for RadioKit — local WebSocket server on port 5555.
 *
 * Implements RadioKitTransport with:
 *   - AP mode (always open — auth via PWD_AUTH protocol)
 *   - STA mode (client on local WiFi network)
 *   - Background STA retry with AP staying active
 *   - mDNS advertising (_radiokit._tcp)
 *   - Per-client auth tracking with 30s auth timeout
 *
 * Requires the arduinoWebSockets library (WebSocketsServer).
 * Only available on ESP32. Enable with: -DRADIOKIT_ENABLE_WIFI in build_flags.
 */

#ifndef RADIOKIT_WIFI_H
#define RADIOKIT_WIFI_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitTransport.h"
#include "../RadioKitProtocol.h"
#include "../RadioKitConfig.h"

#if defined(RK_ENABLE_WIFI)
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ESPmDNS.h>
#endif

// ── Per-client auth tracking ──────────────────────────────────────────────────
#define RK_WIFI_MAX_CLIENTS    4
#define RK_WIFI_AUTH_TIMEOUT_MS 30000  // 30s to authenticate after WS connect

enum RK_WiFiAuthLevel : uint8_t {
    RK_WIFI_AUTH_NONE   = 0,
    RK_WIFI_AUTH_USER   = 1,
    RK_WIFI_AUTH_DEVICE = 2,
};

struct RK_WiFiClientState {
    unsigned long connectTime;  ///< millis() when WS CONNECTED event fired
    uint8_t authLevel;          ///< RK_WiFiAuthLevel
    bool active;                ///< Whether this slot has a connected client
};

class RadioKitWiFi : public RadioKitTransport {
public:
    RadioKitWiFi();

    void begin(const char* name, RK_PacketCallback cb) override;
    void setFsCallback(RK_FsPacketCallback cb) override;
    void setOtaCallback(RK_OtaPacketCallback cb) override;    void setSettingsCallback(RK_SettingsPacketCallback cb) override;
    void setPrintCallback(RK_PrintPacketCallback cb) override;
    void update()                                              override;
    void sendPacket(const uint8_t* buf, uint16_t len) override;
    bool isConnected() const override;
    int8_t getRssi() override;

    // WiFi-specific
    void setCredentials(const char* staSsid, const char* staPassword);
    bool isApMode() const { return _apMode; }
    const char* getLocalIp() const;

    /// Return the auth level for client N (0 = none, 1 = user, 2 = device)
    uint8_t getClientAuthLevel(uint8_t clientNum) const;

private:
    // ── Common state (always declared, used by all targets) ───────
    bool _apMode;
    unsigned long _lastStaRetryMs;

    // Callback pointers (set unconditionally by constructor/begin)
    RK_PacketCallback _packetCb;
    RK_FsPacketCallback _fsCb;
    RK_OtaPacketCallback _otaCb;
    RK_SettingsPacketCallback _settingsCb;
    RK_PrintPacketCallback _printCb;

    // Credential buffers
    char _staSsid[RADIOKIT_MAX_SSID + 1];
    char _staPwd[RADIOKIT_MAX_WIFI_PWD + 1];

    // Cached device name
    char _deviceName[33];

    // IP string buffer (stable return for getLocalIp())
    mutable char _localIpBuf[16];

#if defined(RK_ENABLE_WIFI)
    WebSocketsServer* _server;

    // Per-client auth state
    RK_WiFiClientState _clients[RK_WIFI_MAX_CLIENTS];
    int _activeClientCount;  ///< Number of currently connected clients

    // Send buffer (pre-allocated to avoid stack overflow with large FS frames)
    uint8_t _framedBuf[16388];

    void _startAp();
    bool _connectSta(const char* ssid, const char* password);
    void _onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length);
    void _feedBytes(uint8_t clientNum, const uint8_t* data, size_t len);
    void _initMdns(const char* mode);
    void _sendToClient(uint8_t clientNum, const uint8_t* buf, uint16_t len);
    void _disconnectClient(uint8_t clientNum);
#endif
};

extern RadioKitWiFi RadioKitWiFiInstance;

#endif // RADIOKIT_WIFI_H
