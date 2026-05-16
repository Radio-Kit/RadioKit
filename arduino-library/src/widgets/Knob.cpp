#include "Knob.h"

RK_Knob::RK_Knob(RK_KnobProps p) : props(p) {
    typeId = RK_TYPE_KNOB;
    uint8_t v = RK_VARIANT(p.centering, 0) | (p.variant << 4);
    _init(p.label, p.x, p.y, p.height, p.width, 0, v,
          p.icon, nullptr, nullptr, p.rotation);
}

void RK_Knob::deserializeInput(const uint8_t* buf) {
    int8_t v = (int8_t)buf[0];
    props.value = v > 100 ? 100 : (v < -100 ? -100 : v);
}

void RK_Knob::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)(int8_t)props.value;
}

uint16_t RK_Knob::serializeStrings(uint8_t* buf) const {
    uint16_t len = RadioKit_Widget::serializeStrings(buf);

    buf[0] |= RK_STR_EXTRA;

    uint16_t extraStart = len++;
    uint16_t extraLen = 0;

    if (props.centerIcon && props.centerIcon[0] != '\0') {
        uint8_t iconLen = strlen(props.centerIcon);
        buf[len++] = iconLen;
        memcpy(buf + len, props.centerIcon, iconLen);
        len += iconLen;
        extraLen = 1 + iconLen;
    } else {
        buf[len++] = 0;
        extraLen = 1;
    }

    buf[extraStart] = extraLen + 4;
    buf[len++] = (uint8_t)(props.startAngle & 0xFF);
    buf[len++] = (uint8_t)((props.startAngle >> 8) & 0xFF);
    buf[len++] = (uint8_t)(props.endAngle & 0xFF);
    buf[len++] = (uint8_t)((props.endAngle >> 8) & 0xFF);

    return len;
}
