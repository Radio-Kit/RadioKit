/**
 * SlideSwitch.h
 * RK_SlideSwitch — iOS-style slide/toggle switch for binary on/off control.
 * Unlike RK_ToggleButton (renders as a button), SlideSwitch renders as a
 * horizontal track with a sliding thumb.
 */

#ifndef RADIOKIT_WIDGET_SLIDESWITCH_H
#define RADIOKIT_WIDGET_SLIDESWITCH_H

#include "Widget.h"
#include <initializer_list>

struct RK_SlideSwitchFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon  = nullptr;
    uint8_t     variant = 0;     // 0=Slide Switch (default), 1=Rocker Switch
    const char* onText = nullptr;
    const char* offText = nullptr;
    const char* label = nullptr;
    bool        labelHidden = false;
    bool        active = false;
    bool        state = false;
};

class RK_SlideSwitch : public RadioKit_Widget {
public:
    RK_SlideSwitch(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t* buf)         const override {}
    void deserializeInput(const uint8_t* buf)        override;
    uint8_t variant() const override { return rk.variant; }
    uint16_t serializeStrings(uint8_t* buf) const override;

    RK_SlideSwitchFields rk;

protected:
    float defaultAspect() const override { return 2.5f; }
    RK_SlideSwitchFields _shadow;
};

class RK_RockerSwitch : public RK_SlideSwitch {
public:
    RK_RockerSwitch(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
};

#endif // RADIOKIT_WIDGET_SLIDESWITCH_H
