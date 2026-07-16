#include "Widget.h"
#include "../RadioKitLib.h"
#include <string.h>

// ── Deferred registration list ──────────────────────────────────────────────
struct _DeferredNode {
    RadioKit_Widget*  widget;
    _DeferredNode*    next;
};

static _DeferredNode* s_deferredHead = nullptr;

static void _pushDeferred(RadioKit_Widget* w) {
    _DeferredNode* node = new _DeferredNode{w, s_deferredHead};
    s_deferredHead = node;
}

void RadioKit_Widget_drainDeferred() {
    uint8_t count = 0;
    _DeferredNode* n = s_deferredHead;
    while (n) { count++; n = n->next; }
    if (count == 0) return;

    RadioKit_Widget** arr = new RadioKit_Widget*[count];
    n = s_deferredHead;
    for (int8_t i = (int8_t)(count - 1); i >= 0; i--) {
        arr[i] = n->widget;
        n = n->next;
    }
    for (uint8_t i = 0; i < count; i++) {
        RadioKit._registerWidget(arr[i]);
    }
    delete[] arr;

    n = s_deferredHead;
    while (n) {
        _DeferredNode* next = n->next;
        delete n;
        n = next;
    }
    s_deferredHead = nullptr;
}

// ── Widget base implementation ──────────────────────────────────────────────

RadioKit_Widget::RadioKit_Widget()
    : typeId(0), widgetId(0)
    , _x(0), _y(0), _page(0), _height(10), _width(0)
    , _rotation(0), _enabled(true)
    , _style(0), _variant(0)
{
    _label[0]   = '\0';
    _icon[0]    = '\0';
    _onText[0]  = '\0';
    _offText[0] = '\0';
}

void RadioKit_Widget::_init(
    const char* label,  uint8_t x,       uint8_t y,
    uint8_t height,     uint8_t width,
    uint8_t style,      uint8_t variant,
    const char* icon,   const char* onText, const char* offText,
    int16_t rotation, uint8_t page)
{
    _x        = x;
    _y        = y;
    _page     = page;
    _height   = height;
    _width    = width;
    _rotation = rotation;
    _enabled  = true;
    _style    = style;
    _variant  = variant;

    auto _copyStr = [](char* dst, const char* src, size_t maxLen) {
        if (src && src[0] != '\0') {
            strncpy(dst, src, maxLen);
            dst[maxLen] = '\0';
        } else {
            dst[0] = '\0';
        }
    };

    _copyStr(_label,   label,   RADIOKIT_MAX_LABEL);
    _copyStr(_icon,    icon,    RADIOKIT_MAX_ICON);
    _copyStr(_onText,  onText,  RADIOKIT_MAX_LABEL);
    _copyStr(_offText, offText, RADIOKIT_MAX_LABEL);

    _registerSelf();
}

void RadioKit_Widget::_registerSelf() {
    _pushDeferred(this);
}

uint16_t RadioKit_Widget::serializeStrings(uint8_t* buf) const {
    uint8_t mask = 0;
    // Bit 0 reserved — label is always present.
    if (_labelHidden) mask |= RK_STR_LABEL_HIDDEN;
    if (_hidden)      mask |= RK_STR_WIDGET_HIDDEN;
    if (_icon[0]    != '\0') mask |= RK_STR_ICON;
    if (_onText[0]  != '\0') mask |= RK_STR_ONTEXT;
    if (_offText[0] != '\0') mask |= RK_STR_OFFTEXT;
    
    const char* content = getContent();
    if (content && content[0] != '\0') mask |= RK_STR_CONTENT;

    uint16_t out = 0;
    buf[out++] = mask;

    auto _writeStr = [&](const char* s, size_t maxLen) {
        uint8_t len = (uint8_t)strnlen(s, maxLen < 255 ? maxLen : 255);
        buf[out++] = len;
        memcpy(&buf[out], s, len);
        out += len;
    };

    // Label is always serialized (no mask bit).
    _writeStr(_label, RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_ICON)    _writeStr(_icon,    RADIOKIT_MAX_ICON);
    if (mask & RK_STR_ONTEXT)  _writeStr(_onText,  RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_OFFTEXT) _writeStr(_offText, RADIOKIT_MAX_LABEL);
    if (mask & RK_STR_CONTENT) _writeStr(content,  RADIOKIT_TEXT_LEN);

    return out;
}
