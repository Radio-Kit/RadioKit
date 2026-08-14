#include "Joystick.h"

RK_Joystick::RK_Joystick(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    typeId = RK_TYPE_JOYSTICK;
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.centering = RK_SPRING_CENTER;
    rk.enabled = true;
    _init(rk.label, x, y, height, width, 0, rk.centering,
          rk.icon, nullptr, nullptr, rotation);
    _enabled = rk.enabled;
    _shadow = rk;
}

void RK_Joystick::deserializeInput(const uint8_t* buf) {
    rk.xvalue = (int8_t)buf[0];
    rk.yvalue = (int8_t)buf[1];
    _shadow.xvalue = rk.xvalue;
    _shadow.yvalue = rk.yvalue;
}

void RK_Joystick::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)rk.xvalue;
    buf[1] = (uint8_t)rk.yvalue;
}

uint16_t RK_Joystick::serializeStrings(uint8_t* buf) const {
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
