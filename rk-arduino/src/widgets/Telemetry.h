/**
 * Telemetry.h
 * RK_Telemetry — display-only widget for telemetry values.
 *
 * Telemetry widgets are not positioned on the canvas. They are registered
 * as regular widgets (widget protocol 0x55) so they can push VAR_DATA
 * updates, but the Flutter app renders them in the active link card
 * rather than on the control canvas.
 *
 * Each telemetry widget has:
 *   - label  (C++ identifier, also used as the serialization label)
 *   - icon   (icon name for the app to render)
 *   - value  (dynamic text set via rk.content)
 *
 * The unit is metadata stored in the JSON config (not sent over the wire).
 */

#ifndef RADIOKIT_WIDGET_TELEMETRY_H
#define RADIOKIT_WIDGET_TELEMETRY_H

#include "Widget.h"

struct RK_TelemetryFields {
    const char* label   = nullptr;
    const char* icon    = nullptr;
    const char* unit    = nullptr;
    const char* content = "";     ///< Dynamic text value (points to _text buffer)
};

class RK_Telemetry : public RadioKit_Widget {
public:
    RK_Telemetry(const char* label);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override;
    void serializeInput(uint8_t*)           const override {}
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    /// Returns the current value text for serialization (content field).
    const char* getContent() const override { return rk.content; }

    RK_TelemetryFields rk;

protected:
    float defaultAspect() const override { return 1.0f; }
    RK_TelemetryFields _shadow;

private:
    char _text[RADIOKIT_TEXT_LEN + 1];
    char _unit[RADIOKIT_TEXT_LEN + 1];
};

#endif // RADIOKIT_WIDGET_TELEMETRY_H
