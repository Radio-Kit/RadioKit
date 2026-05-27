/**
 * Button.h
 * RK_PushButton  — momentary (true while held)
 * RK_ToggleButton — latched (toggles on tap)
 */

#ifndef RADIOKIT_WIDGET_BUTTON_H
#define RADIOKIT_WIDGET_BUTTON_H

#include "Widget.h"
#include <initializer_list>

// ── Props struct ───────────────────────────────────────────────────────
struct RK_ButtonProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon  = nullptr;
    const char* onText = nullptr;
    const char* offText = nullptr;
    const char* label = nullptr;
    bool        active = false;
    bool        state = false;
};

// ── Shared implementation base ──────────────────────────────────────────────
class RadioKit_Button : public RadioKit_Widget {
public:
    static constexpr uint8_t DEFAULT_ASPECT = 10;

    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t* buf)         const override {}
    void deserializeInput(const uint8_t* buf)        override;

    bool get() const { return props.state; }
    void set(bool val);
    void setOnText(const char* val) { props.onText = val; }
    void setOffText(const char* val) { props.offText = val; }

    RK_ButtonProps props;

protected:
    float   defaultAspect() const override { return 1.0f; }
    bool    _pendingPress = false;

    void _initFromProps(const RK_ButtonProps& p, uint8_t typeId);
};

// ── PushButton ─────────────────────────────────────────────────────────────
class RK_PushButton : public RadioKit_Button {
public:
    RK_PushButton(RK_ButtonProps p);
    bool isPressed();
    bool clicked();
};

// ── ToggleButton ────────────────────────────────────────────────────────────
class RK_ToggleButton : public RadioKit_Button {
public:
    RK_ToggleButton(RK_ButtonProps p);
};

#endif // RADIOKIT_WIDGET_BUTTON_H
