#include "Button.h"
#include "../RadioKitLib.h"
#include <string.h>

void RadioKit_Button::_initFromProps(const RK_ButtonFields& p, uint8_t tid) {
    rk     = p;
    typeId = tid;
    _init(p.label, p.x, p.y, p.height, p.width, 0, 0,
          p.icon, p.onText, p.offText, p.rotation);
    _shadow = rk;
}

void RadioKit_Button::serializeInput(uint8_t* buf) const {
    buf[0] = rk.state ? 1 : 0;
}

void RadioKit_Button::deserializeInput(const uint8_t* buf) {
    bool newState = (buf[0] != 0);
    if (typeId == RK_TYPE_PUSH_BUTTON) {
        if (newState && !rk.state) _pendingPress = true;
        rk.state = newState;
    } else {
        rk.state = newState;
    }
    _shadow.state = rk.state;  // sync shadow immediately on incoming update
}


RK_PushButton::RK_PushButton(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    _initFromProps(rk, RK_TYPE_PUSH_BUTTON);
}

RK_ToggleButton::RK_ToggleButton(uint8_t x, uint8_t y, uint8_t height, uint8_t width, int16_t rotation) {
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.rotation = rotation;
    _initFromProps(rk, RK_TYPE_TOGGLE_BUTTON);
}
