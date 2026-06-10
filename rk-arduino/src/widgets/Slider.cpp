#include "Slider.h"

RK_Slider::RK_Slider(RK_SliderProps p) : props(p) {
    typeId = RK_TYPE_SLIDER;
    
    // If variant is zero, calculate it from centering/detents.
    // Otherwise, use the provided variant (e.g. for RK_GasPedal).
    uint8_t v = p.variant;
    if (v == 0) {
        v = RK_VARIANT(p.centering, p.detents);
    }
    
    _init(p.label, p.x, p.y, p.height, p.width, 0, v,
          nullptr, nullptr, nullptr, p.rotation);
}

void RK_Slider::deserializeInput(const uint8_t* buf) {
    int8_t v = (int8_t)buf[0];
    props.value = v > 100 ? 100 : (v < -100 ? -100 : v);
}

void RK_Slider::serializeInput(uint8_t* buf) const {
    buf[0] = (uint8_t)(int8_t)props.value; // two's complement, safe cast
}
