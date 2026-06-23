/**
 * RadioKitCloud.h
 * Cloud relay transport for RadioKit — outbound WebSocket client (WSS).
 *
 * Connects to the RadioKit relay server (Rust), registers the device, and
 * forwards radio protocol frames bidirectionally. Uses the same type-byte
 * prefix pattern as RadioKitWiFi for protocol multiplexing.
 *
 * Requires ESP32 + arduinoWebSockets library. Guarded by:
 *   #if defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)
 *
 * Usage:
 *   1. Call setCloudUrl() and setAccount() before begin()
 *   2. begin() starts the outbound WebSocket connection
 *   3. On WS_CONNECTED, automatically sends register frame
 *   4. On "registered" response, relays begin
 *   5. Heartbeat ping every 30s
 *   6. Automatic reconnect with exponential backoff (1s → 60s max)
 */

#ifndef RADIOKIT_CLOUD_H
#define RADIOKIT_CLOUD_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitTransport.h"
#include "../RadioKitProtocol.h"
#include "../RadioKitConfig.h"

#if defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)
#include <WebSocketsClient.h>
#endif

class RadioKitCloud : public RadioKitTransport {
public:
    RadioKitCloud();

    void begin(const char* name, RK_PacketCallback cb) override;
    void setFsCallback(RK_FsPacketCallback cb) override;
    void setOtaCallback(RK_OtaPacketCallback cb) override;
    void setSettingsCallback(RK_SettingsPacketCallback cb) override;
    void setPrintCallback(RK_PrintPacketCallback cb) override;
    void update() override;
    void sendPacket(const uint8_t* buf, uint16_t len) override;
    bool isConnected() const override;
    int8_t getRssi() override;

    // Cloud-specific
    void setCloudUrl(const char* url);
    void setAccount(const char* account);
    bool isRegistered() const { return _registered; }

private:
    // ── Common state (always declared) ────────────────────────
    bool _registered;
    unsigned long _lastPingMs;
    unsigned long _lastReconnectMs;
    unsigned int  _reconnectDelaySec;  // Exponential backoff: 1, 2, 4, 8, ... max 60

    // Connection params
    char _host[128];
    uint16_t _port;
    char _account[65];
    char _deviceName[33];

    // Connection status tracking
    bool _wsConnected;
    unsigned long _lastPacketMs;

    // Callback pointers
    RK_PacketCallback _packetCb;
    RK_FsPacketCallback _fsCb;
    RK_OtaPacketCallback _otaCb;
    RK_SettingsPacketCallback _settingsCb;
    RK_PrintPacketCallback _printCb;

#if defined(RK_ENABLE_CLOUD) && defined(RK_ENABLE_WIFI)
    WebSocketsClient _ws;

    // Send buffer (pre-allocated)
    uint8_t _framedBuf[16388];

    void _sendRegister();
    void _handleText(uint8_t* payload, size_t length);
    void _feedBytes(const uint8_t* data, size_t len);
    void _onWsEvent(WStype_t type, uint8_t* payload, size_t length);
#endif
};

extern RadioKitCloud RadioKitCloudInstance;

#endif // RADIOKIT_CLOUD_H
