/**
 * Slider.h
 * RK_Slider — linear analog control (-100 to +100).
 *
 * variant byte: RK_VARIANT(centering, detents)
 *   bits[1:0] = centering  (RK_CENTER_NONE / CENTER / MIN / MAX)
 *   bits[6:2] = detents    (0 = continuous, 1-31 = snap positions)
 *   bit 7     = alt shape  (1 = GasPedal/Steering)
 */

#ifndef RADIOKIT_WIDGET_SLIDER_H
#define RADIOKIT_WIDGET_SLIDER_H

#define RK_SHAPE_STANDARD 0x00
#define RK_SHAPE_ALT      0x80

#include "Widget.h"

struct RK_SliderFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* label = nullptr;
    bool        active = false;
    int8_t      value = 0;
    uint8_t     centering = RK_SPRING_NONE;
    uint8_t     detents   = 0;
    // variant is auto-derived from centering+detents
};

class RK_Slider : public RadioKit_Widget {
public:
    RK_Slider(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)             const override {}
    void deserializeInput(const uint8_t* buf)        override;

    RK_SliderFields rk;

protected:
    float defaultAspect() const override { return 5.0f; }
    RK_SliderFields _shadow;  ///< Shadow copy for change detection
};

// ── GasPedal ──────────────────────────────────────────────────────────────
class RK_GasPedal : public RK_Slider {
public:
    RK_GasPedal(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
};

#endif // RADIOKIT_WIDGET_SLIDER_H
