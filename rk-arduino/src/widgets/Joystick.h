/**
 * Joystick.h
 * RK_Joystick — 2-axis analog controller (-100 to +100).
 */

#ifndef RADIOKIT_WIDGET_JOYSTICK_H
#define RADIOKIT_WIDGET_JOYSTICK_H

#include "Widget.h"

struct RK_JoystickFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon = nullptr;
    bool        enabled = true;
    const char* label = nullptr;
    bool        active = false;
    int8_t      xvalue = 0;
    int8_t      yvalue = 0;
    uint8_t     centering = RK_SPRING_CENTER;
};

class RK_Joystick : public RadioKit_Widget {
public:
    RK_Joystick(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);

    uint8_t inputSize()  const override { return 2; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;
    uint8_t variant() const override { return rk.centering; }
    uint16_t serializeStrings(uint8_t* buf) const override;

    RK_JoystickFields rk;

protected:
    float defaultAspect() const override { return 1.0f; }
    RK_JoystickFields _shadow;
};

#endif // RADIOKIT_WIDGET_JOYSTICK_H
