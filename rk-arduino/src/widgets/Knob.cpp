#include "Knob.h"

RK_Knob::RK_Knob(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    typeId = RK_TYPE_KNOB;
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.value = 0;
    rk.centering = RK_SPRING_NONE;
    rk.detents = 0;
    rk.variant = 0;
    rk.startAngle = -135;
    rk.endAngle = 135;

    // Pack centering+detents + variant bit into _variant byte
    uint8_t v = RK_VARIANT(rk.centering, rk.detents) | (rk.variant << 4);
    _init(rk.label, x, y, height, width, 0, v,
          rk.icon, nullptr, nullptr, rotation);
    _shadow = rk;
}

void RK_Knob::deserializeInput(const uint8_t* buf) {
    int8_t v = (int8_t)buf[0];
    rk.value = v > 100 ? 100 : (v < -100 ? -100 : v);
    _shadow.value = rk.value;
}

void RK_Knob::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)(int8_t)rk.value;
}

uint16_t RK_Knob::serializeStrings(uint8_t* buf) const {
    uint16_t len = RadioKit_Widget::serializeStrings(buf);

    buf[0] |= RK_STR_EXTRA;

    uint16_t extraStart = len++;
    uint16_t extraLen = 0;

    if (rk.centerIcon && rk.centerIcon[0] != '\0') {
        uint8_t iconLen = strlen(rk.centerIcon);
        buf[len++] = iconLen;
        memcpy(buf + len, rk.centerIcon, iconLen);
        len += iconLen;
        extraLen = 1 + iconLen;
    } else {
        buf[len++] = 0;
        extraLen = 1;
    }

    buf[extraStart] = extraLen + 4;
    buf[len++] = (uint8_t)(rk.startAngle & 0xFF);
    buf[len++] = (uint8_t)((rk.startAngle >> 8) & 0xFF);
    buf[len++] = (uint8_t)(rk.endAngle & 0xFF);
    buf[len++] = (uint8_t)((rk.endAngle >> 8) & 0xFF);

    return len;
}
