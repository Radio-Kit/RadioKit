/**
 * RadioKitCloud.h
 * Cloud relay transport for RadioKit — outbound WebSocket client.
 *
 * Stub for Phase 4 implementation. Provides the extern declaration so
 * RadioKitClass can reference RadioKitCloudInstance in update() and
 * broadcast loops without conditional compilation.
 *
 * Full implementation in Phase 4.
 */

#ifndef RADIOKIT_CLOUD_H
#define RADIOKIT_CLOUD_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitTransport.h"

class RadioKitCloud : public RadioKitTransport {
public:
    void begin(const char* name, RK_PacketCallback cb) override { (void)name; (void)cb; }
    void setFsCallback(RK_FsPacketCallback cb) override { (void)cb; }
    void setOtaCallback(RK_OtaPacketCallback cb) override { (void)cb; }
    void setSettingsCallback(RK_SettingsPacketCallback cb) override { (void)cb; }
    void update() override {}
    void sendPacket(const uint8_t* buf, uint16_t len) override { (void)buf; (void)len; }
    bool isConnected() const override { return false; }
    int8_t getRssi() override { return 0; }
};

extern RadioKitCloud RadioKitCloudInstance;

#endif // RADIOKIT_CLOUD_H
