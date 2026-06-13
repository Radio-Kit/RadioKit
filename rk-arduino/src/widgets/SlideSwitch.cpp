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

// ── RockerSwitch ────────────────────────────────────────────────────────────
RK_RockerSwitch::RK_RockerSwitch(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation)
    : RK_SlideSwitch(x, y, height, width, rotation)
{
    rk.variant = 1;
}
