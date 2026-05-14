/**
 * Slider.h
 * RK_Slider — linear analog control (-100 to +100).
 *
 * variant byte: RK_VARIANT(centering, detents)
 *   bits[1:0] = centering  (RK_CENTER_NONE / LEFT / CENTER / RIGHT)
 *   bits[7:2] = detents    (0 = continuous, 1-63 = snap positions)
 */

#ifndef RADIOKIT_WIDGET_SLIDER_H
#define RADIOKIT_WIDGET_SLIDER_H

#include "Widget.h"

struct RK_SliderProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* label = nullptr;
    bool        active = false;
    int8_t      value = 0;
    uint8_t     centering = RK_SPRING_NONE;
    uint8_t     detents   = 0;
    uint8_t     variant   = 0;
};

class RK_Slider : public RadioKit_Widget {
public:
    RK_Slider(RK_SliderProps p);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)             const override {}
    void deserializeInput(const uint8_t* buf)        override;

    int8_t  get()           const { return props.value; }
    void    set(int8_t val)       { props.value = val > 100 ? 100 : (val < -100 ? -100 : val); }
    uint8_t centering()     const { return props.centering; }
    uint8_t detents()       const { return props.detents; }

    RK_SliderProps props;

protected:
    float defaultAspect() const override { return 5.0f; }
};

// ── GasPedal ──────────────────────────────────────────────────────────────
class RK_GasPedal : public RK_Slider {
public:
    RK_GasPedal(RK_SliderProps p) : RK_Slider(p) {
        typeId = RK_TYPE_SLIDER;
        props.variant = 1; // Gas Pedal variant
        props.centering = RK_SPRING_LEFT;
    }
};

#endif // RADIOKIT_WIDGET_SLIDER_H
