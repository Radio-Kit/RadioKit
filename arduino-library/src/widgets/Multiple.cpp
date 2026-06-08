#include "Multiple.h"
#include "../RadioKitLib.h"
#include <string.h>

void RadioKit_Multiple::_initFromProps(const RK_MultipleProps& p, uint8_t tid) {
    props      = p;
    typeId     = tid;
    _poolCount = 0;
    memset(_pool, 0, sizeof(_pool));

    for (const RK_Item& item : p.items) {
        if (_poolCount >= RADIOKIT_MAX_ITEMS) break;
        uint8_t slot = _poolCount;
        if (item.pos < RADIOKIT_MAX_ITEMS) slot = item.pos;
        _pool[slot] = item;
        _poolCount++;
    }

    _init(p.label, p.x, p.y, p.height, p.width, 0, p.variant,
          nullptr, nullptr, nullptr, p.rotation);
}

void RadioKit_Multiple::deserializeInput(const uint8_t* buf) {
    props.value = buf[0];
}

void RadioKit_Multiple::serializeInput(uint8_t* buf) const {
    buf[0] = props.value;
}

void RadioKit_Multiple::clear() {
    memset(_pool, 0, sizeof(_pool));
    _poolCount  = 0;
    props.value = 0;
}

void RadioKit_Multiple::add(const RK_Item& item) {
    if (_poolCount >= RADIOKIT_MAX_ITEMS) return;
    uint8_t slot = _poolCount;
    if (item.pos < RADIOKIT_MAX_ITEMS) slot = item.pos;
    _pool[slot] = item;
    _poolCount++;
}

void RadioKit_Multiple::remove(uint8_t index) {
    if (index >= RADIOKIT_MAX_ITEMS) return;
    memset(&_pool[index], 0, sizeof(RK_Item));
    if (_poolCount > 0) _poolCount--;
}


RK_MultipleButton::RK_MultipleButton(RK_MultipleProps p) {
    p.variant = 0; // Index-based (Radio)
    _initFromProps(p, RK_TYPE_MULTIPLE);
}

RK_MultipleSelect::RK_MultipleSelect(RK_MultipleProps p) {
    p.variant = 1; // Bitmask-based (Checkboxes)
    _initFromProps(p, RK_TYPE_MULTIPLE);
}

uint16_t RadioKit_Multiple::serializeStrings(uint8_t* buf) const {
    uint8_t mask = 0;
    if (_label[0]  != '\0') mask |= RK_STR_LABEL;
    if (_icon[0]   != '\0') mask |= RK_STR_ICON;
    if (_onText[0] != '\0') mask |= RK_STR_ONTEXT;
    if (_offText[0]!= '\0') mask |= RK_STR_OFFTEXT;

    // Build pipe-delimited content string: "label:icon|label:icon|..."
    char itemsStr[RADIOKIT_MAX_ITEMS * (RADIOKIT_MAX_LABEL + RADIOKIT_MAX_ICON + 2) + 1];
    itemsStr[0] = '\0';
    size_t remaining = sizeof(itemsStr) - 1;
    bool first = true;
    for (uint8_t i = 0; i < _poolCount; i++) {
        const RK_Item& item = _pool[i];
        const char* lbl  = item.label ? item.label : "";
        const char* icon = item.icon  ? item.icon  : "";
        if (lbl[0] == '\0' && icon[0] == '\0') continue;

        if (!first) {
            strncat(itemsStr, "|", remaining);
            remaining = remaining > 1 ? remaining - 1 : 0;
        }
        first = false;

        strncat(itemsStr, lbl, remaining);
        size_t lblLen = strnlen(lbl, remaining);
        remaining = remaining > lblLen ? remaining - lblLen : 0;

        if (icon[0] != '\0') {
            strncat(itemsStr, ":", remaining);
            remaining = remaining > 1 ? remaining - 1 : 0;
            strncat(itemsStr, icon, remaining);
            size_t iconLen = strnlen(icon, remaining);
            remaining = remaining > iconLen ? remaining - iconLen : 0;
        }
    }
    if (itemsStr[0] != '\0') mask |= RK_STR_CONTENT;

    uint16_t out = 0;
    buf[out++] = mask;

    // len field is uint8_t — content capped at 255 bytes safely by buffer sizing above
    auto _writeStr = [&](const char* s, size_t maxLen) {
        uint8_t len = (uint8_t)strnlen(s, maxLen < 255 ? maxLen : 255);
        buf[out++] = len;
        memcpy(&buf[out], s, len);
        out += len;
    };

    if (mask & RK_STR_LABEL)   _writeStr(_label,    RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_ICON)    _writeStr(_icon,     RADIOKIT_MAX_ICON);
    if (mask & RK_STR_ONTEXT)  _writeStr(_onText,   RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_OFFTEXT) _writeStr(_offText,  RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_CONTENT) _writeStr(itemsStr,  sizeof(itemsStr) - 1);

    return out;
}
