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

// ── TX contention diagnostics ──
uint16_t RadioKitBLE::s_pendingDrops = 0;
uint32_t RadioKitBLE::s_lastDiagLog = 0;
uint8_t  RadioKitBLE::s_txQueueMaxDepth = 0;

// ── Static Callback Instances (Avoids heap allocation/fragmentation) ──
class RKServerCallbacks : public NimBLEServerCallbacks {
public:
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override { 
        RadioKitBLEInstance._onConnect(pServer, connInfo);
    }
    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override { 
        RadioKitBLEInstance._onDisconnect(reason); 
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
        RadioKitBLEInstance._onWidgetSubscribe(subValue);
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
    , _connIntervalMs(12), _pendingHead(0), _pendingTail(0), _pendingCount(0)
    , _pendingFsSubCmd(0), _pendingFsLen(0), _hasPendingFs(false)
    , _pendingOtaSubCmd(0), _pendingOtaLen(0), _hasPendingOta(false)
    , _txTaskHandle(nullptr), _txSemaphore(nullptr), _txTaskRunning(false)
{
    portMUX_INITIALIZE(&_txMux);
}

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
    NimBLEAdvertisementData advData;
    advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
    advData.addServiceUUID(NimBLEUUID(RK_BLE_SERVICE_UUID));
    pAdv->setAdvertisementData(advData);

    NimBLEAdvertisementData scanData;
    scanData.setName(deviceName ? deviceName : "RadioKit");
    pAdv->setScanResponseData(scanData);
    pAdv->enableScanResponse(true);

    pAdv->start();
    
    RadioKit.print("BLE: System ready.\n");
    Serial.println("BLE: System ready.");

    // Create the non-blocking TX task and semaphore
    _txSemaphore = xSemaphoreCreateBinary();
    if (_txSemaphore) {
        xTaskCreatePinnedToCore(
            ble_tx_task,     // Entry point
            "ble_tx",        // Task name
            4096,            // Stack size (4KB — enough for sendPacket locals)
            this,            // Parameter = this instance
            1,               // Low priority (below NimBLE host task)
            &_txTaskHandle,
            0                // Core 0 (protocol core)
        );
        _txTaskRunning = true;
        RadioKit.print("BLE: TX task started\n");
        Serial.println("BLE: TX task started");
    }
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
    if (!_connected || !buf || len == 0) {
        return;
    }

    // Direct sliced transmission for bulk frames (FS 0xAA, OTA 0xBB) or frames larger than ring slot
    if (buf[0] == RK_FS_START_BYTE || buf[0] == RK_OTA_START_BYTE || len > RK_MAX_PACKET_SIZE) {
        NimBLECharacteristic* target = _charForBuf(buf);
        if (!target) return;

        uint16_t mtu = _negotiatedMtu;
        if (mtu < 23) mtu = 23;
        mtu -= 3;

        uint16_t offset = 0;
        while (offset < len && _connected) {
            uint16_t chunk = len - offset;
            if (chunk > mtu) chunk = mtu;

            bool success = false;
            for (int retry = 0; retry < 50 && !success; retry++) {
                if (!_connected) break;
                success = (_connHandle != 0xFFFF)
                    ? target->notify(buf + offset, chunk, _connHandle)
                    : target->notify(buf + offset, chunk);
                if (!success) delay(10);
            }
            if (!success) {
                Serial.printf("BLE: bulk notify failed at offset %u/%u\n", offset, len);
                break;
            }
            offset += chunk;
            if (offset < len) delay(5);
        }
        return;
    }

    if (!_txSemaphore) return;

    // Non-blocking enqueue for widget & telemetry frames: copy into ring buffer slot and signal TX task.
    // The main loop() returns immediately — no BLE blocking.
    bool enqueued = false;
    portENTER_CRITICAL(&_txMux);
    if (_pendingCount < kPendingRingSize && len <= RK_MAX_PACKET_SIZE) {
        PendingFrame& slot = _pendingRing[_pendingHead];
        memcpy(slot.data, buf, len);
        slot.len = len;
        _pendingHead = (_pendingHead + 1) % kPendingRingSize;
        _pendingCount++;
        if (_pendingCount > s_txQueueMaxDepth) s_txQueueMaxDepth = _pendingCount;
        enqueued = true;
    } else {
        s_pendingDrops++;
    }
    portEXIT_CRITICAL(&_txMux);

    if (enqueued) {
        xSemaphoreGive(_txSemaphore);
    }
}

// ── Non-blocking TX task ──────────────────────────────────────────────────
// Runs on core 0 (protocol core), blocks on semaphore when idle.
// Drains the ring buffer one frame at a time, sending via BLE notify.

void RadioKitBLE::ble_tx_task(void* pvParameters) {
    RadioKitBLE* self = static_cast<RadioKitBLE*>(pvParameters);
    while (self->_txTaskRunning) {
        // Block until frames are enqueued (zero CPU when idle)
        if (xSemaphoreTake(self->_txSemaphore, pdMS_TO_TICKS(100)) == pdTRUE) {
            self->_drainTxQueue();
        }
    }
    vTaskDelete(nullptr);
}

void RadioKitBLE::_drainTxQueue() {
    while (_pendingCount > 0 && _connected) {
        PendingFrame frame;
        portENTER_CRITICAL(&_txMux);
        if (_pendingCount == 0) {
            portEXIT_CRITICAL(&_txMux);
            break;
        }
        frame = _pendingRing[_pendingTail];
        _pendingTail = (_pendingTail + 1) % kPendingRingSize;
        _pendingCount--;
        portEXIT_CRITICAL(&_txMux);

        NimBLECharacteristic* target = _charForBuf(frame.data);
        if (target && frame.len > 0 && _connected) {
            uint16_t mtu = _negotiatedMtu;
            if (mtu < 23) mtu = 23;
            mtu -= 3;

            if (frame.len <= mtu) {
                target->notify(frame.data, frame.len);
            } else {
                uint16_t offset = 0;
                while (offset < frame.len && _connected) {
                    uint16_t chunk = frame.len - offset;
                    if (chunk > mtu) chunk = mtu;
                    bool success = false;
                    for (int retry = 0; retry < 50 && !success; retry++) {
                        if (!_connected) break;
                        success = (_connHandle != 0xFFFF)
                            ? target->notify(frame.data + offset, chunk, _connHandle)
                            : target->notify(frame.data + offset, chunk);
                        if (!success) delay(5);
                    }
                    offset += chunk;
                    if (offset < frame.len) delay(5);
                }
            }
        }
        vTaskDelay(pdMS_TO_TICKS(5));
    }
}

void RadioKitBLE::update() {
    if (_needRestartAdv) {
        _needRestartAdv = false;
        NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
        if (pAdv && !pAdv->isAdvertising()) {
            pAdv->start();
        }
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
    _connected = false; // Remains false until client subscribes to widget char
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
}

void RadioKitBLE::_onMTUChange(uint16_t MTU, NimBLEConnInfo& connInfo) {
    _negotiatedMtu = MTU;
    RadioKit.printf("BLE: MTU negotiated to %u\n", MTU);
    Serial.printf("BLE: MTU negotiated to %u\n", MTU);
}

void RadioKitBLE::_onWidgetSubscribe(uint16_t subValue) {
    Serial.printf("BLE: Widget char subscribed (subValue=%d)\n", subValue);
    if (subValue != 0) {
        _connected = true;
        RadioKit.pushConfigAndVars();
    } else {
        _connected = false;
    }
}

void RadioKitBLE::_onDisconnect(int reason) {
    portENTER_CRITICAL(&_txMux);
    _connected = false;
    _sending = false;
    _pendingHead = 0;
    _pendingTail = 0;
    _pendingCount = 0;
    s_pendingDrops = 0;  // clean slate for new connection
    s_lastDiagLog = 0;
    s_txQueueMaxDepth = 0;
    _hasPendingFs = false;
    _hasPendingOta = false;
    _connHandle = 0xFFFF;
    _negotiatedMtu = RK_BLE_MTU;
    portEXIT_CRITICAL(&_txMux);
    rk_rxReset();
    rk_fsRxReset();
    rk_otaRxReset();
    RadioKit.printf("BLE: Client disconnected (reason=%d, 0x%02X)\n", reason, reason);
    Serial.printf("BLE: Client disconnected (reason=%d, 0x%02X)\n", reason, reason);

    NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
    if (pAdv) {
        pAdv->start();
    }
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
        NimBLEAdvertisementData scanData;
        scanData.setName(name);
        pAdv->setScanResponseData(scanData);
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
    , _connIntervalMs(0), _pendingHead(0), _pendingTail(0), _pendingCount(0)
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
