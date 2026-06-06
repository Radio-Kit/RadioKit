/**
 * RadioKitBLE.cpp
 * BLE transport implementation using NimBLE-Arduino.
 */

#include "RadioKitBLE.h"
#include "../RadioKitProtocol.h"
#include "../RadioKit.h"
#include "RadioKitFS.h"
#include <NimBLEDevice.h>

#define RK_BLE_SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define RK_BLE_CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"

#define RK_BLE_MTU 20

RadioKitBLE RadioKitBLEInstance;

// ── Static Callback Instances (Avoids heap allocation/fragmentation) ──
class RKServerCallbacks : public NimBLEServerCallbacks {
public:
    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override { 
        RadioKitBLEInstance._onConnect();
    }
    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override { 
        RadioKitBLEInstance._onDisconnect(); 
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
    , _connected(false), _needRestartAdv(false)
{}

void RadioKitBLE::begin(const char* deviceName, RK_PacketCallback cb) {
    _packetCallback   = cb;
    _fsPacketCallback = nullptr;
    _connected        = false;
    _needRestartAdv   = false;

    // Pulse the LED to show we reached begin()
    pinMode(7, OUTPUT);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW); delay(100);
    digitalWrite(7, HIGH); delay(100); digitalWrite(7, LOW);

    Serial.println("BLE: Initializing stack...");
    NimBLEDevice::init(deviceName ? deviceName : "RadioKit");
    
    Serial.println("BLE: Creating server...");
    _server = NimBLEDevice::createServer();
    _server->setCallbacks(&s_serverCallbacks);

    Serial.println("BLE: Creating service...");
    NimBLEService* pService = _server->createService(RK_BLE_SERVICE_UUID);

    Serial.println("BLE: Creating characteristic...");
    _characteristic = pService->createCharacteristic(
        RK_BLE_CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::WRITE_NR | 
        NIMBLE_PROPERTY::NOTIFY |
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
    pAdv->setPreferredParams(0x06, 0x06);
    pAdv->start();
    
    Serial.println("BLE: System ready.");
}

void RadioKitBLE::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_connected || !_characteristic) {
        Serial.printf("BLE: Cannot send (connected=%d, char=%p)\n", _connected, _characteristic);
        return;
    }
    
    uint16_t mtu = RK_BLE_MTU;
    if (_server) {
        std::vector<uint16_t> peers = _server->getPeerDevices();
        if (!peers.empty()) {
            mtu = _server->getPeerMTU(peers[0]) - 3; // Subtract 3 for ATT header
            if (mtu < 20) mtu = 20;
        }
    }

    uint16_t offset = 0;
    while (offset < len) {
        uint16_t chunk = len - offset;
        if (chunk > mtu) chunk = mtu;
        bool success = _characteristic->notify(buf + offset, chunk);
        offset += chunk;
        if (offset < len && !success) delay(50); // Delay if queue is full
        else if (offset < len) delay(20); // Normal pacing
    }
}

void RadioKitBLE::update() {
    if (_needRestartAdv) {
        _needRestartAdv = false;
        delay(500);
        NimBLEDevice::getAdvertising()->start();
    }
}

void RadioKitBLE::_onConnect()    { _connected = true; }
void RadioKitBLE::_onDisconnect() { _connected = false; _needRestartAdv = true; rk_rxReset(); rk_fsRxReset(); }

void RadioKitBLE::setFsCallback(RK_FsPacketCallback cb) {
    _fsPacketCallback = cb;
}

void RadioKitBLE::_onWrite(const uint8_t* data, size_t len) {
    uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
    for (size_t i = 0; i < len; i++) {
        if (rk_rxFeedByte(data[i], cmd, payload, payloadLen)) {
            if (_packetCallback) _packetCallback(cmd, payload, payloadLen);
            continue;
        }
        if (rk_fsRxFeedByte(data[i], cmd, payload, payloadLen)) {
            if (_fsPacketCallback) _fsPacketCallback(cmd, payload, payloadLen);
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
