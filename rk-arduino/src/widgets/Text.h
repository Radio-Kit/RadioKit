/**
 * Text.h
 * RK_Text & RK_Serial — dynamic text display label (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_TEXT_H
#define RADIOKIT_WIDGET_TEXT_H

#include "Widget.h"

struct RK_TextFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    const char* label = nullptr;
    const char* content = "";    ///< Pointer to widget's _text buffer
};

class RK_Text : public RadioKit_Widget {
public:
    RK_Text(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override;
    void serializeInput(uint8_t*)           const override;
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    RK_TextFields rk;

protected:
    float defaultAspect() const override { return 4.0f; }
    RK_TextFields _shadow;
    char _text[RADIOKIT_TEXT_LEN];
};

class RK_Serial : public RK_Text, public Print {
public:
    RK_Serial(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0);
    size_t write(uint8_t c) override;
    size_t write(const uint8_t *buffer, size_t size) override;
};

class RK_SerialMonitor : public RK_Serial {
public:
    using RK_Serial::RK_Serial;
};

#endif // RADIOKIT_WIDGET_TEXT_H
