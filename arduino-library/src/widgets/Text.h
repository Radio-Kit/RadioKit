/**
 * Text.h
 * RK_Text & RK_Serial — dynamic text display label (Arduino → App).
 */

#ifndef RADIOKIT_WIDGET_TEXT_H
#define RADIOKIT_WIDGET_TEXT_H

#include "Widget.h"

struct RK_TextProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    const char* label = nullptr;
    const char* content = "";
};

class RK_Text : public RadioKit_Widget {
public:
    RK_Text(RK_TextProps p);

    uint8_t inputSize()  const override { return 0; }
    uint8_t outputSize() const override;
    void serializeInput(uint8_t*)           const override;
    void serializeOutput(uint8_t* buf)         const override;
    void deserializeInput(const uint8_t*)            override {}

    void        set(const char* text);
    void        set(const String& s) { set(s.c_str()); }
    const char* get() const { return _text; }

    RK_TextProps props;

protected:
    float defaultAspect() const override { return 4.0f; }

private:
    char _text[RADIOKIT_TEXT_LEN];
};

class RK_Serial : public RK_Text, public Print {
public:
    RK_Serial(RK_TextProps p);
    size_t write(uint8_t c) override;
    size_t write(const uint8_t *buffer, size_t size) override;
};

#endif // RADIOKIT_WIDGET_TEXT_H
