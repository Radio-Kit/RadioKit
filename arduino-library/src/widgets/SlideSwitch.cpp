#include "SlideSwitch.h"
#include <string.h>

RK_SlideSwitch::RK_SlideSwitch(RK_SlideSwitchProps p) {
    props  = p;
    typeId = RK_TYPE_SLIDE_SWITCH;
    _init(p.label, p.x, p.y, p.height, p.width, 0, p.variant,
          p.icon, p.onText, p.offText, p.rotation);
}

void RK_SlideSwitch::serializeInput(uint8_t* buf) const {
    buf[0] = props.state ? 1 : 0;
}

void RK_SlideSwitch::deserializeInput(const uint8_t* buf) {
    props.state = (buf[0] != 0);
}

void RK_SlideSwitch::setIcon(const char* val) {
    props.icon = val;
    if (val && val[0] != '\0') {
        strncpy(_icon, val, RADIOKIT_MAX_ICON);
        _icon[RADIOKIT_MAX_ICON] = '\0';
    } else {
        _icon[0] = '\0';
    }
}
