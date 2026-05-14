#include "Knob.h"

RK_Knob::RK_Knob(RK_KnobProps p) : props(p) {
    typeId = RK_TYPE_KNOB;
    uint8_t v = RK_VARIANT(p.centering, 0); // Knob docs don't have detents
    _init(p.label, p.x, p.y, p.height, p.width, 0, v,
          p.icon, nullptr, nullptr, p.rotation);
}

void RK_Knob::deserializeInput(const uint8_t* buf) {
    int8_t v = (int8_t)buf[0];
    props.value = v > 100 ? 100 : (v < -100 ? -100 : v);
}

void RK_Knob::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)(int8_t)props.value; // two's complement, safe cast
}

uint16_t RK_Knob::serializeStrings(uint8_t* buf) const {
    uint16_t len = RadioKit_Widget::serializeStrings(buf);
    
    // Set the EXTRA bit in the mask (at buf[0])
    buf[0] |= RK_STR_EXTRA;
    
    // Data format: [LEN(1)] [startAngle_LO(1)] [startAngle_HI(1)] [endAngle_LO(1)] [endAngle_HI(1)]
    buf[len++] = 4; // 4 bytes of extra data
    buf[len++] = (uint8_t)(props.startAngle & 0xFF);
    buf[len++] = (uint8_t)((props.startAngle >> 8) & 0xFF);
    buf[len++] = (uint8_t)(props.endAngle & 0xFF);
    buf[len++] = (uint8_t)((props.endAngle >> 8) & 0xFF);
    
    return len;
}
