#include "Text.h"
#include "../RadioKitLib.h"
#include <string.h>

RK_Text::RK_Text(uint8_t x, uint8_t y, uint8_t height, uint8_t width)
{
    typeId = RK_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
    rk.x = x;
    rk.y = y;
    rk.height = height;
    rk.width = width;
    rk.content = _text;
    _init(rk.label, x, y, height, width, 0, 0,
          nullptr, nullptr, nullptr, 0);
    _shadow = rk;
}

void RK_Text::serializeInput(uint8_t* buf) const {
    // Text widgets have no input state
}

void RK_Text::serializeOutput(uint8_t* buf) const {
  const char* src = rk.content ? rk.content : "";
  uint8_t len = (uint8_t)strnlen(src, RADIOKIT_TEXT_LEN - 1);
  buf[0] = len;
  if (len > 0) {
    memcpy(buf + 1, src, len);
  }
}

uint8_t RK_Text::outputSize() const {
  return RADIOKIT_TEXT_LEN;
}

uint16_t RK_Text::serializeStrings(uint8_t* buf) const {
    const char* lbl = (rk.label && rk.label[0] != '\0') ? rk.label : _label;
    uint8_t mask = 0;
    if (_labelHidden) mask |= RK_STR_LABEL_HIDDEN;
    if (_hidden)      mask |= RK_STR_WIDGET_HIDDEN;

    uint16_t out = 0;
    buf[out++] = mask;

    auto _writeStr = [&](const char* s, size_t maxLen) {
        uint8_t len = s ? (uint8_t)strnlen(s, maxLen < 255 ? maxLen : 255) : 0;
        buf[out++] = len;
        if (len > 0) memcpy(&buf[out], s, len);
        out += len;
    };

    _writeStr(lbl, RADIOKIT_MAX_LABEL);
    return out;
}

// RK_Serial
RK_Serial::RK_Serial(uint8_t x, uint8_t y, uint8_t height, uint8_t width) : RK_Text(x, y, height, width) {}

size_t RK_Serial::write(uint8_t c) {
    _text[0] = (char)c;
    _text[1] = '\0';
    rk.content = _text;
    RadioKit.pushUpdate(widgetId);
    return 1;
}

size_t RK_Serial::write(const uint8_t *buffer, size_t size) {
    if (!buffer || size == 0) return 0;
    size_t toCopy = (size < RADIOKIT_TEXT_LEN - 1) ? size : RADIOKIT_TEXT_LEN - 1;
    memcpy(_text, buffer, toCopy);
    _text[toCopy] = '\0';
    rk.content = _text;
    RadioKit.pushUpdate(widgetId);
    return toCopy;
}
