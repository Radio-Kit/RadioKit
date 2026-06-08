#include "Button.h"
#include "../RadioKitLib.h"
#include <string.h>

void RadioKit_Button::_initFromProps(const RK_ButtonProps& p, uint8_t tid) {
    props  = p;
    typeId = tid;
    _init(p.label, p.x, p.y, p.height, p.width, 0, 0,
          p.icon, p.onText, p.offText, p.rotation);
}

void RadioKit_Button::set(bool val) {
    props.state = val;
    RadioKit.pushUpdate(widgetId);
}

void RadioKit_Button::serializeInput(uint8_t* buf) const {
    buf[0] = props.state ? 1 : 0;
}

void RadioKit_Button::deserializeInput(const uint8_t* buf) {
    bool newState = (buf[0] != 0);
    if (typeId == RK_TYPE_PUSH_BUTTON) {
        if (newState && !props.state) _pendingPress = true;
        props.state = newState;
    } else {
        props.state = newState;
    }
}


RK_PushButton::RK_PushButton(RK_ButtonProps p) {
    _initFromProps(p, RK_TYPE_PUSH_BUTTON);
}

bool RK_PushButton::isPressed() {
    return props.state;
}

bool RK_PushButton::clicked() {
    if (_pendingPress) { _pendingPress = false; return true; }
    return false;
}

RK_ToggleButton::RK_ToggleButton(RK_ButtonProps p) {
    _initFromProps(p, RK_TYPE_TOGGLE_BUTTON);
    props.state = p.state;
}
