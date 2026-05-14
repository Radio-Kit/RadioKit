#include "LED.h"
#include "../RadioKit.h"
#include <string.h>

RK_LED::RK_LED(RK_LedProps p) : props(p) {
    typeId = RK_TYPE_LED;
    _init(p.label, p.x, p.y, p.height, p.width, 0, 0,
          nullptr, nullptr, nullptr, p.rotation);
}

void RK_LED::on() {
    props.state = true;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::off() {
    props.state = false;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = props.state ? 1 : 0;
    buf[1] = (props.color >> 16) & 0xFF; // R
    buf[2] = (props.color >> 8)  & 0xFF; // G
    buf[3] =  props.color        & 0xFF; // B
    buf[4] = 255; // Opacity (v3 protocol uses 5 bytes for LED, but docs only show color)
}

void RK_LED::serializeInput(uint8_t* buf) const {
    // LEDs have no input state
}

void RK_LED::set(bool val) {
    props.state = val;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::setColor(uint32_t val) {
    props.color = val;
    RadioKit.pushUpdate(widgetId);
}
