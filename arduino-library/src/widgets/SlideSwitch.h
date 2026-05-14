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

struct RK_SlideSwitchProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon  = nullptr;
    uint8_t     variant = 0;     // 0=Slide Switch (default), 1=Rocker Switch
    const char* onText = nullptr;
    const char* offText = nullptr;
    const char* label = nullptr;
    bool        active = false;
    bool        state = false;
};

class RK_SlideSwitch : public RadioKit_Widget {
public:
    RK_SlideSwitch(RK_SlideSwitchProps p);

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t* buf)         const override {}
    void deserializeInput(const uint8_t* buf)        override;

    bool get() const { return props.state; }
    void set(bool val) { props.state = val; }
    void setIcon(const char* val);

    RK_SlideSwitchProps props;

protected:
    float defaultAspect() const override { return 2.5f; }
};

class RK_RockerSwitch : public RK_SlideSwitch {
public:
    RK_RockerSwitch(RK_SlideSwitchProps p) : RK_SlideSwitch(p) {
        props.variant = 1;
    }
};

#endif // RADIOKIT_WIDGET_SLIDESWITCH_H
