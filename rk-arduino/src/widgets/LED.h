/**
 * LED.h
 * RK_LED — visual status indicator (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_LED_H
#define RADIOKIT_WIDGET_LED_H

#include "Widget.h"

#define RK_LED_SHAPE_CIRCLE   0
#define RK_LED_SHAPE_SQUARE   1
#define RK_LED_SHAPE_DIAMOND  2
#define RK_LED_SHAPE_STAR     3

#define RK_LED_STATE_OFF      0
#define RK_LED_STATE_ON       1
#define RK_LED_STATE_BLINK    2
#define RK_LED_STATE_BREATHE  3

struct RK_LedFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* label = nullptr;
    uint32_t    color = RK_OFF;
    bool        state = false;
    uint8_t     shape = RK_LED_SHAPE_CIRCLE;
    uint8_t     ledState = RK_LED_STATE_ON;
    uint16_t    timing = 500;
};

class RK_LED : public RadioKit_Widget {
public:
    RK_LED(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override { return 5; }
    void serializeInput(uint8_t*)           const override;
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}
    uint16_t serializeStrings(uint8_t* buf)    const override;

    RK_LedFields rk;

protected:
    float defaultAspect() const override { return 1.0f; }
    RK_LedFields _shadow;
};

#endif // RADIOKIT_WIDGET_LED_H
