/**
 * Serial.h
 * RK_Serial — serial monitor display (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_SERIAL_H
#define RADIOKIT_WIDGET_SERIAL_H

#include "Widget.h"
#include "Text.h"  // For RK_DisplayProps

class RK_Serial : public RadioKit_Widget {
public:
  RK_Serial(RK_DisplayProps p);

  uint8_t inputSize()  const override { return 0; }
  uint8_t outputSize() const override;
  void serializeInput(uint8_t*)           const override;
  void serializeOutput(uint8_t* buf)         const override;
  void deserializeInput(const uint8_t*)            override {}

  void set(const char* text);
  void set(const String& s) { set(s.c_str()); }
  const char* get() const { return _text; }

  void print(...);
  void println(...);
  void clear();

  RK_DisplayProps props;

protected:
  float defaultAspect() const override { return 4.0f; }

private:
  char _text[RADIOKIT_TEXT_LEN];
};

#endif // RADIOKIT_WIDGET_SERIAL_H
