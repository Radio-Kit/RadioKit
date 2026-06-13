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

// ── GasPedal ────────────────────────────────────────────────────────────────
RK_GasPedal::RK_GasPedal(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation)
    : RK_Slider(x, y, height, width, rotation)
{
    rk.centering = RK_SPRING_CENTER;
    rk.detents = 0;
    _variant = RK_SHAPE_ALT | RK_VARIANT(rk.centering, rk.detents);
    _shadow = rk;
}
