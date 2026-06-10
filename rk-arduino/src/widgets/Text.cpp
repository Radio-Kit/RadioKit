#include "Text.h"
#include "../RadioKitLib.h"
#include <string.h>

RK_Text::RK_Text(RK_TextProps p)
    : props(p)
{
    typeId = RK_TYPE_TEXT;
    memset(_text, 0, RADIOKIT_TEXT_LEN);
    if (p.content && p.content[0] != '\0') {
        strncpy(_text, p.content, RADIOKIT_TEXT_LEN - 1);
    }
    _init(p.label, p.x, p.y, p.height, p.width, 0, 0,
          nullptr, nullptr, nullptr, 0);
}

void RK_Text::set(const char* text) {
    if (!text) { memset(_text, 0, RADIOKIT_TEXT_LEN); return; }
    strncpy(_text, text, RADIOKIT_TEXT_LEN - 1);
    _text[RADIOKIT_TEXT_LEN - 1] = '\0';
    props.content = _text;
    RadioKit.pushUpdate(widgetId);
}

void RK_Text::serializeInput(uint8_t* buf) const {
    // Text widgets have no input state
}

void RK_Text::serializeOutput(uint8_t* buf) const {
  uint8_t len = (uint8_t)strlen(_text);
  buf[0] = len;
  if (len > 0) {
    memcpy(buf + 1, _text, len);
  }
}

uint8_t RK_Text::outputSize() const {
  return RADIOKIT_TEXT_LEN;
}

// RK_Serial
RK_Serial::RK_Serial(RK_TextProps p) : RK_Text(p) {}

size_t RK_Serial::write(uint8_t c) {
    char s[2] = {(char)c, 0};
    set(s);
    return 1;
}

size_t RK_Serial::write(const uint8_t *buffer, size_t size) {
    if (!buffer || size == 0) return 0;
    char temp[RADIOKIT_TEXT_LEN];
    size_t toCopy = (size < RADIOKIT_TEXT_LEN - 1) ? size : RADIOKIT_TEXT_LEN - 1;
    memcpy(temp, buffer, toCopy);
    temp[toCopy] = '\0';
    set(temp);
    return toCopy;
}
