#include "Multiple.h"
#include "../RadioKitLib.h"
#include <string.h>

void RadioKit_Multiple::_initFromFields(const RK_MultipleFields& f, uint8_t tid) {
    rk       = f;
    typeId   = tid;

    _init(rk.label, rk.x, rk.y, rk.height, rk.width, 0, rk.variant,
          nullptr, nullptr, nullptr, rk.rotation);
    _shadow = rk;
}

void RadioKit_Multiple::deserializeInput(const uint8_t* buf) {
    rk.value = buf[0];
    _shadow.value = rk.value;
}

void RadioKit_Multiple::serializeInput(uint8_t* buf) const {
    buf[0] = rk.value;
}


RK_MultipleButton::RK_MultipleButton(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.variant = 0; // Index-based (Radio)
    rk.value = 0;
    rk.itemCount = 0;
    memset(rk.items, 0, sizeof(rk.items));
    _initFromFields(rk, RK_TYPE_MULTIPLE);
}

RK_MultipleSelect::RK_MultipleSelect(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.variant = 1; // Bitmask-based (Checkboxes)
    rk.value = 0;
    rk.itemCount = 0;
    memset(rk.items, 0, sizeof(rk.items));
    _initFromFields(rk, RK_TYPE_MULTIPLE);
}

uint16_t RadioKit_Multiple::serializeStrings(uint8_t* buf) const {
    uint8_t mask = 0;
    // Bit 0 reserved — label is always present.
    if (_labelHidden)           mask |= RK_STR_LABEL_HIDDEN;
    if (_hidden)                mask |= RK_STR_WIDGET_HIDDEN;
    if (_icon[0]   != '\0') mask |= RK_STR_ICON;
    if (_onText[0] != '\0') mask |= RK_STR_ONTEXT;
    if (_offText[0]!= '\0') mask |= RK_STR_OFFTEXT;

    // Build pipe-delimited content string: "label:icon|label:icon|..."
    char itemsStr[RADIOKIT_MAX_ITEMS * (RADIOKIT_MAX_LABEL + RADIOKIT_MAX_ICON + 2) + 1];
    itemsStr[0] = '\0';
    size_t remaining = sizeof(itemsStr) - 1;
    bool first = true;
    for (uint8_t i = 0; i < rk.itemCount; i++) {
        const RK_Item& item = rk.items[i];
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

    // Label is always serialized (no mask bit).
    _writeStr(_label, RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_ICON)    _writeStr(_icon,     RADIOKIT_MAX_ICON);
    if (mask & RK_STR_ONTEXT)  _writeStr(_onText,   RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_OFFTEXT) _writeStr(_offText,  RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_CONTENT) _writeStr(itemsStr,  sizeof(itemsStr) - 1);

    return out;
}
