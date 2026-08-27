/**
 * Multiple.h
 * RK_MultipleButton — radio-group (single select)
 * RK_MultipleSelect  — checkbox-group (multi select)
 */

#ifndef RADIOKIT_WIDGET_MULTIPLE_H
#define RADIOKIT_WIDGET_MULTIPLE_H

#include "Widget.h"
#include <initializer_list>

struct RK_Item {
  const char *label = nullptr;
  const char *icon = nullptr;
  uint8_t pos = 255;
};

struct RK_MultipleFields {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* label = nullptr;
    bool        active = true;
    uint8_t     value = 0;                    // Selection mask
    uint8_t     variant = 0;                  // 0=Segments, 1=Grid, 2=Wheel
    uint8_t     itemMask = 0xFF;              // Item visibility bitmap (bit i: 1=visible, 0=hidden)
    RK_Item     items[RADIOKIT_MAX_ITEMS];    // Item pool
    uint8_t     itemCount = 0;
};

class RadioKit_Multiple : public RadioKit_Widget {
public:
    uint8_t inputSize()  const override { return 1; }
    uint8_t outputSize() const override { return 0; }
    uint16_t serializeStrings(uint8_t* buf) const override;
    uint8_t variant() const override { return rk.variant; }
    void serializeInput(uint8_t* buf)          const override;
    void serializeOutput(uint8_t*)           const override {}
    void deserializeInput(const uint8_t* buf)      override;

    void setItemMask(uint8_t mask) {
        rk.itemMask = mask;
        RadioKitClass::markConfDirty();
    }
    uint8_t itemMask() const { return rk.itemMask; }
    void setItemVisible(uint8_t index, bool visible) {
        if (index < 8) {
            if (visible) {
                rk.itemMask |= (1 << index);
            } else {
                rk.itemMask &= ~(1 << index);
            }
            RadioKitClass::markConfDirty();
        }
    }
    void setItemHidden(uint8_t index, bool hidden) {
        setItemVisible(index, !hidden);
    }
    bool isItemVisible(uint8_t index) const {
        if (index >= 8) return false;
        return (rk.itemMask & (1 << index)) != 0;
    }

    RK_MultipleFields rk;

protected:
    float defaultAspect() const override { return 1.0f; }
    RK_MultipleFields _shadow;

    void _initFromFields(const RK_MultipleFields& f, uint8_t tid);
};

class RK_MultipleButton : public RadioKit_Multiple {
public:
    RK_MultipleButton(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
};

class RK_MultipleSelect : public RadioKit_Multiple {
public:
    RK_MultipleSelect(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
};

#endif // RADIOKIT_WIDGET_MULTIPLE_H
