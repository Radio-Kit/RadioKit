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

// Default MTU (negotiated value is cached after connection)
#define RK_BLE_MTU 20

class NimBLEConnInfo;

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
    void _onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo);
    void _onDisconnect();
    void _onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo);
    void _onWrite(const uint8_t* data, size_t len);

private:
    NimBLEServer*         _server;
    NimBLECharacteristic* _characteristic;
    RK_PacketCallback     _packetCallback;
    RK_FsPacketCallback   _fsPacketCallback;
    volatile bool _connected;
    volatile bool         _sending;          // Re-entrancy guard for sendPacket (cross-task)
    bool                  _needRestartAdv;
    uint16_t              _negotiatedMtu;     // Cached negotiated MTU
    uint16_t              _connHandle;        // Cached connection handle
    uint16_t              _connIntervalMs;    // Connection interval in ms (0 = unknown)

    // Dedicated send buffer: the caller's buffer (rk_fsTxBuf) can be
    // overwritten by handleRead during delay() yields, so we copy the frame
    // here at the start of sendPacket and send from this safe copy.
    // Size = FS header(4) + FS max payload(16384) = 16388.
    static const uint16_t kSendBufSize = 16388;
    uint8_t               _sendBuf[kSendBufSize];

    // Pending-send buffer: when sendPacket is re-entered (e.g. an incoming
    // BLE write is processed during a delay() in the send loop), the
    // outgoing frame is queued here and sent after the current send completes.
    static const uint16_t kPendingBufSize = 16388;
    uint8_t               _pendingBuf[kPendingBufSize];
    uint16_t              _pendingLen;
};

extern RadioKitBLE RadioKitBLEInstance;

#endif // RADIOKIT_BLE_H
