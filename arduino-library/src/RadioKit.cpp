/**
 * RadioKit.cpp
 * OOP widget registry, protocol dispatch, serialization (v2.0 / Protocol v3).
 */

#include "RadioKit.h"
#include "connection/RadioKitFsHandlers.h"
#include "connection/RadioKitOTA.h"
#include <string.h>

// ── OTA support (ESP32 Update.h + esp_ota_ops) ──────────────────────────────
#if defined(ESP32)
#include <Update.h>
#include <esp_ota_ops.h>
#define RK_HAS_OTA 1
#else
#define RK_HAS_OTA 0
#endif

// ── Debug logging (enabled by default for debugging) ────────────────────
// Set to 1 to enable verbose debug output
#define RK_DEBUG_VERBOSE 0

#if RK_DEBUG_VERBOSE
#define RK_DEBUG_PRINT(fmt, ...) Serial.printf(fmt, ##__VA_ARGS__)
#else
#define RK_DEBUG_PRINT(fmt, ...)
#endif

// ── CONF_DATA / META_DATA payload buffer sizes ──────────────────────────
#define RK_STR_BUF_SIZE 640

RadioKitClass RadioKit;
static RadioKitClass* s_instance = nullptr;

// Forward-declared in Widget.cpp
extern void RadioKit_Widget_drainDeferred();

RadioKitClass::RadioKitClass()
    : _widgetCount(0)
    , _transport(nullptr)
    , _pendingUpdatesMask(0)
    , _varUpdateSeq(0)
    , _pendingMetaMask(0)
    , _metaUpdateSeq(0)
    , _nvsActive(false)
    , _authenticated(false)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf,   0, sizeof(_txBuf));
    memset(_shadowInput, 0, sizeof(_shadowInput));
    memset(_nvsName, 0, sizeof(_nvsName));
    memset(_nvsDesc, 0, sizeof(_nvsDesc));
    memset(_nvsPwd,  0, sizeof(_nvsPwd));
    s_instance = this;
}

void RadioKitClass::_registerWidget(RadioKit_Widget* widget) {
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) return;
    widget->widgetId = _widgetCount;
    _widgets[_widgetCount++] = widget;
}

void RadioKitClass::begin() {
    RadioKit_Widget_drainDeferred();
    // Auto-mount the FS. The handler namespace is a no-op when LittleFS
    // is unavailable, in which case all FS commands reply with NO_FS.
    RKFs::setSender(&RadioKitClass::_sendFsFrame);
    rk_fsSetCallback(&RadioKitClass::_onFsPacket);
    RKFs::begin();

    // ── Initialise NVS and load config ──────────────────────────────
    _nvsActive = RKNvs::init();

    if (_nvsActive) {
        // Check if NVS already has our config keys
        char testName[RADIOKIT_MAX_NAME + 1];
        bool hasExisting = RKNvs::readString(RK_NVS_KEY_NAME, testName, sizeof(testName));

        if (!hasExisting) {
            // First boot — write compile-time defaults to NVS
            RKNvs::writeString(RK_NVS_KEY_NAME, config.name ? config.name : "");
            RKNvs::writeString(RK_NVS_KEY_DESC, config.description ? config.description : "");
            RKNvs::writeString(RK_NVS_KEY_PWD,  config.password ? config.password : "");
            RKNvs::commit();
        }

        // Load NVS values into internal buffers (these override RK_Config)
        _syncNvsToBuffers();
    } else {
        // NVS not available — copy compile-time defaults as fallback
        strncpy(_nvsName, config.name ? config.name : "", sizeof(_nvsName) - 1);
        strncpy(_nvsDesc, config.description ? config.description : "", sizeof(_nvsDesc) - 1);
        strncpy(_nvsPwd,  config.password ? config.password : "", sizeof(_nvsPwd) - 1);
    }

    // Reset auth state on boot
    _authenticated = (_nvsPwd[0] == '\0');  // No password = pre-authenticated
}

void RadioKitClass::pushUpdate(uint8_t widgetId) {
    if (widgetId < _widgetCount && widgetId < 32) {
        _pendingUpdatesMask |= (1UL << widgetId);
    }
}

void RadioKitClass::pushMetaUpdate(uint8_t widgetId) {
    if (widgetId < _widgetCount && widgetId < 32) {
        _pendingMetaMask |= (1UL << widgetId);
    }
}

void RadioKitClass::startBLE(const char* deviceName) {
    // Use NVS-backed name if available, else fall back to provided name or config.name
    const char* baseName;
    if (_nvsActive && _nvsName[0] != '\0') {
        baseName = _nvsName;
    } else if (deviceName && deviceName[0] != '\0') {
        baseName = deviceName;
    } else {
        baseName = config.name;
    }
    // Prefix "RK_" to the BLE broadcast name so the app can reliably filter
    // by name prefix. The config.name (without prefix) is sent in CONF_DATA
    // and displayed in the app UI.
    static char bleAdvName[RADIOKIT_MAX_NAME + 4]; // 3 for "RK_" + null
    snprintf(bleAdvName, sizeof(bleAdvName), "RK_%s", baseName ? baseName : "RadioKit");
    _transport = &RadioKitBLEInstance;
    _transport->begin(bleAdvName, RadioKitClass::_onPacket);
    _transport->setFsCallback(RadioKitClass::_onFsPacket);
    rk_otaSetCallback(RadioKitClass::_onOtaPacket);
    _transport->setOtaCallback(RadioKitClass::_onOtaPacket);
}

void RadioKitClass::startSerial(Stream& stream) {
    _transport = &RadioKitSerialInstance;
    RadioKitSerialInstance.begin(stream, RadioKitClass::_onPacket);
    RadioKitSerialInstance.setFsCallback(RadioKitClass::_onFsPacket);
    rk_otaSetCallback(RadioKitClass::_onOtaPacket);
    RadioKitSerialInstance.setOtaCallback(RadioKitClass::_onOtaPacket);
}

void RadioKitClass::update() {
    if (_transport) _transport->update();

    // Track connection state to reset auth on disconnect
    static bool s_lastConnected = false;
    if (_transport) {
        bool nowConnected = _transport->isConnected();
        if (s_lastConnected && !nowConnected) {
            // Connection was lost — reset auth so new client must re-authenticate
            _authenticated = (_nvsPwd[0] == '\0');  // No pwd = pre-authed
        }
        s_lastConnected = nowConnected;
    }

    if (_transport && _transport->isConnected()) {
        for (uint8_t i = 0; i < _widgetCount; i++) {
            RadioKit_Widget* w = _widgets[i];
            uint8_t inSz = w->inputSize();
            if (inSz > 0 && inSz <= 4) {
                uint8_t currentBuf[4] = {0};
                w->serializeInput(currentBuf);
                bool match = (memcmp(currentBuf, _shadowInput[i], inSz) == 0);
                if (!match) {
                    RK_DEBUG_PRINT("[DBG]   -> shadow MISMATCH for widget %d! Updating and pushing\n", i);
                    memcpy(_shadowInput[i], currentBuf, inSz);
                    pushUpdate(i);
                }
            }
        }
    }

    // ── Batch-fire all pending VAR_UPDATE / SET_INPUT ─────────────
    if (_pendingUpdatesMask != 0 && _transport && _transport->isConnected()) {
        for (uint8_t i = 0; i < 32; i++) {
            if (_pendingUpdatesMask & (1UL << i)) {
                RadioKit_Widget* w = _widgets[i];
                uint8_t inSz = w->inputSize();
                uint8_t outSz = w->outputSize();
                uint8_t dataSz = inSz > 0 ? inSz : outSz;
                if (dataSz == 0) continue;

                uint8_t payload[2 + dataSz];
                payload[0] = i;
                payload[1] = ++_varUpdateSeq;
                uint8_t cmd;
                if (inSz > 0) {
                    w->serializeInput(&payload[2]);
                    cmd = RK_CMD_SET_INPUT;
                } else {
                    w->serializeOutput(&payload[2]);
                    cmd = RK_CMD_VAR_UPDATE;
                }
                uint8_t pktBuf[RK_MAX_PACKET_SIZE];
                uint16_t pktLen = rk_buildPacket(pktBuf, cmd, payload, 2 + dataSz);
                _sendPacket(pktBuf, pktLen);
            }
        }
        _pendingUpdatesMask = 0;
    }

    // ── Batch-fire all pending META_UPDATE ────────────────────────
    if (_pendingMetaMask != 0 && _transport && _transport->isConnected()) {
        for (uint8_t i = 0; i < 32; i++) {
            if (_pendingMetaMask & (1UL << i)) {
                RadioKit_Widget* w = _widgets[i];
                uint8_t pktBuf[RK_MAX_PACKET_SIZE];
                uint8_t payload[2 + RK_STR_BUF_SIZE];
                payload[0] = i;
                payload[1] = ++_metaUpdateSeq;
                uint16_t strLen = w->serializeStrings(&payload[2]);
                uint16_t pktLen = rk_buildPacket(pktBuf, RK_CMD_META_UPDATE, payload, 2 + strLen);
                _sendPacket(pktBuf, pktLen);
            }
        }
        _pendingMetaMask = 0;
    }
}

bool RadioKitClass::isConnected() const {
    return _transport ? _transport->isConnected() : false;
}

void RadioKitClass::_onPacket(uint8_t cmd,
                              const uint8_t* payload,
                              uint16_t payloadLen)
{
    if (!s_instance) return;

    // ── Auth gate ───────────────────────────────────────────────────
    // If a password is set and the session is not yet authenticated,
    // only allow CMD_PWD_AUTH, CMD_GET_CONF, and CMD_GET_FEATURES.
    if (!s_instance->_authenticated && s_instance->_nvsPwd[0] != '\0') {
        if (cmd != RK_CMD_PWD_AUTH && cmd != RK_CMD_GET_CONF && cmd != RK_CMD_GET_FEATURES) {
            Serial.printf("RK: Rejected CMD 0x%02X — not authenticated\n", cmd);
            uint8_t err = RK_PWD_AUTH_MISMATCH;
            uint16_t len = rk_buildPacket(s_instance->_txBuf, RK_CMD_ACK, &err, 1);
            s_instance->_sendPacket(len);
            return;
        }
    }

    RK_DEBUG_PRINT("RK: Dispatching CMD %s (0x%02X), len %d\n", rk_cmdName(cmd), cmd, payloadLen);
    switch (cmd) {
        case RK_CMD_GET_CONF:   s_instance->_handleGetConf();                       break;
        case RK_CMD_GET_VARS:   s_instance->_handleGetVars();                       break;
        case RK_CMD_GET_META:   s_instance->_handleGetMeta();                       break;
        case RK_CMD_SET_INPUT:  s_instance->_handleSetInput(payload, payloadLen);   break;
        case RK_CMD_GET_TELEMETRY: s_instance->_handleGetTelemetry();                break;
        case RK_CMD_PING:       s_instance->_handlePing();                          break;
        case RK_CMD_ACK:        s_instance->_handleAck(payload, payloadLen);        break;
        case RK_CMD_VAR_UPDATE: s_instance->_handleVarUpdate(payload, payloadLen);  break;
        case RK_CMD_META_UPDATE:s_instance->_handleMetaUpdate(payload, payloadLen); break;
        case RK_CMD_BLE_INFO:   s_instance->_handleBleInfo();                        break;
        case RK_CMD_GET_FEATURES: s_instance->_handleGetFeatures();                   break;
        case RK_CMD_GET_CHIP_INFO: s_instance->_handleGetChipInfo();                   break;
        case RK_CMD_SET_CONF:   s_instance->_handleSetConf(payload, payloadLen);    break;
        case RK_CMD_PWD_AUTH:   s_instance->_handlePwdAuth(payload, payloadLen);    break;
        case RK_CMD_FACTORY_RESET: s_instance->_handleFactoryReset();                 break;
        default: 
            Serial.printf("RK: Unknown CMD %s (0x%02X)\n", rk_cmdName(cmd), cmd);
            break;
    }
}

int8_t RadioKitClass::getRssi() {
    if (_transport) return _transport->getRssi();
    return 0;
}

void RadioKitClass::_handleBleInfo() {
    if (!_transport) return;
    
    // Payload: [connIntervalMs(2 LE)] [negotiatedMtu(2 LE)] [rssi(1)]
    uint8_t payload[5];
    uint16_t interval = RadioKitBLEInstance.getConnIntervalMs();
    uint16_t mtu = RadioKitBLEInstance.getNegotiatedMtu();
    int r = getRssi();
    
    payload[0] = interval & 0xFF;
    payload[1] = (interval >> 8) & 0xFF;
    payload[2] = mtu & 0xFF;
    payload[3] = (mtu >> 8) & 0xFF;
    payload[4] = (uint8_t)r;
    
    uint16_t len = rk_buildPacket(_txBuf, RK_CMD_BLE_INFO_DATA, payload, 5);
    _sendPacket(len);
}

void RadioKitClass::_handleGetFeatures() {
    if (!_transport) return;
    
    uint8_t bitmask = 0;
    
#if RK_HAS_OTA
    bitmask |= RK_FEATURE_OTA;
#endif
    
#if RK_FS_HAS_LITTLEFS
    bitmask |= RK_FEATURE_FILESYSTEM;
#endif
    
    // Report if a non-empty password is set in NVS
    if (_nvsActive && _nvsPwd[0] != '\0') {
        bitmask |= RK_FEATURE_HAS_PASSWORD;
    }
    
    RK_DEBUG_PRINT("RK: Reporting features bitmask: 0x%02X\n", bitmask);
    uint16_t len = rk_buildPacket(_txBuf, RK_CMD_FEATURES_DATA, &bitmask, 1);
    _sendPacket(len);
}

void RadioKitClass::_handleGetTelemetry() {
    if (!_transport) return;
    
    uint8_t payload[4];
    int r = getRssi();
    payload[0] = (uint8_t)r;
    payload[1] = 0; // Reserved for latency
    payload[2] = 0;
    payload[3] = 0;

    // Send full 4-byte payload to match potential app expectations
    uint16_t len = rk_buildPacket(_txBuf, RK_CMD_TELEMETRY_DATA, payload, 4);
    _sendPacket(len);
}

void RadioKitClass::_handleGetConf() {
    uint8_t* payloadPtr = &_txBuf[RK_HEADER_SIZE];
    uint16_t payloadLen = _buildConfPayload(payloadPtr,
                                            RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, payloadPtr, payloadLen);
    _sendPacket(totalLen);
}

void RadioKitClass::_handleGetVars() {
    uint16_t payloadLen = _buildVarPayload(&_txBuf[RK_HEADER_SIZE],
                                           RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA, nullptr, payloadLen);
    _sendPacket(totalLen);
}

void RadioKitClass::_handleGetMeta() {
    uint16_t payloadLen = _buildMetaPayload(&_txBuf[RK_HEADER_SIZE],
                                            RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_META_DATA, nullptr, payloadLen);
    _sendPacket(totalLen);
}

void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    RK_DEBUG_PRINT("[DBG] _handleSetInput: len=%d\n", len);
    uint16_t offset = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->inputSize();
        if (sz == 0) continue;
        if (offset + sz > len) break;
        w->deserializeInput(payload + offset);
        if (sz <= 4) {
            memcpy(_shadowInput[i], payload + offset, sz);
        }
        RK_DEBUG_PRINT("[DBG]   widget[%d]: sz=%d, val=%d\n", i, sz, payload[offset]);
        offset += sz;
    }
    uint8_t seq = 0;
    uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &seq, 1);
    _sendPacket(pkt);
}

void RadioKitClass::_handlePing() {
    uint16_t pkt = rk_buildPong(_txBuf);
    _sendPacket(pkt);
}

void RadioKitClass::_handleAck(const uint8_t* payload, uint16_t len) {
    // ACKs are informational only — shadow comparison provides reliability.
}

void RadioKitClass::_handleVarUpdate(const uint8_t* payload, uint16_t len) {
    if (len < 2) {
        RK_DEBUG_PRINT("[DBG] _handleVarUpdate: too short (%d)\n", len);
        return;
    }
    uint8_t widgetId = payload[0];
    uint8_t seq = payload[1];
    if (widgetId >= _widgetCount) {
        RK_DEBUG_PRINT("[DBG] _handleVarUpdate: invalid widgetId %d\n", widgetId);
        return;
    }

    RadioKit_Widget* w = _widgets[widgetId];
    uint8_t inSz = w->inputSize();
    uint8_t outSz = w->outputSize();
    RK_DEBUG_PRINT("[DBG] _handleVarUpdate: wid=%d seq=%d inSz=%d outSz=%d\n",
        widgetId, seq, inSz, outSz);
    
    if (inSz > 0 && 2 + inSz <= len) {
        uint8_t oldVal = 0;
        w->serializeInput(&oldVal);  // need actual state
        uint8_t newVal = payload[2];
        w->deserializeInput(&payload[2]);
        if (inSz <= 4) {
            RK_DEBUG_PRINT("[DBG]   input: old=%d new=%d, updating shadow\n", oldVal, newVal);
            memcpy(_shadowInput[widgetId], &payload[2], inSz);
        }
    } else if (outSz > 0 && 2 + outSz <= len) {
        // Output widgets (LED, Text) receive VAR_UPDATE for value updates
        // (No deserializeOutput method exists in the base Widget interface)
        RK_DEBUG_PRINT("[DBG]   output: len=%d (ignored, no deserializeOutput)\n", outSz);
    }

    // Ack back to sender
    uint16_t pkt = rk_buildAck(_txBuf, seq);
    _sendPacket(pkt);
}

void RadioKitClass::_handleMetaUpdate(const uint8_t* payload, uint16_t len) {
    if (len < 2) return;
    uint8_t widgetId = payload[0];
    uint8_t seq = payload[1];
    if (widgetId >= _widgetCount) return;

    RadioKit_Widget* w = _widgets[widgetId];
    // Meta update from App to Arduino: App wants to change labels?
    // Not usually used, but we handle it.
    // (Actual implementation would need a deserializeStrings, but we leave it for now)
    
    // Ack back to sender
    uint16_t pkt = rk_buildAck(_txBuf, seq);
    _sendPacket(pkt);
}

// ── CONF_DATA payload builder (Protocol v3) ──────────────────────────────
//
// strBuf worst-case per widget:
//   mask(1)
//   + label:   len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + icon:    len(1) + RADIOKIT_MAX_ICON(24)     = 25
//   + onText:  len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + offText: len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + content: len(1) + RADIOKIT_MAX_ITEMS*(RADIOKIT_MAX_LABEL+RADIOKIT_MAX_ICON+2) pipes
//            = 1 + 8*(32+24+2) = 1 + 464 = 465  (Multiple widget worst case)
// Total worst case = 1+33+25+33+33+465 = 590 bytes → use 640 to be safe.

uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    // Use NVS-backed buffers if available, else fall back to RK_Config
    const char* name    = _nvsActive && _nvsName[0] ? _nvsName : (config.name ? config.name : "");
    const char* desc    = _nvsActive && _nvsDesc[0] ? _nvsDesc : (config.description ? config.description : "");
    const char* themeStr = config.theme            ? config.theme       : RK_DEFAULT;
    uint8_t nameLen  = (uint8_t)strnlen(name,     RADIOKIT_MAX_NAME);
    uint8_t descLen  = (uint8_t)strnlen(desc,     RADIOKIT_MAX_DESC);
    uint8_t themeLen = (uint8_t)strnlen(themeStr, 64);

    // v0x04: no password field (pwd removed from CONF_DATA)
    if (out + 7 + nameLen + descLen + themeLen > bufSize) return 0;

    buf[out++] = RK_PROTOCOL_VERSION;  // 0x04
    buf[out++] = config.orientation;
    buf[out++] = _widgetCount;
    buf[out++] = nameLen;
    memcpy(&buf[out], name, nameLen); out += nameLen;
    buf[out++] = descLen;
    memcpy(&buf[out], desc, descLen); out += descLen;
    buf[out++] = themeLen;
    memcpy(&buf[out], themeStr, themeLen); out += themeLen;

    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];

        if (out + 10 > bufSize) break;
        buf[out++] = w->typeId;
        buf[out++] = w->widgetId;
        buf[out++] = w->x();
        buf[out++] = w->y();
        buf[out++] = w->width();
        buf[out++] = w->height();
        int16_t rot = w->rotation();
        buf[out++] = (uint8_t)(rot & 0xFF);
        buf[out++] = (uint8_t)((rot >> 8) & 0xFF);
        buf[out++] = w->style();
        buf[out++] = w->variant();

        // Write strings directly to the target buffer.
        uint16_t strLen = w->serializeStrings(&buf[out]);
        if (out + strLen <= bufSize) {
            out += strLen;
        } else {
            break; // No more room for this widget's strings
        }
    }
    return out;
}

// ── VAR_DATA payload builder ──────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t inSz = w->inputSize();
        uint8_t outSz = w->outputSize();
        uint8_t sz = (outSz > 0) ? outSz : inSz;
        
        if (sz == 0) continue;
        if (out + sz > bufSize) break;
        
        if (outSz > 0) w->serializeOutput(&buf[out]);
        else w->serializeInput(&buf[out]);
        
        out += sz;
    }
    return out;
}

uint16_t RadioKitClass::_buildMetaPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint16_t strLen = w->serializeStrings(&buf[out]);
        if (out + strLen <= bufSize) {
            out += strLen;
        } else {
            break;
        }
    }
    return out;
}

void RadioKitClass::_sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_transport) return;
    _transport->sendPacket(buf, len);
}

void RadioKitClass::_sendPacket(uint16_t len) {
    if (!_transport) return;
    RK_DEBUG_PRINT("RK: Sending CMD %s (0x%02X), len %d\n", rk_cmdName(_txBuf[3]), _txBuf[3], len);
    _transport->sendPacket(_txBuf, len);
}

// ── Filesystem bulk protocol ────────────────────────────────────────────────

bool RadioKitClass::beginFs() {
    return RKFs::begin();
}

bool RadioKitClass::isFsReady() const {
    return RKFs::isReady();
}

bool RadioKitClass::formatFs() {
    return RKFs::format();
}

void RadioKitClass::sendFsFrame(const uint8_t* buf, uint16_t len) {
    if (!_transport) return;
    _transport->sendPacket(buf, len);
}

void RadioKitClass::_sendFsFrame(const uint8_t* buf, uint16_t len) {
    if (s_instance) s_instance->sendFsFrame(buf, len);
}

void RadioKitClass::_onFsPacket(uint8_t subCmd,
                                const uint8_t* payload,
                                uint16_t payloadLen)
{
    RK_DEBUG_PRINT("RK: Dispatching FS %s (0x%02X), len %d\n",
                   rk_fsCmdName(subCmd), subCmd, payloadLen);
    RKFs::dispatch(subCmd, payload, payloadLen);
}

// ── CHIP_INFO handler ─────────────────────────────────────────────────────

void RadioKitClass::_handleGetChipInfo() {
#if defined(ESP32)
    uint8_t payload[64];
    uint16_t offset = 0;

    // 1. Chip model string (use Arduino ESP32 built-in)
    String modelStr = ESP.getChipModel();
    uint8_t modelLen = modelStr.length();
    if (modelLen > 20) modelLen = 20;
    payload[offset++] = modelLen;
    memcpy(&payload[offset], modelStr.c_str(), modelLen);
    offset += modelLen;

    // 2. Chip revision
    payload[offset++] = ESP.getChipRevision();

    // 3. Number of cores
    payload[offset++] = ESP.getChipCores();

    // 4. Flash size (bytes, LE)
    uint32_t flashSize = ESP.getFlashChipSize();
    payload[offset++] = flashSize & 0xFF;
    payload[offset++] = (flashSize >> 8) & 0xFF;
    payload[offset++] = (flashSize >> 16) & 0xFF;
    payload[offset++] = (flashSize >> 24) & 0xFF;

    // 5. PSRAM size (bytes, LE; 0 if none)
    uint32_t psramSize = ESP.getPsramSize();
    payload[offset++] = psramSize & 0xFF;
    payload[offset++] = (psramSize >> 8) & 0xFF;
    payload[offset++] = (psramSize >> 16) & 0xFF;
    payload[offset++] = (psramSize >> 24) & 0xFF;

    // 6. SDK version string
    String sdkVer = ESP.getSdkVersion();
    uint8_t sdkLen = sdkVer.length();
    if (sdkLen > 30) sdkLen = 30;
    payload[offset++] = sdkLen;
    memcpy(&payload[offset], sdkVer.c_str(), sdkLen);
    offset += sdkLen;

    // 7. MAC address (6 bytes from uint64_t)
    uint64_t macInt = ESP.getEfuseMac();
    uint8_t mac[6];
    mac[0] = (uint8_t)(macInt & 0xFF);
    mac[1] = (uint8_t)((macInt >> 8) & 0xFF);
    mac[2] = (uint8_t)((macInt >> 16) & 0xFF);
    mac[3] = (uint8_t)((macInt >> 24) & 0xFF);
    mac[4] = (uint8_t)((macInt >> 32) & 0xFF);
    mac[5] = (uint8_t)((macInt >> 40) & 0xFF);
    memcpy(&payload[offset], mac, 6);
    offset += 6;

    uint16_t len = rk_buildPacket(_txBuf, RK_CMD_CHIP_INFO_DATA, payload, offset);
    _sendPacket(len);
#else
    // Non-ESP32: send empty payload to signal "not available"
    uint16_t len = rk_buildPacket(_txBuf, RK_CMD_CHIP_INFO_DATA, nullptr, 0);
    _sendPacket(len);
#endif
}

// ── OTA protocol ────────────────────────────────────────────────────────────

// Progress tracking for OTA — persisted across Begin/Chunk calls
static uint32_t s_otaLastProgressPct = 0;
static uint32_t s_otaLastProgressChunk = 0;
static uint32_t s_otaChunkCount = 0;

// OTA bytes written counter, tracked ourselves because ESP32's
// Update.progress() only increments when a full flash sector (4096 bytes)
// is flushed, not after every Update.write() call with partial sectors.
static uint32_t s_otaBytesWritten = 0;

void RadioKitClass::_onOtaPacket(uint8_t subCmd,
                                 const uint8_t* payload,
                                 uint16_t payloadLen)
{
    if (!s_instance) return;
    RK_DEBUG_PRINT("RK: Dispatching OTA %s (0x%02X), len %d\n",
                   rk_otaCmdName(subCmd), subCmd, payloadLen);
    switch (subCmd) {
        case RK_OTA_CMD_BEGIN:  s_instance->_handleOtaBegin(payload, payloadLen); break;
        case RK_OTA_CMD_CHUNK:  s_instance->_handleOtaChunk(payload, payloadLen); break;
        case RK_OTA_CMD_END:    s_instance->_handleOtaEnd(payload, payloadLen);   break;
        case RK_OTA_CMD_ABORT:  s_instance->_handleOtaAbort();                    break;
        default:
            Serial.printf("RK: Unknown OTA sub-command 0x%02X\n", subCmd);
            break;
    }
}

void RadioKitClass::_sendOtaFrame(const uint8_t* buf, uint16_t len) {
    if (s_instance && s_instance->_transport) {
        s_instance->_transport->sendPacket(buf, len);
    }
}

void RadioKitClass::_handleOtaBegin(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 4) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint32_t firmwareSize = (uint32_t)payload[0] |
                           ((uint32_t)payload[1] << 8) |
                           ((uint32_t)payload[2] << 16) |
                           ((uint32_t)payload[3] << 24);

    RK_DEBUG_PRINT("OTA: Begin firmware update, size=%u\n", firmwareSize);

    // Reset progress tracking for fresh OTA session
    s_otaLastProgressPct = 0;
    s_otaLastProgressChunk = 0;
    s_otaChunkCount = 0;
    s_otaBytesWritten = 0;

    // Abort any stale OTA in progress
    Update.abort();
    s_otaBytesWritten = 0;

    if (!Update.begin(firmwareSize)) {
        uint8_t err = RK_OTA_ERR_NO_SPACE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Serial.printf("OTA: Update.begin failed (no space?)\n");
        return;
    }

    uint8_t err = RK_OTA_ERR_OK;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

void RadioKitClass::_handleOtaChunk(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 4) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    if (!Update.isRunning()) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint32_t chunkOffset = (uint32_t)payload[0] |
                          ((uint32_t)payload[1] << 8) |
                          ((uint32_t)payload[2] << 16) |
                          ((uint32_t)payload[3] << 24);
    uint16_t dataLen = len - 4;

    // Use our own progress tracking instead of Update.progress() because
    // ESP32's Update class only increments progress when a full flash sector
    // (4096 bytes) is flushed, not on every Update.write() call.
    if (chunkOffset != s_otaBytesWritten) {
        Serial.printf("OTA: Offset mismatch — got %u, expected %u\n",
            chunkOffset, s_otaBytesWritten);
        uint8_t err = RK_OTA_ERR_SEQ;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    size_t written = Update.write((uint8_t*)(&payload[4]), dataLen);
    if (written != dataLen) {
        Serial.printf("OTA: Write error — wrote %u of %u bytes\n", written, dataLen);
        uint8_t err = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }
    s_otaBytesWritten += written;

    // Send ACK
    uint8_t err = RK_OTA_ERR_OK;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);

    // Send periodic progress notification (every ~5% or every 50 chunks)
    uint32_t total = Update.size();
    uint32_t received = s_otaBytesWritten;
    if (total > 0) {
        uint32_t pct = (received * 100) / total;
        s_otaChunkCount++;
        if (pct >= s_otaLastProgressPct + 5 || s_otaChunkCount - s_otaLastProgressChunk >= 50) {
            s_otaLastProgressPct = pct;
            s_otaLastProgressChunk = s_otaChunkCount;
            uint8_t progBuf[8];
            progBuf[0] = (uint8_t)(received & 0xFF);
            progBuf[1] = (uint8_t)((received >> 8) & 0xFF);
            progBuf[2] = (uint8_t)((received >> 16) & 0xFF);
            progBuf[3] = (uint8_t)((received >> 24) & 0xFF);
            progBuf[4] = (uint8_t)(total & 0xFF);
            progBuf[5] = (uint8_t)((total >> 8) & 0xFF);
            progBuf[6] = (uint8_t)((total >> 16) & 0xFF);
            progBuf[7] = (uint8_t)((total >> 24) & 0xFF);
            uint16_t pLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_PROGRESS, progBuf, 8);
            _sendOtaFrame(rk_otaTxBuf(), pLen);
        }
    }
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

void RadioKitClass::_handleOtaEnd(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 4) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    if (!Update.isRunning()) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint32_t expectedCrc = (uint32_t)payload[0] |
                          ((uint32_t)payload[1] << 8) |
                          ((uint32_t)payload[2] << 16) |
                          ((uint32_t)payload[3] << 24);

    RK_DEBUG_PRINT("OTA: End — expected CRC32=0x%08X\n", expectedCrc);

    if (!Update.end()) {
        // Flash write error during finalisation
        Serial.printf("OTA: Update.end() failed\n");
        uint8_t err = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Update.abort();
        return;
    }

    // Update.end() verifies its own SHA-256 digest internally.
    // Set the boot partition to the new firmware.
    const esp_partition_t* running = esp_ota_get_running_partition();
    const esp_partition_t* next = esp_ota_get_next_update_partition(running);
    if (!next) {
        Serial.printf("OTA: No next OTA partition found\n");
        uint8_t err = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Update.abort();
        return;
    }

    esp_err_t err = esp_ota_set_boot_partition(next);
    if (err != ESP_OK) {
        Serial.printf("OTA: esp_ota_set_boot_partition failed: %d\n", err);
        uint8_t errCode = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &errCode, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Update.abort();
        return;
    }

    // Send success ACK before rebooting
    uint8_t errCode = RK_OTA_ERR_OK;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &errCode, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);

    RK_DEBUG_PRINT("OTA: Complete — rebooting in 100ms...\n");
    delay(100);
    esp_restart();
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

void RadioKitClass::_handleOtaAbort() {
#if RK_HAS_OTA
    RK_DEBUG_PRINT("OTA: Abort requested\n");
    Update.abort();
    s_otaBytesWritten = 0;
    Serial.println("OTA: Aborted — partition released, ready for new OTA");
#else
    Serial.println("OTA: Abort ignored — OTA not supported");
#endif
}

// ── Factory Reset ───────────────────────────────────────────────────────────

void RadioKitClass::_handleFactoryReset() {
    Serial.println("FACTORY RESET: Erasing NVS config and rebooting...");
    
    if (_nvsActive) {
        RKNvs::eraseAll();
        RKNvs::commit();
    }
    
    // Small delay to let the ACK frame be sent before reboot
    delay(100);
#if defined(ESP32)
    esp_restart();
#else
    Serial.println("FACTORY RESET: Reboot not supported on this platform");
#endif
}

// ── NVS Config Helpers ──────────────────────────────────────────────────────

void RadioKitClass::_syncNvsToBuffers() {
    // Clear buffers first
    memset(_nvsName, 0, sizeof(_nvsName));
    memset(_nvsDesc, 0, sizeof(_nvsDesc));
    memset(_nvsPwd,  0, sizeof(_nvsPwd));

    if (!_nvsActive) {
        // Fall back to compile-time defaults
        strncpy(_nvsName, config.name ? config.name : "", sizeof(_nvsName) - 1);
        strncpy(_nvsDesc, config.description ? config.description : "", sizeof(_nvsDesc) - 1);
        strncpy(_nvsPwd,  config.password ? config.password : "", sizeof(_nvsPwd) - 1);
        return;
    }

    // Read from NVS — if a key doesn't exist, use compile-time default
    if (!RKNvs::readString(RK_NVS_KEY_NAME, _nvsName, sizeof(_nvsName))) {
        strncpy(_nvsName, config.name ? config.name : "", sizeof(_nvsName) - 1);
    }
    if (!RKNvs::readString(RK_NVS_KEY_DESC, _nvsDesc, sizeof(_nvsDesc))) {
        strncpy(_nvsDesc, config.description ? config.description : "", sizeof(_nvsDesc) - 1);
    }
    if (!RKNvs::readString(RK_NVS_KEY_PWD, _nvsPwd, sizeof(_nvsPwd))) {
        strncpy(_nvsPwd, config.password ? config.password : "", sizeof(_nvsPwd) - 1);
    }

    RK_DEBUG_PRINT("NVS: Loaded name='%s', desc='%s', pwd=%s\n",
        _nvsName, _nvsDesc, _nvsPwd[0] ? "***" : "(none)");
}

void RadioKitClass::_setBleAdvertisingName(const char* name) {
#if defined(ESP32)
    // Re-start BLE advertising with the new name.
    // NimBLE allows updating the advertiser's name and re-starting.
    extern RadioKitBLE RadioKitBLEInstance;
    if (_transport == &RadioKitBLEInstance && RadioKitBLEInstance.isConnected()) {
        static char bleAdvName[RADIOKIT_MAX_NAME + 4];
        snprintf(bleAdvName, sizeof(bleAdvName), "RK_%s", name ? name : "RadioKit");
        RadioKitBLEInstance.updateAdvertisingName(bleAdvName);
        Serial.printf("NVS: BLE advertising name updated to '%s'\n", bleAdvName);
    }
#else
    (void)name;
#endif
}

// ── Public NVS config API ───────────────────────────────────────────────────

void RadioKitClass::setConfig(const char* name, const char* description, const char* password) {
    if (!_nvsActive) {
        Serial.println("NVS: Cannot set config — NVS not available");
        return;
    }

    bool changed = false;

    if (name && name[0] != '\0' && strncmp(name, _nvsName, RADIOKIT_MAX_NAME) != 0) {
        strncpy(_nvsName, name, sizeof(_nvsName) - 1);
        RKNvs::writeString(RK_NVS_KEY_NAME, _nvsName);
        changed = true;
        // Update BLE advertisement name
        _setBleAdvertisingName(_nvsName);
    }

    if (description && description[0] != '\0' && strncmp(description, _nvsDesc, RADIOKIT_MAX_DESC) != 0) {
        strncpy(_nvsDesc, description, sizeof(_nvsDesc) - 1);
        RKNvs::writeString(RK_NVS_KEY_DESC, _nvsDesc);
        changed = true;
    }

    if (password && strncmp(password, _nvsPwd, RADIOKIT_MAX_PWD) != 0) {
        strncpy(_nvsPwd, password, sizeof(_nvsPwd) - 1);
        RKNvs::writeString(RK_NVS_KEY_PWD, _nvsPwd);
        changed = true;
        // If password was cleared, mark as pre-authenticated
        if (_nvsPwd[0] == '\0') {
            _authenticated = true;
        } else {
            _authenticated = false;  // New password set — re-auth required
        }
    }

    if (changed) {
        RKNvs::commit();
        Serial.println("NVS: Config updated and committed");
    }
}

uint8_t RadioKitClass::authenticate(const char* password) {
    if (!password) return RK_PWD_AUTH_MISMATCH;
    if (_authenticated) return RK_PWD_AUTH_ALREADY;
    if (_nvsPwd[0] == '\0') {
        // No password set — auth is automatic
        _authenticated = true;
        return RK_PWD_AUTH_OK;
    }
    if (strncmp(password, _nvsPwd, RADIOKIT_MAX_PWD) == 0) {
        _authenticated = true;
        return RK_PWD_AUTH_OK;
    }
    return RK_PWD_AUTH_MISMATCH;
}

// ── CMD_SET_CONF handler (0x19) ─────────────────────────────────────────────

void RadioKitClass::_handleSetConf(const uint8_t* payload, uint16_t len) {
    if (!_nvsActive || len < 2) {
        Serial.println("NVS: CMD_SET_CONF ignored — NVS not available or payload too short");
        return;
    }

    uint16_t fieldMask = (uint16_t)payload[0] | ((uint16_t)payload[1] << 8);
    uint16_t offset = 2;
    uint8_t statusMask = fieldMask & 0x7F;  // Clear error bit

    // Name
    if (fieldMask & RK_SET_CONF_NAME) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_NAME) strLen = RADIOKIT_MAX_NAME;
            if (offset + strLen <= len) {
                memcpy(_nvsName, &payload[offset], strLen);
                _nvsName[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_NAME, _nvsName);
                _setBleAdvertisingName(_nvsName);
            }
            offset += strLen;
        }
    }

    // Description
    if (fieldMask & RK_SET_CONF_DESC) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_DESC) strLen = RADIOKIT_MAX_DESC;
            if (offset + strLen <= len) {
                memcpy(_nvsDesc, &payload[offset], strLen);
                _nvsDesc[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_DESC, _nvsDesc);
            }
            offset += strLen;
        }
    }

    // Password
    if (fieldMask & RK_SET_CONF_PWD) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_PWD) strLen = RADIOKIT_MAX_PWD;
            if (offset + strLen <= len) {
                memcpy(_nvsPwd, &payload[offset], strLen);
                _nvsPwd[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_PWD, _nvsPwd);
            }
            offset += strLen;
        }
    }

    // Commit all writes to NVS
    RKNvs::commit();

    // Send ACK with echoed field mask
    uint16_t ackLen = rk_buildPacket(_txBuf, RK_CMD_ACK, (uint8_t*)&statusMask, 1);
    _sendPacket(ackLen);

    // Re-broadcast CONF_DATA so the app can refresh config name/desc
    _handleGetConf();

    // If the password was changed, re-broadcast features so the app updates
    // its hasPassword bitmask. This is critical when the password is cleared
    // (set to empty) — the app needs to know it can skip the auth gate.
    if (fieldMask & RK_SET_CONF_PWD) {
        _handleGetFeatures();
    }

    Serial.printf("NVS: CMD_SET_CONF applied mask=0x%04X\n", fieldMask);
}

// ── CMD_PWD_AUTH handler (0x1A) ─────────────────────────────────────────────

void RadioKitClass::_handlePwdAuth(const uint8_t* payload, uint16_t len) {
    if (len < 1) {
        uint8_t status = RK_PWD_AUTH_MISMATCH;
        uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &status, 1);
        _sendPacket(pkt);
        return;
    }

    uint8_t pwdLen = payload[0];
    if (pwdLen > RADIOKIT_MAX_PWD) pwdLen = RADIOKIT_MAX_PWD;

    // If already authenticated
    if (_authenticated) {
        uint8_t status = RK_PWD_AUTH_ALREADY;
        uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &status, 1);
        _sendPacket(pkt);
        return;
    }

    // No password on device = auto-success
    if (_nvsPwd[0] == '\0') {
        _authenticated = true;
        uint8_t status = RK_PWD_AUTH_OK;
        uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &status, 1);
        _sendPacket(pkt);
        return;
    }

    // Compare passwords
    if (len >= 1 + pwdLen && strncmp((const char*)&payload[1], _nvsPwd, pwdLen) == 0) {
        _authenticated = true;
        uint8_t status = RK_PWD_AUTH_OK;
        uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &status, 1);
        _sendPacket(pkt);
        Serial.println("NVS: Authentication successful");
    } else {
        uint8_t status = RK_PWD_AUTH_MISMATCH;
        uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &status, 1);
        _sendPacket(pkt);
        Serial.println("NVS: Authentication failed — password mismatch");
    }
}
