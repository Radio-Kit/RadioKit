/**
 * RadioKitBLE.cpp
 * BLE transport implementation using NimBLE-Arduino.
 *
 * Optimizations applied:
 *   1. WRITE + WRITE_NR properties (reliable cross-platform writes)
 *   2. Default PHY set to 2M (double the 1M base rate)
 *   3. Large MTU negotiation (up to 512 bytes)
 *   4. Data Length Extension (DLE) for 251-byte payloads
 *   5. Optimized connection parameters (low latency)
 *   6. Dynamic send pacing based on negotiated MTU
 */

#include "RadioKitBLE.h"
#include "../RadioKitProtocol.h"
#include "../RadioKit.h"
#include "RadioKitFS.h"
#include <NimBLEDevice.h>

#define RK_BLE_SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"

// Default MTU (will be updated after negotiation)
#define RK_BLE_MTU 20

RadioKitBLE RadioKitBLEInstance;

// ── Static Callback Instances (Avoids heap allocation/fragmentation) ──
class RKServerCallbacks : public NimBLEServerCallbacks {
public:
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override { 
        RadioKitBLEInstance._onConnect(pServer, connInfo);
    }
    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override { 
        RadioKitBLEInstance._onDisconnect(); 
    }
    void onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo) override {
        RadioKitBLEInstance._onMTUChange(MTU, connInfo);
    }
};

class RKCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        NimBLEAttValue value = pChar->getValue();
        if (value.length() > 0)
            RadioKitBLEInstance._onWrite(value.data(), value.length());
    }
    void onSubscribe(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo, uint16_t subValue) override {
        Serial.printf("BLE: Client subscribed (subValue=%d)\n", subValue);
    }
};

static RKServerCallbacks s_serverCallbacks;
static RKCharCallbacks   s_charCallbacks;

// ─────────────────────────────────────────────
RadioKitBLE::RadioKitBLE()
    : _server(nullptr), _characteristic(nullptr)
    , _packetCallback(nullptr), _fsPacketCallback(nullptr)
    , _connected(false), _sending(false), _needRestartAdv(false)
    , _negotiatedMtu(RK_BLE_MTU), _connHandle(0xFFFF)
    , _connIntervalMs(12), _pendingLen(0)
{}

void RadioKitBLE::begin(const char* deviceName, RK_PacketCallback cb) {
    _packetCallback   = cb;
    _fsPacketCallback = nullptr;
    _connected        = false;
    _needRestartAdv   = false;
    _negotiatedMtu    = RK_BLE_MTU;
    _connHandle       = 0xFFFF;

    // Pulse the LED to show we reached begin()
    pinMode(7, OUTPUT);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW); delay(100);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW);

    Serial.println("BLE: Initializing stack...");
    NimBLEDevice::init(deviceName ? deviceName : "RadioKit");

    // ── BLE Optimizations ────────────────────────────────────────

    // 1. Request large MTU (512 is max practical for N_ L2CAP)
    //    Must be called BEFORE creating server/service/characteristic.
    NimBLEDevice::setMTU(512);
    Serial.println("BLE: Requested MTU 512");

    // 2. Prefer 2M PHY for maximum throughput.
    //    ESP32-S3 supports BLE 5.0 with 2M PHY.
    //    Masks: BLE_GAP_LE_PHY_1M = 1, BLE_GAP_LE_PHY_2M = 2, BLE_GAP_LE_PHY_CODED = 4
    NimBLEDevice::setDefaultPhy(BLE_GAP_LE_PHY_2M_MASK, BLE_GAP_LE_PHY_2M_MASK);
    Serial.println("BLE: Preferred 2M PHY");

    // 3. Set power to +9 dBm for stronger signal (ESP32-S3 max)
    NimBLEDevice::setPower(9, NimBLETxPowerType::All);

    Serial.println("BLE: Creating server...");
    _server = NimBLEDevice::createServer();
    _server->setCallbacks(&s_serverCallbacks);

    Serial.println("BLE: Creating service...");
    NimBLEService* pService = _server->createService(RK_BLE_SERVICE_UUID);

    Serial.println("BLE: Creating characteristic...");
    _characteristic = pService->createCharacteristic(
        RK_BLE_CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::WRITE   |       // Reliable writes (with response)
        NIMBLE_PROPERTY::WRITE_NR |       // Fast writes (no response)
        NIMBLE_PROPERTY::NOTIFY  |
        NIMBLE_PROPERTY::INDICATE
    );
    _characteristic->setCallbacks(&s_charCallbacks);

    Serial.println("BLE: Starting server...");
    _server->start();

    Serial.println("BLE: Starting advertising...");
    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    pAdv->addServiceUUID(RK_BLE_SERVICE_UUID);
    pAdv->enableScanResponse(true);
    pAdv->setName(deviceName ? deviceName : "RadioKit");
    // Optimized connection advertising params:
    // minInterval = 0x06 * 0.625ms = 3.75ms, maxInterval = 0x06 * 0.625ms = 3.75ms
    pAdv->setPreferredParams(0x06, 0x06);
    pAdv->start();
    
    Serial.println("BLE: System ready.");
}

void RadioKitBLE::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_connected || !_characteristic) {
        Serial.printf("BLE: Cannot send (connected=%d, char=%p)\n", _connected, _characteristic);
        return;
    }
    
    // Re-entrancy guard: if sendPacket is already in progress (e.g., an
    // incoming BLE write is processed during a delay() in the send loop
    // and triggers an outgoing ACK frame), queue the frame in [_pendingBuf]
    // for delivery after the current send completes, rather than dropping it.
    // Dropped ACKs cause the Flutter side to time out (60s per chunk),
    // stalling large file transfers at ~156 KB.
    if (_sending) {
        uint16_t cap = sizeof(_pendingBuf);
        if (len <= cap) {
            memcpy(_pendingBuf, buf, len);
            _pendingLen = len;
        }
        return;
    }
    _sending = true;

    // Copy the frame to the dedicated send buffer so handler callbacks
    // (e.g. handleRead writing to rk_fsTxBuf) cannot corrupt in-flight
    // data during delay() yields between notifications.
    const uint8_t* safeBuf = buf;
    if (len <= sizeof(_sendBuf)) {
        memcpy(_sendBuf, buf, len);
        safeBuf = _sendBuf;
    }

    uint16_t mtu = _negotiatedMtu;
    if (mtu < 23) mtu = 23;
    mtu -= 3;

    uint16_t offset = 0;
    unsigned long sendStart = millis();
    const unsigned long SEND_TIMEOUT_MS = 30000;
    
    while (offset < len) {
        uint16_t chunk = len - offset;
        if (chunk > mtu) chunk = mtu;
        
        bool success = false;
        int backoff = 10;
        for (int retry = 0; retry < 10 && !success; retry++) {
            if (millis() - sendStart >= SEND_TIMEOUT_MS) {
                Serial.printf("BLE: sendPacket timeout (%ums) at offset %u/%u\n",
                    SEND_TIMEOUT_MS, offset, len);
                _sending = false;
                return;
            }
            if (!_connected) {
                Serial.printf("BLE: sendPacket aborted (disconnected) at offset %u/%u\n",
                    offset, len);
                _sending = false;
                return;
            }
            
            success = _characteristic->notify(safeBuf + offset, chunk);
            if (!success) {
                delay(backoff);
                if (backoff < 250) backoff += 10;
            }
        }
        
        if (!success) {
            Serial.printf("BLE: sendPacket abort — notify failed after 10 retries at offset %u/%u\n",
                offset, len);
            _sending = false;
            return;
        }
        
        offset += chunk;
        
        if (offset < len) {
            delay(5);  // Yield 5ms between notifications so the NimBLE host
                      // task can process TX completion events from the
                      // controller. 1ms was too short for 16-notification
                      // bursts (8KB chunks) — the host couldn't drain the
                      // 10-slot TX queue fast enough. 5ms gives the host
                      // adequate time per notification while still being
                      // 12× faster than the original 60ms pacing.
        }
    }
    
    _sending = false;

    // Deliver any frame that was queued while we were sending.
    if (_pendingLen > 0) {
        uint16_t qLen = _pendingLen;
        _pendingLen = 0;
        // Recurse — _sending is now false so this call will proceed normally.
        sendPacket(_pendingBuf, qLen);
        return;
    }
}

void RadioKitBLE::update() {
    if (_needRestartAdv) {
        _needRestartAdv = false;
        delay(500);
        NimBLEDevice::getAdvertising()->start();
    }
}

void RadioKitBLE::_onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) {
    _connected = true;
    _connHandle = connInfo.getConnHandle();

    _connIntervalMs = (uint16_t)(connInfo.getConnInterval() * 1.25f);
    if (_connIntervalMs < 8) _connIntervalMs = 8; // clamp minimum
    Serial.printf("BLE: Client connected (handle=%u, interval=%ums)\n",
        _connHandle, _connIntervalMs);

    // Cache the initial (pre-negotiation) MTU
    _negotiatedMtu = pServer->getPeerMTU(_connHandle);
    if (_negotiatedMtu < 3) _negotiatedMtu = RK_BLE_MTU;
    Serial.printf("BLE: Initial MTU = %u (will update after negotiation)\n", _negotiatedMtu);

    // ── Post-connection optimizations ─────────────────────────────

    // 1. Update connection parameters for lowest possible latency
    //    minInterval = 6 * 1.25ms = 7.5ms  (BLE minimum)
    //    maxInterval = 8 * 1.25ms = 10ms   (flexible — phone more likely to accept)
    //    latency = 0 (no slave latency)
    //    timeout = 400 * 10ms = 4s
    pServer->updateConnParams(_connHandle, 6, 8, 0, 400);
    Serial.println("BLE: Requested connection params (7.5-10ms, lat=0, timeout=4s)");

    // 2. Enable Data Length Extension for 251-byte payloads
    //    This is the max BLE 4.2+ DLE size.
    pServer->setDataLen(_connHandle, 251);
    Serial.println("BLE: Requested data length 251 (DLE)");

    // 3. Request 2M PHY if not already negotiated
    pServer->updatePhy(_connHandle, BLE_GAP_LE_PHY_2M_MASK, BLE_GAP_LE_PHY_2M_MASK, 0);
    Serial.println("BLE: Requested 2M PHY update");
}

void RadioKitBLE::_onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo) {
    _negotiatedMtu = MTU;
    Serial.printf("BLE: MTU negotiated to %u\n", MTU);
}
void RadioKitBLE::_onDisconnect() {
    _connected = false;
    _sending = false;
    _connHandle = 0xFFFF;
    _negotiatedMtu = RK_BLE_MTU;
    _needRestartAdv = true;
    rk_rxReset();
    rk_fsRxReset();
    Serial.println("BLE: Client disconnected");
}

void RadioKitBLE::setFsCallback(RK_FsPacketCallback cb) {
    _fsPacketCallback = cb;
}

void RadioKitBLE::_onWrite(const uint8_t* data, size_t len) {
    uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++) {
        uint8_t byte = data[i];
        
        // Clean dispatch: each byte goes to exactly one parser based on
        // frame ownership. Two parsers share the same byte stream:
        //   - Widget parser: 0x55 frames (commands, PING, telemetry)
        //   - FS parser:     0xAA frames (filesystem operations)
        //
        // Rules:
        //   1. If a parser is mid-frame (owns the stream), all bytes go
        //      exclusively to that parser until its frame completes.
        //   2. If neither parser is active, dispatch by start byte:
        //      0x55 → widget, 0xAA → FS, other → dropped (harmless).
        //
        // This fully prevents interference between the two protocols.
        // No widget frame bytes (including PING 0x55) can reach the FS
        // parser while a widget frame is in progress, and no FS data
        // bytes (including binary 0x55) can reach the widget parser
        // while an FS frame is in progress.
        
        bool widgetActive = rk_rxIsActive();
        bool fsActive = rk_fsRxIsActive();
        
        if (widgetActive) {
            // ── Widget parser owns the stream ──
            if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
                if (_packetCallback) _packetCallback(cmd, payload, payloadLen);
            }
        } else if (fsActive) {
            // ── FS parser owns the stream ──
            if (rk_fsRxFeedByte(byte, cmd, payload, payloadLen)) {
                if (_fsPacketCallback) _fsPacketCallback(cmd, payload, payloadLen);
            }
        } else {
            // ── Neither parser active — dispatch by start byte ──
            if (byte == RK_START_BYTE) {
                if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
                    if (_packetCallback) _packetCallback(cmd, payload, payloadLen);
                }
            } else if (byte == RK_FS_START_BYTE) {
                if (rk_fsRxFeedByte(byte, cmd, payload, payloadLen)) {
                    if (_fsPacketCallback) _fsPacketCallback(cmd, payload, payloadLen);
                }
            }
            // Other bytes: not a start byte for either parser.
            // Both parsers are in WAIT_START and would ignore them.
        }
    }
}

int8_t RadioKitBLE::getRssi() {
    if (!_connected || !_server) return 0;
    if (_server->getConnectedCount() == 0) return 0;
    
    NimBLEConnInfo connInfo = _server->getPeerInfo(0);
    int8_t rssi = 0;
    if (ble_gap_conn_rssi(connInfo.getConnHandle(), &rssi) == 0) {
        return rssi;
    }
    return 0;
}
