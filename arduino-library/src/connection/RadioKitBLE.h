/**
 * RadioKitBLE.h
 * BLE transport for RadioKit — wraps NimBLE-Arduino.
 * Implements RadioKitTransport.
 */

#ifndef RADIOKIT_BLE_H
#define RADIOKIT_BLE_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitTransport.h"

class NimBLEServer;
class NimBLECharacteristic;

#define RK_BLE_SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"

// Conservative MTU (default 23 − 3 ATT overhead = 20 usable bytes)
#define RK_BLE_MTU 20

class RadioKitBLE : public RadioKitTransport {
public:
    RadioKitBLE();

    void begin(const char* deviceName, RK_PacketCallback cb) override;
    void setFsCallback(RK_FsPacketCallback cb) override;
    void update()                                            override;
    void sendPacket(const uint8_t* buf, uint16_t len)       override;
    bool isConnected() const                                override { return _connected; }
    int8_t getRssi()                                        override;

    // Internal callbacks invoked by NimBLE event handlers
    void _onConnect();
    void _onDisconnect();
    void _onWrite(const uint8_t* data, size_t len);

private:
    NimBLEServer*         _server;
    NimBLECharacteristic* _characteristic;
    RK_PacketCallback     _packetCallback;
    RK_FsPacketCallback   _fsPacketCallback;
    volatile bool         _connected;
    bool                  _needRestartAdv;
};

extern RadioKitBLE RadioKitBLEInstance;

#endif // RADIOKIT_BLE_H
