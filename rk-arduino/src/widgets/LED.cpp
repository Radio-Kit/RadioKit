#include "LED.h"
#include "../RadioKitLib.h"
#include <string.h>

RK_LED::RK_LED(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    typeId = RK_TYPE_LED;
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    rk.shape = RK_LED_SHAPE_CIRCLE;
    rk.ledState = RK_LED_STATE_ON;
    rk.timing = 500;
    rk.color = RK_OFF;
    rk.state = false;
    _init(rk.label, x, y, height, width, 0, rk.shape,
          nullptr, nullptr, nullptr, rotation);
    _shadow = rk;
}

void RK_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = rk.state ? 1 : 0;
    buf[1] = (rk.color >> 16) & 0xFF;
    buf[2] = (rk.color >> 8)  & 0xFF;
    buf[3] =  rk.color        & 0xFF;
    buf[4] = 255;
}

void RK_LED::serializeInput(uint8_t* buf) const {
}

uint16_t RK_LED::serializeStrings(uint8_t* buf) const {
    return RadioKit_Widget::serializeStrings(buf);
}
