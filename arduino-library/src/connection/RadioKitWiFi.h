/**
 * RadioKitWiFi.h
 * WiFi transport for RadioKit — local WebSocket server on port 5555.
 *
 * Implements RadioKitTransport with:
 *   - AP mode (fallback when no STA credentials)
 *   - STA mode (client on local WiFi network)
 *   - Background STA retry with AP staying active
 *   - mDNS advertising (_radiokit._tcp)
 *   - Type-byte-prefixed WebSocket binary frames
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

#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <ESPmDNS.h>
#endif

class RadioKitWiFi : public RadioKitTransport {
public:
    RadioKitWiFi();

    void begin(const char* name, RK_PacketCallback cb) override;
    void setFsCallback(RK_FsPacketCallback cb) override;
    void setOtaCallback(RK_OtaPacketCallback cb) override;
    void setSettingsCallback(RK_SettingsPacketCallback cb) override;
    void update() override;
    void sendPacket(const uint8_t* buf, uint16_t len) override;
    bool isConnected() const override;
    int8_t getRssi() override;

    // WiFi-specific
    void setCredentials(const char* staSsid, const char* staPassword);
    void setApPassword(const char* pwd);
    bool isApMode() const { return _apMode; }
    const char* getLocalIp() const;

private:
    // ── Common state (always declared, used by all targets) ───────
    bool _apMode;
    bool _wsConnected;
    unsigned long _lastPacketMs;
    unsigned long _lastStaRetryMs;

    // Callback pointers (set unconditionally by constructor/begin)
    RK_PacketCallback _packetCb;
    RK_FsPacketCallback _fsCb;
    RK_OtaPacketCallback _otaCb;
    RK_SettingsPacketCallback _settingsCb;

    // Credential buffers
    char _staSsid[RADIOKIT_MAX_SSID + 1];
    char _staPwd[RADIOKIT_MAX_WIFI_PWD + 1];
    const char* _connPwd;

    // Cached device name
    char _deviceName[33];

    // IP string buffer (stable return for getLocalIp())
    mutable char _localIpBuf[16];

#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)
    WebSocketsServer _server;

    // Send buffer (pre-allocated to avoid stack overflow with large FS frames)
    uint8_t _framedBuf[16388];

    void _startAp();
    bool _connectSta(const char* ssid, const char* password);
    void _onWsEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length);
    void _feedBytes(const uint8_t* data, size_t len);
    void _initMdns(const char* mode);
#endif
};

extern RadioKitWiFi RadioKitWiFiInstance;

#endif // RADIOKIT_WIFI_H
