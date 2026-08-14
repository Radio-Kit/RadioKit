/**
 * Button.h
 * RK_PushButton  — momentary (true while held)
 * RK_ToggleButton — latched (toggles on tap)
 */

#ifndef RADIOKIT_WIDGET_BUTTON_H
#define RADIOKIT_WIDGET_BUTTON_H

#include "Widget.h"
#include <initializer_list>

// ── Field struct ───────────────────────────────────────────────────────
struct RK_ButtonFields {
    // Spatial (set by constructor, reassignable)
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;

    // Strings (pointers to base class buffers, set after construction)
    const char* icon    = nullptr;
    const char* onText  = nullptr;
    const char* offText = nullptr;
    const char* label   = nullptr;

    // State
    bool        active = false;    ///< Transport active flag (internal)
    bool        state  = false;    ///< Push/toggle state
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
    uint16_t serializeStrings(uint8_t* buf)    const override;

    // Canonical fields — all state access through rk.
    RK_ButtonFields rk;

protected:
    float   defaultAspect() const override { return 1.0f; }
    bool    _pendingPress = false;

    // Shadow copy for change detection on RadioKit.update()
    RK_ButtonFields _shadow;

    void _initFromProps(const RK_ButtonFields& p, uint8_t typeId);
};

// ── PushButton ─────────────────────────────────────────────────────────────
class RK_PushButton : public RadioKit_Button {
public:
    RK_PushButton(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
};

// ── ToggleButton ────────────────────────────────────────────────────────────
class RK_ToggleButton : public RadioKit_Button {
public:
    RK_ToggleButton(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
};

#endif // RADIOKIT_WIDGET_BUTTON_H
