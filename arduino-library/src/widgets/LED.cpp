#include "LED.h"
#include "../RadioKit.h"
#include <string.h>

RK_LED::RK_LED(RK_LedProps p) : props(p) {
    typeId = RK_TYPE_LED;
    _init(p.label, p.x, p.y, p.height, p.width, 0, p.shape,
          nullptr, nullptr, nullptr, p.rotation);
}

void RK_LED::on() {
    props.state = true;
    props.ledState = RK_LED_STATE_ON;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::off() {
    props.state = false;
    props.ledState = RK_LED_STATE_OFF;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::serializeOutput(uint8_t* buf) const {
    buf[0] = props.state ? 1 : 0;
    buf[1] = (props.color >> 16) & 0xFF;
    buf[2] = (props.color >> 8)  & 0xFF;
    buf[3] =  props.color        & 0xFF;
    buf[4] = 255;
}

void RK_LED::serializeInput(uint8_t* buf) const {
}

uint16_t RK_LED::serializeStrings(uint8_t* buf) const {
    return RadioKit_Widget::serializeStrings(buf);
}

void RK_LED::set(bool val) {
    props.state = val;
    props.ledState = val ? RK_LED_STATE_ON : RK_LED_STATE_OFF;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::setColor(uint32_t val) {
    props.color = val;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::setShape(uint8_t val) {
    props.shape = val;
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::setLedState(uint8_t val) {
    props.ledState = val;
    props.state = (val != RK_LED_STATE_OFF);
    RadioKit.pushUpdate(widgetId);
}

void RK_LED::setTiming(uint16_t val) {
    props.timing = val;
    RadioKit.pushUpdate(widgetId);
}
