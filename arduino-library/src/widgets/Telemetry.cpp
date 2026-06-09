#include "Telemetry.h"
#include "../RadioKitLib.h"
#include <string.h>

RK_Telemetry::RK_Telemetry(const char* label, const char* icon, const char* unit)
{
    typeId = RK_TYPE_TELEMETRY;
    memset(_text, 0, sizeof(_text));
    memset(_unit, 0, sizeof(_unit));

    if (unit && unit[0] != '\0') {
        strncpy(_unit, unit, RADIOKIT_TEXT_LEN);
        _unit[RADIOKIT_TEXT_LEN] = '\0';
    }

    // Telemetry widgets have no canvas position — pass 0 for all spatial params.
    // label, icon are used by the Flutter app to identify and render the widget.
    _init(label,
          0,     // x
          0,     // y
          0,     // height
          0,     // width
          0,     // style
          0,     // variant
          icon,  // icon (used by app for rendering)
          nullptr, // onText (not used)
          nullptr, // offText (not used)
          0);    // rotation
}

void RK_Telemetry::set(const char* text) {
    if (!text) { memset(_text, 0, sizeof(_text)); return; }
    strncpy(_text, text, RADIOKIT_TEXT_LEN);
    _text[RADIOKIT_TEXT_LEN] = '\0';
    RadioKit.pushUpdate(widgetId);
}

void RK_Telemetry::serializeOutput(uint8_t* buf) const {
    uint8_t len = (uint8_t)strlen(_text);
    buf[0] = len;
    if (len > 0) {
        memcpy(buf + 1, _text, len);
    }
}

uint8_t RK_Telemetry::outputSize() const {
    return RADIOKIT_TEXT_LEN + 1; // length byte + text
}
