#include "Telemetry.h"
#include "../RadioKitLib.h"
#include <string.h>

RK_Telemetry::RK_Telemetry(const char* label)
{
    typeId = RK_TYPE_TELEMETRY;
    memset(_text, 0, sizeof(_text));
    memset(_unit, 0, sizeof(_unit));

    rk.label = label;
    rk.icon = nullptr;
    rk.unit = nullptr;
    rk.content = _text;

    // Telemetry widgets have no canvas position — pass 0 for all spatial params.
    _init(label,
          0,     // x
          0,     // y
          0,     // height
          0,     // width
          0,     // style
          0,     // variant
          nullptr, // icon (set via rk.icon after construction)
          nullptr, // onText (not used)
          nullptr, // offText (not used)
          0);    // rotation
    _shadow = rk;
}

void RK_Telemetry::serializeOutput(uint8_t* buf) const {
    const char* src = rk.content ? rk.content : "";
    uint8_t len = (uint8_t)strnlen(src, RADIOKIT_TEXT_LEN);
    buf[0] = len;
    if (len > 0) {
        memcpy(buf + 1, src, len);
    }
}

uint8_t RK_Telemetry::outputSize() const {
    return RADIOKIT_TEXT_LEN + 1; // length byte + text
}

uint16_t RK_Telemetry::serializeStrings(uint8_t* buf) const {
    const char* lbl = (rk.label && rk.label[0] != '\0') ? rk.label : _label;
    const char* icn = (rk.icon && rk.icon[0] != '\0') ? rk.icon : _icon;

    uint8_t mask = 0;
    if (_labelHidden) mask |= RK_STR_LABEL_HIDDEN;
    if (_hidden)      mask |= RK_STR_WIDGET_HIDDEN;
    if (icn && icn[0] != '\0') mask |= RK_STR_ICON;

    uint16_t out = 0;
    buf[out++] = mask;

    auto _writeStr = [&](const char* s, size_t maxLen) {
        uint8_t len = s ? (uint8_t)strnlen(s, maxLen < 255 ? maxLen : 255) : 0;
        buf[out++] = len;
        if (len > 0) memcpy(&buf[out], s, len);
        out += len;
    };

    _writeStr(lbl, RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_ICON) _writeStr(icn, RADIOKIT_MAX_ICON);

    return out;
}
