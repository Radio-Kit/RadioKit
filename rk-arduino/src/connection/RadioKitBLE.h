/**
 * RadioKitBLE.h
 * BLE transport for RadioKit — wraps NimBLE-Arduino.
 * Implements RadioKitTransport.
 *
 * Three dedicated BLE characteristics prevent notification interleaving:
 *   0xFFE1 — Widget protocol (0x55 frames)
 *   0xFFE2 — Filesystem protocol (0xAA frames)
 *   0xFFE3 — OTA protocol (0xBB frames)
 * Each characteristic has independent NOTIFY + WRITE properties,
 * so one protocol's notifications can never interleave into another's data stream.
 */

#ifndef RADIOKIT_BLE_H
#define RADIOKIT_BLE_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitTransport.h"

class NimBLEServer;
class NimBLECharacteristic;

#define RK_BLE_SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHAR_WIDGET_UUID    "0000FFE1-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHAR_FS_UUID        "0000FFE2-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHAR_OTA_UUID       "0000FFE3-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHAR_SETTINGS_UUID  "0000FFE4-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHAR_PRINT_UUID     "0000FFE5-0000-1000-8000-00805F9B34FB"

// Default MTU (negotiated value is cached after connection)
#define RK_BLE_MTU 20

class NimBLEConnInfo;

class RadioKitBLE : public RadioKitTransport {
public:
    RadioKitBLE();

    // Public getters for connection parameters (used by RadioKit::_handleBleInfo)
    uint16_t getConnIntervalMs() const { return _connIntervalMs; }
    uint16_t getNegotiatedMtu() const { return _negotiatedMtu; }

    void begin(const char* deviceName, RK_PacketCallback cb) override;
    void setFsCallback(RK_FsPacketCallback cb) override;
    void setOtaCallback(RK_OtaPacketCallback cb) override;
    void setSettingsCallback(RK_SettingsPacketCallback cb) override;
    void setPrintCallback(RK_PrintPacketCallback cb) override;
    void update()                                            override;
    void sendPacket(const uint8_t* buf, uint16_t len)       override;
    bool isConnected() const                                override { return _connected; }
    int8_t getRssi()                                        override;

    /**
     * Update the BLE advertising name and re-start advertising.
     * Called when the device name is changed via CMD_SET_CONF.
     * Does nothing if not connected (name takes effect on next start).
     */
    void updateAdvertisingName(const char* name);

    // Internal callbacks invoked by NimBLE event handlers
    void _onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo);
    void _onDisconnect();
    void _onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo);
    void _onWidgetWrite(const uint8_t* data, size_t len);
    void _onFsWrite(const uint8_t* data, size_t len);
    void _onOtaWrite(const uint8_t* data, size_t len);
    void _onSettingsWrite(const uint8_t* data, size_t len);
    void _processPendingFs();

private:
    NimBLEServer*         _server;
    NimBLECharacteristic* _charWidget;    // 0xFFE1 — widget protocol (0x55)
    NimBLECharacteristic* _charFs;        // 0xFFE2 — filesystem protocol (0xAA)
    NimBLECharacteristic* _charOta;       // 0xFFE3 — OTA protocol (0xBB)
    NimBLECharacteristic* _charSettings;  // 0xFFE4 — settings protocol (0xDD)
    NimBLECharacteristic* _charPrint;     // 0xFFE5 — print stream (0xEE, notify only)
    RK_PacketCallback     _packetCallback;
    RK_FsPacketCallback   _fsPacketCallback;
    RK_OtaPacketCallback  _otaPacketCallback;
    RK_SettingsPacketCallback _settingsPacketCallback;
    RK_PrintPacketCallback _printPacketCallback;
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

    // Deferred FS frame: the NimBLE host task buffers complete FS frames
    // here instead of calling _fsPacketCallback inline, preventing LittleFS
    // operations from blocking the BLE stack and stalling the TX queue.
    static const uint16_t kPendingFsPayloadSize = 16384;
    uint8_t               _pendingFsPayload[kPendingFsPayloadSize];
    uint8_t               _fsWorkBuf[kPendingFsPayloadSize];  // update()'s safe working copy
    uint8_t               _pendingFsSubCmd;
    uint16_t              _pendingFsLen;
    volatile bool         _hasPendingFs;

    // Deferred OTA frame: same pattern as FS — OTA flash writes (Update.write)
    // can block the NimBLE host task for 50-200ms, stalling the TX queue.
    // Max OTA payload is RK_OTA_MAX_PAYLOAD (4096).
    static const uint16_t kPendingOtaPayloadSize = 4096;
    uint8_t               _pendingOtaPayload[kPendingOtaPayloadSize];
    uint8_t               _otaWorkBuf[kPendingOtaPayloadSize];
    uint8_t               _pendingOtaSubCmd;
    uint16_t              _pendingOtaLen;
    volatile bool         _hasPendingOta;

    // Select the characteristic matching [buf[0]]'s protocol.
    NimBLECharacteristic* _charForBuf(const uint8_t* buf) const;

    void _processPendingOta();
};

extern RadioKitBLE RadioKitBLEInstance;

#endif // RADIOKIT_BLE_H
