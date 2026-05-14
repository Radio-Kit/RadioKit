#include "Joystick.h"

RK_Joystick::RK_Joystick(RK_JoystickProps p) : props(p) {
    typeId   = RK_TYPE_JOYSTICK;
    _init(p.label, p.x, p.y, p.height, p.width, 0, p.centering,
          p.icon, nullptr, nullptr, p.rotation);
    _enabled = p.enabled;
}

void RK_Joystick::deserializeInput(const uint8_t* buf) {
    props.xvalue = (int8_t)buf[0];
    props.yvalue = (int8_t)buf[1];
}

void RK_Joystick::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)props.xvalue;
    buf[1] = (uint8_t)props.yvalue;
}
