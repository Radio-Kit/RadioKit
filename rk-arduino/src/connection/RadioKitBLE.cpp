/**
 * RadioKitBLE.cpp
 * BLE transport implementation using NimBLE-Arduino.
 *
 * Three dedicated BLE characteristics prevent notification interleaving
 * between protocols: 0xFFE1 (widget), 0xFFE2 (FS), 0xFFE3 (OTA).
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
#include "../RadioKitClass.h"
#include "RadioKitPrint.h"
#include "RadioKitFS.h"
#include "RadioKitOTA.h"
#include "RadioKitSettings.h"

#if defined(RK_ENABLE_BLE)
#include <NimBLEDevice.h>

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

// Per-characteristic write callbacks — each feeds the appropriate parser directly.
class RKWidgetCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        NimBLEAttValue value = pChar->getValue();
        if (value.length() > 0)
            RadioKitBLEInstance._onWidgetWrite(value.data(), value.length());
    }
    void onSubscribe(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo, uint16_t subValue) override {
        // Serial-only to avoid spamming the print buffer on every BLE connect
        Serial.printf("BLE: Widget char subscribed (subValue=%d)\n", subValue);
    }
};

class RKFsCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        NimBLEAttValue value = pChar->getValue();
        if (value.length() > 0)
            RadioKitBLEInstance._onFsWrite(value.data(), value.length());
    }
    void onSubscribe(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo, uint16_t subValue) override {
        // Serial-only to avoid spamming the print buffer on every BLE connect
        Serial.printf("BLE: FS char subscribed (subValue=%d)\n", subValue);
    }
};

class RKOtaCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        NimBLEAttValue value = pChar->getValue();
        if (value.length() > 0)
            RadioKitBLEInstance._onOtaWrite(value.data(), value.length());
    }
    void onSubscribe(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo, uint16_t subValue) override {
        // Serial-only to avoid spamming the print buffer on every BLE connect
        Serial.printf("BLE: OTA char subscribed (subValue=%d)\n", subValue);
    }
};

static RKServerCallbacks   s_serverCallbacks;
static RKWidgetCharCallbacks s_widgetCharCallbacks;
static RKFsCharCallbacks    s_fsCharCallbacks;
static RKOtaCharCallbacks   s_otaCharCallbacks;

class RKSettingsCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        NimBLEAttValue value = pChar->getValue();
        if (value.length() > 0)
            RadioKitBLEInstance._onSettingsWrite(value.data(), value.length());
    }
    void onSubscribe(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo, uint16_t subValue) override {
        // Serial-only to avoid spamming the print buffer on every BLE connect
        Serial.printf("BLE: Settings char subscribed (subValue=%d)\n", subValue);
    }
};

class RKPrintCharCallbacks : public NimBLECharacteristicCallbacks {
public:
    void onSubscribe(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo, uint16_t subValue) override {
        // Serial-only to avoid spamming the print buffer on every BLE connect
        Serial.printf("BLE: Print char subscribed (subValue=%d)\n", subValue);
    }
};

static RKPrintCharCallbacks s_printCharCallbacks;
static RKSettingsCharCallbacks s_settingsCharCallbacks;

// ─────────────────────────────────────────────
RadioKitBLE::RadioKitBLE()
    : _server(nullptr), _charWidget(nullptr), _charFs(nullptr), _charOta(nullptr), _charSettings(nullptr), _charPrint(nullptr)
    , _packetCallback(nullptr), _fsPacketCallback(nullptr)
    , _otaPacketCallback(nullptr), _settingsPacketCallback(nullptr)
    , _printPacketCallback(nullptr)
    , _connected(false), _sending(false), _needRestartAdv(false)
    , _negotiatedMtu(RK_BLE_MTU), _connHandle(0xFFFF)
    , _connIntervalMs(12), _pendingLen(0)
    , _pendingFsSubCmd(0), _pendingFsLen(0), _hasPendingFs(false)
    , _pendingOtaSubCmd(0), _pendingOtaLen(0), _hasPendingOta(false)
{}

void RadioKitBLE::begin(const char* deviceName, RK_PacketCallback cb) {
    _packetCallback   = cb;
    _fsPacketCallback = nullptr;
    _otaPacketCallback = nullptr;
    _settingsPacketCallback = nullptr;
    _connected        = false;
    _needRestartAdv   = false;
    _negotiatedMtu    = RK_BLE_MTU;
    _connHandle       = 0xFFFF;

    // Pulse the LED to show we reached begin()
    pinMode(7, OUTPUT);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW); delay(100);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW);

    RadioKit.print("BLE: Initializing stack...\n");
    Serial.println("BLE: Initializing stack...");
    NimBLEDevice::init(deviceName ? deviceName : "RadioKit");

    // ── BLE Optimizations ────────────────────────────────────────

    // 1. Request large MTU (512 is max practical for N_ L2CAP)
    //    Must be called BEFORE creating server/service/characteristic.
    NimBLEDevice::setMTU(512);
    RadioKit.print("BLE: Requested MTU 512\n");
    Serial.println("BLE: Requested MTU 512");

    // 2. Prefer 2M PHY for maximum throughput.
    //    ESP32-S3 supports BLE 5.0 with 2M PHY.
    //    Masks: BLE_GAP_LE_PHY_1M = 1, BLE_GAP_LE_PHY_2M = 2, BLE_GAP_LE_PHY_CODED = 4
    NimBLEDevice::setDefaultPhy(BLE_GAP_LE_PHY_2M_MASK, BLE_GAP_LE_PHY_2M_MASK);
    RadioKit.print("BLE: Preferred 2M PHY\n");
    Serial.println("BLE: Preferred 2M PHY");

    // 3. Set power to +9 dBm for stronger signal (ESP32-S3 max)
    NimBLEDevice::setPower(9, NimBLETxPowerType::All);

    RadioKit.print("BLE: Creating server...\n");
    Serial.println("BLE: Creating server...");
    _server = NimBLEDevice::createServer();
    _server->setCallbacks(&s_serverCallbacks);

    RadioKit.print("BLE: Creating service...\n");
    Serial.println("BLE: Creating service...");
    NimBLEService* pService = _server->createService(RK_BLE_SERVICE_UUID);

    // ── Three dedicated characteristics ───────────────────────────
    // Each protocol gets its own pipe — prevents notification interleaving.

    RadioKit.print("BLE: Creating widget char (0xFFE1)...\n");
    Serial.println("BLE: Creating widget char (0xFFE1)...");
    _charWidget = pService->createCharacteristic(
        RK_BLE_CHAR_WIDGET_UUID,
        NIMBLE_PROPERTY::WRITE   |
        NIMBLE_PROPERTY::WRITE_NR |
        NIMBLE_PROPERTY::NOTIFY
    );
    _charWidget->setCallbacks(&s_widgetCharCallbacks);

    RadioKit.print("BLE: Creating FS char (0xFFE2)...\n");
    Serial.println("BLE: Creating FS char (0xFFE2)...");
    _charFs = pService->createCharacteristic(
        RK_BLE_CHAR_FS_UUID,
        NIMBLE_PROPERTY::WRITE   |
        NIMBLE_PROPERTY::WRITE_NR |
        NIMBLE_PROPERTY::NOTIFY
    );
    _charFs->setCallbacks(&s_fsCharCallbacks);

    RadioKit.print("BLE: Creating OTA char (0xFFE3)...\n");
    Serial.println("BLE: Creating OTA char (0xFFE3)...");
    _charOta = pService->createCharacteristic(
        RK_BLE_CHAR_OTA_UUID,
        NIMBLE_PROPERTY::WRITE   |
        NIMBLE_PROPERTY::WRITE_NR |
        NIMBLE_PROPERTY::NOTIFY
    );
    _charOta->setCallbacks(&s_otaCharCallbacks);

    RadioKit.print("BLE: Creating Settings char (0xFFE4)...\n");
    Serial.println("BLE: Creating Settings char (0xFFE4)...");
    _charSettings = pService->createCharacteristic(
        RK_BLE_CHAR_SETTINGS_UUID,
        NIMBLE_PROPERTY::WRITE   |
        NIMBLE_PROPERTY::WRITE_NR |
        NIMBLE_PROPERTY::NOTIFY
    );
    _charSettings->setCallbacks(&s_settingsCharCallbacks);

    RadioKit.print("BLE: Creating Print char (0xFFE5 — notify-only)...\n");
    Serial.println("BLE: Creating Print char (0xFFE5 — notify-only)...");
    _charPrint = pService->createCharacteristic(
        RK_BLE_CHAR_PRINT_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );
    _charPrint->setCallbacks(&s_printCharCallbacks);

    RadioKit.print("BLE: Starting server...\n");
    Serial.println("BLE: Starting server...");
    _server->start();

    RadioKit.print("BLE: Starting advertising...\n");
    Serial.println("BLE: Starting advertising...");
    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    pAdv->addServiceUUID(RK_BLE_SERVICE_UUID);
    pAdv->enableScanResponse(true);
    pAdv->setName(deviceName ? deviceName : "RadioKit");
    // Optimized connection advertising params:
    // minInterval = 0x06 * 0.625ms = 3.75ms, maxInterval = 0x06 * 0.625ms = 3.75ms
    pAdv->setPreferredParams(0x06, 0x06);
    pAdv->start();
    
    RadioKit.print("BLE: System ready.\n");
    Serial.println("BLE: System ready.");
}

/// Select the characteristic matching the frame's protocol by start byte.
NimBLECharacteristic* RadioKitBLE::_charForBuf(const uint8_t* buf) const {
    if (!buf) return _charWidget;
    if (buf[0] == RK_FS_START_BYTE)        return _charFs;
    if (buf[0] == RK_OTA_START_BYTE)       return _charOta;
    if (buf[0] == RK_SETTINGS_START_BYTE)  return _charSettings;
    if (buf[0] == RK_PRINT_START_BYTE)     return _charPrint;
    return _charWidget; // 0x55 (RK_START_BYTE) or unknown
}

void RadioKitBLE::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_connected) {
        return;
    }

    NimBLECharacteristic* target = _charForBuf(buf);
    if (!target) {
        Serial.printf("BLE: Cannot send (no char for protocol 0x%02X)\n", buf ? buf[0] : 0);
        return;
    }
    
    // Re-entrancy guard: if sendPacket is already in progress (e.g., an
    // incoming BLE write is processed during a delay() in the send loop
    // and triggers an outgoing ACK frame), queue the frame in [_pendingBuf]
    // for delivery after the current send completes, rather than dropping it.
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
            
            success = target->notify(safeBuf + offset, chunk);
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
            delay(5);
        }
    }
    
    _sending = false;

    // Deliver any frame that was queued while we were sending.
    if (_pendingLen > 0) {
        uint16_t qLen = _pendingLen;
        _pendingLen = 0;
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

    // Process any pending FS frames that were deferred from the NimBLE host
    // task. LittleFS operations in handleWrite can trigger garbage collection
    // (50-200ms) which would stall the BLE stack's TX queue if called from
    // the host task. By processing here in the main loop, delay() calls
    // inside sendPacket yield to the host task, keeping the TX queue drained.
    if (_hasPendingFs) {
        _processPendingFs();
    }

    // Process any pending OTA frames (same pattern — Update.write does flash
    // I/O that blocks the NimBLE host task if called inline from _onOtaWrite).
    if (_hasPendingOta) {
        _processPendingOta();
    }
}

void RadioKitBLE::_processPendingFs() {
    // Loop instead of recursion: process at most 3 frames per update() call.
    // The phone sends frames sequentially and waits for ACK before sending
    // the next, so 3 is a generous upper bound. Each iteration copies the
    // pending payload to the safe working buffer before clearing the flag.
    for (int i = 0; i < 3 && _hasPendingFs; i++) {
        uint8_t subCmd = _pendingFsSubCmd;
        uint16_t plen = _pendingFsLen;
        if (plen > 0 && plen <= kPendingFsPayloadSize) {
            memcpy(_fsWorkBuf, _pendingFsPayload, plen);
        }
        _hasPendingFs = false;

        if (_fsPacketCallback) {
            _fsPacketCallback(subCmd, plen > 0 ? _fsWorkBuf : nullptr, plen);
        }
    }
}

void RadioKitBLE::_processPendingOta() {
    // Same pattern as _processPendingFs: process at most 3 frames per
    // update() call. Each iteration copies the pending payload to the safe
    // working buffer before clearing the flag, so the NimBLE host task can
    // write new data to _pendingOtaPayload without corrupting what we're
    // processing.
    for (int i = 0; i < 3 && _hasPendingOta; i++) {
        uint8_t subCmd = _pendingOtaSubCmd;
        uint16_t plen = _pendingOtaLen;
        if (plen > 0 && plen <= kPendingOtaPayloadSize) {
            memcpy(_otaWorkBuf, _pendingOtaPayload, plen);
        }
        _hasPendingOta = false;

        if (_otaPacketCallback) {
            _otaPacketCallback(subCmd, plen > 0 ? _otaWorkBuf : nullptr, plen);
        }
    }
}

void RadioKitBLE::_onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) {
    _connected = true;
    _connHandle = connInfo.getConnHandle();

    _connIntervalMs = (uint16_t)(connInfo.getConnInterval() * 1.25f);
    if (_connIntervalMs < 8) _connIntervalMs = 8;
    RadioKit.printf("BLE: Client connected (handle=%u, interval=%ums)\n",
        _connHandle, _connIntervalMs);
    Serial.printf("BLE: Client connected (handle=%u, interval=%ums)\n",
        _connHandle, _connIntervalMs);

    // Cache the initial (pre-negotiation) MTU
    _negotiatedMtu = pServer->getPeerMTU(_connHandle);
    if (_negotiatedMtu < 3) _negotiatedMtu = RK_BLE_MTU;
    RadioKit.printf("BLE: Initial MTU = %u (will update after negotiation)\n", _negotiatedMtu);
    Serial.printf("BLE: Initial MTU = %u (will update after negotiation)\n", _negotiatedMtu);

    // ── Post-connection optimizations ─────────────────────────────

    pServer->updateConnParams(_connHandle, 6, 8, 0, 400);
    RadioKit.print("BLE: Requested connection params (7.5-10ms, lat=0, timeout=4s)\n");
    Serial.println("BLE: Requested connection params (7.5-10ms, lat=0, timeout=4s)");

    pServer->setDataLen(_connHandle, 251);
    RadioKit.print("BLE: Requested data length 251 (DLE)\n");
    Serial.println("BLE: Requested data length 251 (DLE)");

    pServer->updatePhy(_connHandle, BLE_GAP_LE_PHY_2M_MASK, BLE_GAP_LE_PHY_2M_MASK, 0);
    RadioKit.print("BLE: Requested 2M PHY update\n");
    Serial.println("BLE: Requested 2M PHY update");
}

void RadioKitBLE::_onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo) {
    _negotiatedMtu = MTU;
    RadioKit.printf("BLE: MTU negotiated to %u\n", MTU);
    Serial.printf("BLE: MTU negotiated to %u\n", MTU);
}

void RadioKitBLE::_onDisconnect() {
    _connected = false;
    _sending = false;
    _hasPendingFs = false;
    _hasPendingOta = false;
    _connHandle = 0xFFFF;
    _negotiatedMtu = RK_BLE_MTU;
    _needRestartAdv = true;
    rk_rxReset();
    rk_fsRxReset();
    rk_otaRxReset();
    RadioKit.print("BLE: Client disconnected\n");
    Serial.println("BLE: Client disconnected");
}

void RadioKitBLE::setFsCallback(RK_FsPacketCallback cb) {
    _fsPacketCallback = cb;
}

void RadioKitBLE::setOtaCallback(RK_OtaPacketCallback cb) {
    _otaPacketCallback = cb;
}

void RadioKitBLE::setSettingsCallback(RK_SettingsPacketCallback cb) {
    _settingsPacketCallback = cb;
}

void RadioKitBLE::setPrintCallback(RK_PrintPacketCallback cb) {
    _printPacketCallback = cb;
}

// ── Per-characteristic write handlers ─────────────────────────────────────
// Each handler feeds bytes directly into the appropriate state-machine parser.
// No dispatch-by-start-byte needed — the characteristic itself identifies the protocol.

void RadioKitBLE::_onWidgetWrite(const uint8_t* data, size_t len) {
    uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++) {
        if (rk_rxFeedByte(data[i], cmd, payload, payloadLen)) {
            if (_packetCallback) _packetCallback(cmd, payload, payloadLen);
        }
    }
}

void RadioKitBLE::_onFsWrite(const uint8_t* data, size_t len) {
    uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++) {
        if (rk_fsRxFeedByte(data[i], subCmd, payload, payloadLen)) {
            // Defer callback to update() to avoid blocking the NimBLE host
            // task with LittleFS operations. Copy the payload to our own
            // buffer since rk_fsRxFeedByte's returned payload pointer is into
            // the FS state machine's internal rx buffer (s_fsBuf).
            _pendingFsSubCmd = subCmd;
            _pendingFsLen = payloadLen;
            if (payload && payloadLen > 0 && payloadLen <= kPendingFsPayloadSize) {
                memcpy(_pendingFsPayload, payload, payloadLen);
            }
            _hasPendingFs = true;
        }
    }
}

void RadioKitBLE::_onOtaWrite(const uint8_t* data, size_t len) {
    uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++) {
        if (rk_otaRxFeedByte(data[i], subCmd, payload, payloadLen)) {
            // Defer callback to update() to avoid blocking the NimBLE host
            // task with Update.write() flash I/O. Copy the payload to our own
            // buffer since rk_otaRxFeedByte's returned payload pointer is into
            // the OTA state machine's internal rx buffer (s_otaBuf).
            _pendingOtaSubCmd = subCmd;
            _pendingOtaLen = payloadLen;
            if (payload && payloadLen > 0 && payloadLen <= kPendingOtaPayloadSize) {
                memcpy(_pendingOtaPayload, payload, payloadLen);
            }
            _hasPendingOta = true;
        }
    }
}

void RadioKitBLE::_onSettingsWrite(const uint8_t* data, size_t len) {
    uint8_t subCmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++) {
        if (rk_settingsRxFeedByte(data[i], subCmd, payload, payloadLen)) {
            if (_settingsPacketCallback) {
                _settingsPacketCallback(subCmd, payload, payloadLen);
            }
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

void RadioKitBLE::updateAdvertisingName(const char* name) {
    if (!name) return;
    
    RadioKit.printf("BLE: Updating advertising name to '%s'\n", name);
    Serial.printf("BLE: Updating advertising name to '%s'\n", name);
    
    // Update at the NimBLE device level so that after disconnection the
    // re-start of advertising (triggered by _needRestartAdv -> update())
    // picks up the new name rather than the original name from ::init().
    NimBLEDevice::setDeviceName(name);
    
    // Also update on the advertising object for the current advertising run.
    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    if (pAdv) {
        pAdv->stop();
        pAdv->setName(name);
        pAdv->start();
    }
    
    RadioKit.print("BLE: Advertising re-started with new name\n");
    Serial.println("BLE: Advertising re-started with new name");
}

#else // !defined(RK_ENABLE_BLE) — no-op stubs for non-BLE platforms

RadioKitBLE RadioKitBLEInstance;

RadioKitBLE::RadioKitBLE()
    : _server(nullptr), _charWidget(nullptr), _charFs(nullptr), _charOta(nullptr), _charSettings(nullptr), _charPrint(nullptr)
    , _packetCallback(nullptr), _fsPacketCallback(nullptr)
    , _otaPacketCallback(nullptr), _settingsPacketCallback(nullptr), _printPacketCallback(nullptr)
    , _connected(false), _sending(false), _needRestartAdv(false)
    , _negotiatedMtu(20), _connHandle(0xFFFF)
    , _connIntervalMs(0), _pendingLen(0)
    , _pendingFsSubCmd(0), _pendingFsLen(0), _hasPendingFs(false)
    , _pendingOtaSubCmd(0), _pendingOtaLen(0), _hasPendingOta(false)
{}

void RadioKitBLE::begin(const char* /*deviceName*/, RK_PacketCallback /*cb*/) {}
void RadioKitBLE::setFsCallback(RK_FsPacketCallback /*cb*/) {}
void RadioKitBLE::setOtaCallback(RK_OtaPacketCallback /*cb*/) {}
void RadioKitBLE::setSettingsCallback(RK_SettingsPacketCallback /*cb*/) {}
void RadioKitBLE::setPrintCallback(RK_PrintPacketCallback /*cb*/) {}
void RadioKitBLE::update() {}
void RadioKitBLE::sendPacket(const uint8_t* /*buf*/, uint16_t /*len*/) {}
// isConnected() is defined inline in the header
int8_t RadioKitBLE::getRssi() { return 0; }
void RadioKitBLE::updateAdvertisingName(const char* /*name*/) {}
void RadioKitBLE::_onConnect(NimBLEServer* /*pServer*/, NimBLEConnInfo& /*connInfo*/) {}
void RadioKitBLE::_onDisconnect() {}
void RadioKitBLE::_onMTUChange(uint16_t /*MTU*/, NimBLEConnInfo& /*connInfo*/) {}
void RadioKitBLE::_onWidgetWrite(const uint8_t* /*data*/, size_t /*len*/) {}
void RadioKitBLE::_onFsWrite(const uint8_t* /*data*/, size_t /*len*/) {}
void RadioKitBLE::_onOtaWrite(const uint8_t* /*data*/, size_t /*len*/) {}
void RadioKitBLE::_onSettingsWrite(const uint8_t* /*data*/, size_t /*len*/) {}
void RadioKitBLE::_processPendingFs() {}
void RadioKitBLE::_processPendingOta() {}

#endif // defined(RK_ENABLE_BLE)
