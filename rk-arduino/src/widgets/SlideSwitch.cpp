#include "SlideSwitch.h"
#include <string.h>

RK_SlideSwitch::RK_SlideSwitch(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.variant = 0;
    typeId = RK_TYPE_SLIDE_SWITCH;
    _init(rk.label, x, y, height, width, 0, rk.variant,
          rk.icon, rk.onText, rk.offText, rotation);
    _shadow = rk;
}

void RK_SlideSwitch::serializeInput(uint8_t* buf) const {
    buf[0] = rk.state ? 1 : 0;
}

void RK_SlideSwitch::deserializeInput(const uint8_t* buf) {
    rk.state = (buf[0] != 0);
    _shadow.state = rk.state;
}

uint16_t RK_SlideSwitch::serializeStrings(uint8_t* buf) const {
    const char* lbl = (rk.label && rk.label[0] != '\0') ? rk.label : _label;
    const char* icn = (rk.icon && rk.icon[0] != '\0') ? rk.icon : _icon;
    const char* ont = (rk.onText && rk.onText[0] != '\0') ? rk.onText : _onText;
    const char* oft = (rk.offText && rk.offText[0] != '\0') ? rk.offText : _offText;

    uint8_t mask = 0;
    if (_labelHidden) mask |= RK_STR_LABEL_HIDDEN;
    if (_hidden)      mask |= RK_STR_WIDGET_HIDDEN;
    if (icn && icn[0] != '\0') mask |= RK_STR_ICON;
    if (ont && ont[0] != '\0') mask |= RK_STR_ONTEXT;
    if (oft && oft[0] != '\0') mask |= RK_STR_OFFTEXT;

    uint16_t out = 0;
    buf[out++] = mask;

    auto _writeStr = [&](const char* s, size_t maxLen) {
        uint8_t len = s ? (uint8_t)strnlen(s, maxLen < 255 ? maxLen : 255) : 0;
        buf[out++] = len;
        if (len > 0) memcpy(&buf[out], s, len);
        out += len;
    };

    _writeStr(lbl, RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_ICON)    _writeStr(icn, RADIOKIT_MAX_ICON);
    if (mask & RK_STR_ONTEXT)  _writeStr(ont, RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_OFFTEXT) _writeStr(oft, RADIOKIT_MAX_LABEL);

    return out;
}

// ── RockerSwitch ────────────────────────────────────────────────────────────
RK_RockerSwitch::RK_RockerSwitch(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation)
    : RK_SlideSwitch(x, y, height, width, rotation)
{
    rk.variant = 1;
}
