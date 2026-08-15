#include "Slider.h"

RK_Slider::RK_Slider(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    typeId = RK_TYPE_SLIDER;
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.centering = RK_SPRING_NONE;
    rk.detents = 0;
    rk.value = 0;

    uint8_t v = RK_VARIANT(rk.centering, rk.detents);
    _init(rk.label, x, y, height, width, 0, v,
          nullptr, nullptr, nullptr, rotation);
    _shadow = rk;
}

void RK_Slider::deserializeInput(const uint8_t* buf) {
    int8_t v = (int8_t)buf[0];
    rk.value = v > 100 ? 100 : (v < -100 ? -100 : v);
    _shadow.value = rk.value;
}

void RK_Slider::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)(int8_t)rk.value; // two's complement, safe cast
}

uint8_t RK_Slider::variant() const {
    uint8_t alt = (_variant & RK_SHAPE_ALT);
    return alt | RK_VARIANT(rk.centering, rk.detents);
}

uint16_t RK_Slider::serializeStrings(uint8_t* buf) const {
    const char* lbl = (rk.label && rk.label[0] != '\0') ? rk.label : _label;
    uint8_t mask = 0;
    if (_labelHidden) mask |= RK_STR_LABEL_HIDDEN;
    if (_hidden)      mask |= RK_STR_WIDGET_HIDDEN;

    uint16_t out = 0;
    buf[out++] = mask;

    auto _writeStr = [&](const char* s, size_t maxLen) {
        uint8_t len = s ? (uint8_t)strnlen(s, maxLen < 255 ? maxLen : 255) : 0;
        buf[out++] = len;
        if (len > 0) memcpy(&buf[out], s, len);
        out += len;
    };

    _writeStr(lbl, RADIOKIT_MAX_LABEL);
    return out;
}

// ── GasPedal ────────────────────────────────────────────────────────────────
RK_GasPedal::RK_GasPedal(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation)
    : RK_Slider(x, y, height, width, rotation)
{
    rk.centering = RK_SPRING_CENTER;
    rk.detents = 0;
    rk.value = -100;
    _variant = RK_SHAPE_ALT | RK_VARIANT(rk.centering, rk.detents);
    _shadow = rk;
}
