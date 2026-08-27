/**
 * Widget.h
 * Abstract base class for all RadioKit widgets (v2.0).
 */

#ifndef RADIOKIT_WIDGET_H
#define RADIOKIT_WIDGET_H

#include <Arduino.h>
#include <stdint.h>
#include "../RadioKitConfig.h"
#include "../RadioKitClass.h"

// Visual shape flags (variant byte bit 7).
#define RK_SHAPE_STANDARD 0x00
#define RK_SHAPE_ALT      0x80

class RadioKit_Widget {
public:
    RadioKit_Widget();
    virtual ~RadioKit_Widget() {}

    // ── Identity ───────────────────────────────────────────────────────
    uint8_t typeId;
    uint8_t widgetId;

    // ── Accessors ──────────────────────────────────────────────────────
    uint8_t     x()        const { return _x; }
    uint8_t     y()        const { return _y; }
    /// Height in virtual units (0-200).
    uint8_t     height()   const { return _height; }
    /// Width in virtual units (0-200).
    uint8_t     width()    const { return _width; }
    /// Page index this widget belongs to (0-based).
    uint8_t     page()     const { return _page; }
    /// Rotation in degrees (absolute).
    int16_t     rotation() const { return _rotation; }
    bool        enabled()  const { return _enabled; }
    uint8_t     style()    const { return _style; }
    virtual uint8_t variant() const { return _variant; }
    const char* label()    const { return _label; }
    const char* icon()     const { return _icon; }
    const char* onText()   const { return _onText; }
    const char* offText()  const { return _offText; }
    bool        labelHidden() const { return _labelHidden; }
    bool        hidden() const { return _hidden; }

    void setLabelHidden(bool hidden) {
        _labelHidden = hidden;
        RadioKitClass::markConfDirty();
    }
    void setHidden(bool hidden) {
        _hidden = hidden;
        RadioKitClass::markConfDirty();
    }
    void setPage(uint8_t p) { _page = p; }

    // ── Serialization ─────────────────────────────────────────────────────
    virtual uint8_t inputSize()  const = 0;
    virtual uint8_t outputSize() const = 0;
    /// Writes the current input-side value(s) to [buf]. Called by GET_VARS.
    virtual void serializeInput(uint8_t* buf)          const = 0;
    /// Writes the current output-side value(s) to [buf]. Called by GET_VARS.
    virtual void serializeOutput(uint8_t* buf)         const = 0;
    virtual void deserializeInput(const uint8_t* buf)        = 0;

    virtual uint16_t serializeStrings(uint8_t* buf) const;
    virtual const char* getContent() const { return nullptr; }

protected:
    uint8_t  _x, _y;
    uint8_t  _page;
    uint8_t  _height;
    uint8_t  _width;
    int16_t  _rotation;
    bool     _enabled;
    bool     _labelHidden = false;
    bool     _hidden = false;
    uint8_t  _style;
    uint8_t  _variant;
    char     _label  [RADIOKIT_MAX_LABEL + 1];
    char     _icon   [RADIOKIT_MAX_ICON  + 1];
    char     _onText [RADIOKIT_MAX_LABEL + 1];
    char     _offText[RADIOKIT_MAX_LABEL + 1];

    virtual float defaultAspect() const = 0;

    /// rotation defaults to 0. Positive = clockwise in degrees.
    void _init(const char* label,  uint8_t x,        uint8_t y,
               uint8_t height,     uint8_t width,
               uint8_t style,      uint8_t variant,
               const char* icon,   const char* onText, const char* offText,
               int16_t rotation = 0, uint8_t page = 0);

private:
    void _registerSelf();
};

// ── Static helper ────────────────────────────────────────────────────────
static inline uint8_t _clampUint8(int val) {
    if (val < 0) return 0;
    return (val > 255) ? 255 : (uint8_t)val;
}

#endif // RADIOKIT_WIDGET_H
