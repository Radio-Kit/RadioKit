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
