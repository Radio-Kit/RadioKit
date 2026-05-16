/**
 * Joystick.h
 * RK_Joystick — 2-axis analog controller (-100 to +100).
 */

#ifndef RADIOKIT_WIDGET_JOYSTICK_H
#define RADIOKIT_WIDGET_JOYSTICK_H

#include "Widget.h"

struct RK_JoystickProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon = nullptr;
    bool        enabled = true;
    uint8_t     centering = RK_SPRING_CENTER;
    const char* label = nullptr;
    bool        active = false;
    int8_t      xvalue = 0;
    int8_t      yvalue = 0;
};

class RK_Joystick : public RadioKit_Widget {
public:
    RK_Joystick(RK_JoystickProps p);

    uint8_t inputSize()  const override { return 2; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    int8_t getX() const { return props.xvalue; }
    int8_t getY() const { return props.yvalue; }
    uint8_t centering() const { return props.centering; }

    RK_JoystickProps props;

protected:
    float defaultAspect() const override { return 1.0f; }
};

#endif // RADIOKIT_WIDGET_JOYSTICK_H
