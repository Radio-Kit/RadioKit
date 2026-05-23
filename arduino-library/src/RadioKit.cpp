/**
 * RadioKit.cpp
 * OOP widget registry, protocol dispatch, serialization (v2.0 / Protocol v3).
 */

#include "RadioKit.h"
#include <string.h>

// ── Debug logging (enabled by default for debugging) ────────────────────
// Set to 1 to enable verbose debug output
#define RK_DEBUG_VERBOSE 1

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
    , _varUpdateSentAt(0)
    , _pendingMetaMask(0)
    , _metaUpdateSeq(0)
    , _metaUpdateId(0)
    , _metaUpdateRetries(0)
    , _metaUpdateSentAt(0)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf,   0, sizeof(_txBuf));
    memset(_shadowInput, 0, sizeof(_shadowInput));
    s_instance = this;
}

void RadioKitClass::_registerWidget(RadioKit_Widget* widget) {
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) return;
    widget->widgetId = _widgetCount;
    _widgets[_widgetCount++] = widget;
}

void RadioKitClass::begin() {
    RadioKit_Widget_drainDeferred();
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
    const char* baseName = (deviceName && deviceName[0] != '\0') ? deviceName : config.name;
    // Prefix "RK_" to the BLE broadcast name so the app can reliably filter
    // by name prefix. The config.name (without prefix) is sent in CONF_DATA
    // and displayed in the app UI.
    static char bleAdvName[RADIOKIT_MAX_NAME + 4]; // 3 for "RK_" + null
    snprintf(bleAdvName, sizeof(bleAdvName), "RK_%s", baseName ? baseName : "RadioKit");
    _transport = &RadioKitBLEInstance;
    _transport->begin(bleAdvName, RadioKitClass::_onPacket);
}

void RadioKitClass::startSerial(Stream& stream) {
    _transport = &RadioKitSerialInstance;
    RadioKitSerialInstance.begin(stream, RadioKitClass::_onPacket);
}

void RadioKitClass::update() {
    if (_transport) _transport->update();

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

    if (_pendingUpdatesMask != 0 && _transport && _transport->isConnected()) {
        if ((_pendingUpdatesMask & (1UL << _varUpdateId)) == 0) {
            // Current ID was ACKed or dropped. Pick next.
            for (uint8_t i = 0; i < 32; i++) {
                if (_pendingUpdatesMask & (1UL << i)) {
                    _varUpdateId = i;
                    _varUpdateSeq++;
                    _varUpdateRetries = 0;
                    _varUpdateSentAt = 0;
                    RK_DEBUG_PRINT("[DBG] pending: picked id=%d seq=%d\n", i, _varUpdateSeq);
                    break;
                }
            }
        }
        
        uint32_t now = millis();
        // Force send on first run (_varUpdateSentAt == 0) or if timeout exceeded
        if (_varUpdateSentAt == 0 || now - _varUpdateSentAt >= RK_VAR_UPDATE_TIMEOUT_MS) {
            if (_varUpdateRetries >= RK_VAR_UPDATE_MAX_RETRIES) {
                RK_DEBUG_PRINT("[DBG] pending: RETRIES EXHAUSTED for id=%d, dropping\n", _varUpdateId);
                // Drop and move on.
                _pendingUpdatesMask &= ~(1UL << _varUpdateId);
                _varUpdateRetries = 0;
                // Fallback to full sync if ACK fails
                _handleGetVars();
            } else {
                RadioKit_Widget* w = _widgets[_varUpdateId];
                uint8_t inSz = w->inputSize();
                uint8_t outSz = w->outputSize();
                uint8_t dataSz = inSz > 0 ? inSz : outSz;
                uint8_t payload[2 + dataSz];
                payload[0] = _varUpdateId;
                payload[1] = _varUpdateSeq;
                uint8_t cmd = RK_CMD_VAR_UPDATE;
                if (inSz > 0) {
                    w->serializeInput(&payload[2]);
                    cmd = RK_CMD_SET_INPUT;
                } else {
                    w->serializeOutput(&payload[2]);
                }
                RK_DEBUG_PRINT("[DBG] pending: SENDING %s id=%d seq=%d val=%d retry=%d\n",
                    rk_cmdName(cmd), _varUpdateId, _varUpdateSeq, payload[2], _varUpdateRetries);
                uint16_t pkt = rk_buildPacket(_txBuf, cmd, payload, 2 + dataSz);
                _sendPacket(pkt);
                _varUpdateSentAt = now;
                _varUpdateRetries++;
            }
        }
    }

    // ── Process META_UPDATE (Reliable) ───────────────────────────────────
    if (_pendingMetaMask != 0 && _transport && _transport->isConnected()) {
        if ((_pendingMetaMask & (1UL << _metaUpdateId)) == 0) {
            for (uint8_t i = 0; i < 32; i++) {
                if (_pendingMetaMask & (1UL << i)) {
                    _metaUpdateId = i;
                    _metaUpdateSeq++;
                    _metaUpdateRetries = 0;
                    _metaUpdateSentAt = 0;
                    break;
                }
            }
        }
        
        uint32_t now = millis();
        if (_metaUpdateSentAt == 0 || now - _metaUpdateSentAt >= RK_VAR_UPDATE_TIMEOUT_MS) {
            if (_metaUpdateRetries >= RK_VAR_UPDATE_MAX_RETRIES) {
                _pendingMetaMask &= ~(1UL << _metaUpdateId);
                _metaUpdateRetries = 0;
            } else {
                RadioKit_Widget* w = _widgets[_metaUpdateId];
                uint8_t payload[2 + RK_STR_BUF_SIZE];
                payload[0] = _metaUpdateId;
                payload[1] = _metaUpdateSeq;
                uint16_t strLen = w->serializeStrings(&payload[2]);
                uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_META_UPDATE, payload, 2 + strLen);
                _sendPacket(pkt);
                _metaUpdateSentAt = now;
                _metaUpdateRetries++;
            }
        }
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
    Serial.printf("RK: Dispatching CMD %s (0x%02X), len %d\n", rk_cmdName(cmd), cmd, payloadLen);
    switch (cmd) {
        case RK_CMD_GET_CONF:  s_instance->_handleGetConf();                      break;
        case RK_CMD_GET_VARS:  s_instance->_handleGetVars();                      break;
        case RK_CMD_GET_META:  s_instance->_handleGetMeta();                      break;
        case RK_CMD_SET_INPUT: s_instance->_handleSetInput(payload, payloadLen);  break;
        case RK_CMD_GET_TELEMETRY: s_instance->_handleGetTelemetry();             break;
        case RK_CMD_PING:      s_instance->_handlePing();                         break;
        case RK_CMD_ACK:       s_instance->_handleAck(payload, payloadLen);       break;
        case RK_CMD_VAR_UPDATE:s_instance->_handleVarUpdate(payload, payloadLen); break;
        case RK_CMD_META_UPDATE:s_instance->_handleMetaUpdate(payload, payloadLen);break;
        default: 
            Serial.printf("RK: Unknown CMD %s (0x%02X)\n", rk_cmdName(cmd), cmd);
            break;
    }
}

int8_t RadioKitClass::getRssi() {
    if (_transport) return _transport->getRssi();
    return 0;
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
    Serial.printf("RK: _handleGetConf: payloadLen = %d\n", payloadLen);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, payloadPtr, payloadLen);
    Serial.printf("RK: _handleGetConf: totalLen = %d, sending...\n", totalLen);
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
    if (len < 1) return;
    uint8_t seq = payload[0];
    RK_DEBUG_PRINT("[DBG] _handleAck: seq=%d pendingMask=0x%08lX varSeq=%d\n",
        seq, (unsigned long)_pendingUpdatesMask, _varUpdateSeq);
    if (_pendingUpdatesMask != 0 && seq == _varUpdateSeq) {
        RK_DEBUG_PRINT("[DBG]   MATCH! Clearing pending for id=%d\n", _varUpdateId);
        _pendingUpdatesMask &= ~(1UL << _varUpdateId);
        _varUpdateRetries = 0;
    } else if (_pendingUpdatesMask != 0) {
        RK_DEBUG_PRINT("[DBG]   seq mismatch: got=%d expected=%d\n", seq, _varUpdateSeq);
    }
    if (_pendingMetaMask != 0 && seq == _metaUpdateSeq) {
        _pendingMetaMask &= ~(1UL << _metaUpdateId);
        _metaUpdateRetries = 0;
    }
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

    const char* name    = config.name        ? config.name        : "";
    const char* desc    = config.description ? config.description : "";
    const char* pwd     = config.password    ? config.password    : "";
    const char* themeStr = config.theme      ? config.theme       : RK_DEFAULT;
    uint8_t nameLen  = (uint8_t)strnlen(name,     RADIOKIT_MAX_NAME);
    uint8_t descLen  = (uint8_t)strnlen(desc,     RADIOKIT_MAX_DESC);
    uint8_t pwdLen   = (uint8_t)strnlen(pwd,      RADIOKIT_MAX_PWD);
    uint8_t themeLen = (uint8_t)strnlen(themeStr, 64);

    if (out + 8 + nameLen + descLen + pwdLen + themeLen > bufSize) return 0;

    buf[out++] = RK_PROTOCOL_VERSION;
    buf[out++] = config.orientation;
    buf[out++] = _widgetCount;
    buf[out++] = nameLen;
    memcpy(&buf[out], name, nameLen); out += nameLen;
    buf[out++] = descLen;
    memcpy(&buf[out], desc, descLen); out += descLen;
    buf[out++] = pwdLen;
    memcpy(&buf[out], pwd, pwdLen);   out += pwdLen;
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

void RadioKitClass::_sendPacket(uint16_t len) {
    if (!_transport) return;
    uint8_t cmd = _txBuf[3];
    Serial.printf("RK: Sending CMD %s (0x%02X), len %d\n", rk_cmdName(cmd), cmd, len);
    _transport->sendPacket(_txBuf, len);
}
