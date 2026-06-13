/**
 * Knob.h
 * RK_Knob — rotary analog control (-100 to +100).
 *
 * variant byte: RK_VARIANT(centering, detents)
 *   bits[1:0] = centering  (RK_CENTER_NONE / LEFT / CENTER / RIGHT)
 *   bits[7:2] = detents    (0 = continuous, 1-63 = snap positions)
 */

#ifndef RADIOKIT_WIDGET_KNOB_H
#define RADIOKIT_WIDGET_KNOB_H

#include "Widget.h"

struct RK_KnobFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 20;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon = nullptr;
    const char* label = nullptr;
    bool        active = false;
    int8_t      value = 0;
    int16_t     startAngle = -135;
    int16_t     endAngle = 135;
    uint8_t     centering = RK_SPRING_NONE;
    uint8_t     detents = 0;         ///< Snap positions (0=continuous, 1-63)
    uint8_t     variant = 0;         ///< 0=standard, 1=steeringWheel
    const char* centerIcon = nullptr;
};

class RK_Knob : public RadioKit_Widget {
public:
    RK_Knob(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)             const override {}
    void deserializeInput(const uint8_t* buf)        override;
    uint16_t serializeStrings(uint8_t* buf)    const override;

    RK_KnobFields rk;

protected:
    float defaultAspect() const override { return 1.0f; }
    RK_KnobFields _shadow;
};

#endif // RADIOKIT_WIDGET_KNOB_H
