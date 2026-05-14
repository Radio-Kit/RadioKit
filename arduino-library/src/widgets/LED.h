/**
 * LED.h
 * RK_LED — visual status indicator (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_LED_H
#define RADIOKIT_WIDGET_LED_H

#include "Widget.h"

struct RK_LedProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* label = nullptr;
    uint32_t    color = RK_OFF;
    bool        state = false;
};

class RK_LED : public RadioKit_Widget {
public:
    RK_LED(RK_LedProps p);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return 5; } // STATE + R + G + B + OPACITY
    void serializeInput(uint8_t*)           const override;
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    void on();
    void off();
    void set(bool val);
    void setColor(uint32_t val);

    RK_LedProps props;

protected:
    float defaultAspect() const override { return 1.0f; }
};

#endif // RADIOKIT_WIDGET_LED_H
