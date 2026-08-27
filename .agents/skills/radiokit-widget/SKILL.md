---
name: radiokit-widget
description: Guide for creating or modifying widget types in the RadioKit Arduino library. This skill should be used when adding new widget classes to rk-arduino/src/widgets/, modifying widget rk fields, or changing how widgets encode/decode in the protocol.
---

# RadioKit Widget Development

## Overview

This skill covers creating and modifying widget types in the RadioKit Arduino library. Widgets are the core UI primitives — each has a C++ class, an `rk` struct for public state, and protocol encoding for BLE/WiFi/Cloud transport.

## Widget File Structure

Every widget type consists of:

```
rk-arduino/src/widgets/
  Widget.h / Widget.cpp       # Base class (RK_Widget)
  <WidgetName>.h              # Header: class + rk struct definition
  <WidgetName>.cpp            # Implementation: constructor, protocol encode/decode
```

## Base Class: RK_Widget

All widgets inherit from `RK_Widget` (in `Widget.h`/`Widget.cpp`):

```cpp
class RK_Widget {
public:
  uint8_t _id;          // Auto-assigned by RadioKit._registerWidget()
  uint8_t _type;        // Widget type constant (RK_WIDGET_BUTTON, etc.)

  virtual void encode(uint8_t* buf, uint8_t& len) = 0;
  virtual void decode(const uint8_t* buf, uint8_t len) = 0;

  // Self-registration happens in Widget.cpp constructor
  RK_Widget();
};
```

Key behaviors:
- Widgets are **self-registering** — constructing a global instance calls `RadioKit._registerWidget()`
- `encode()` serializes current `rk` state into a protocol frame
- `decode()` applies incoming state from the companion app
- Max 16 widgets per device (excess silently dropped)

## rk Struct Pattern

Every widget exposes a public `rk` struct:

```cpp
struct RK_ButtonFields {
  bool state;
  const char* icon;
  const char* onText;
  const char* offText;
  const char* label;

  // Spatial fields (inherited from all widgets)
  uint8_t x, y, height, width;
  int16_t rotation;
};
```

### Rules for rk structs

1. **All fields are public** — no getters/setters
2. **Spatial fields** (`x`, `y`, `height`, `width`, `rotation`) are on every widget
3. **Read fields** are updated by `decode()` from incoming protocol frames
4. **Write fields** are read by `encode()` and sent to the companion app
5. **String fields** must be `const char*` pointing to string literals (max lengths enforced by protocol)

## Shadow Comparison

The `RadioKit.update()` loop compares each widget's `rk` struct against a `_shadow` copy. If any field changed, the updated state is pushed to all connected transports.

```cpp
// In RadioKit.cpp update loop:
for (int i = 0; i < _widgetCount; i++) {
  uint8_t buf[RK_MAX_PACKET_SIZE];
  uint8_t len;
  _widgets[i]->encode(buf, len);
  if (memcmp(buf, _shadow[i], len) != 0) {
    sendPacket(buf, len);
    memcpy(_shadow[i], buf, len);
  }
}
```

This means: **set `rk` fields in your `loop()` and the library handles transport automatically**.

## Adding a New Widget Type

### Step 1: Define the rk struct and class header

```cpp
// MyWidget.h
#pragma once
#include "Widget.h"

struct RK_MyWidgetFields {
  uint8_t x, y, height, width;
  int16_t rotation;
  int8_t value;          // Example: -100 to +100
  bool state;            // Example: on/off
  const char* label;
  const char* icon;
};

class RK_MyWidget : public RK_Widget {
public:
  RK_MyWidgetFields rk;

  RK_MyWidget(uint8_t x, uint8_t y, uint8_t height, uint8_t width = 0, int16_t rotation = 0);
  void encode(uint8_t* buf, uint8_t& len) override;
  void decode(const uint8_t* buf, uint8_t len) override;
};
```

### Step 2: Implement the cpp file

```cpp
// MyWidget.cpp
#include "MyWidget.h"
#include "../RadioKitProtocol.h"

RK_MyWidget::RK_MyWidget(uint8_t x, uint8_t y, uint8_t h, uint8_t w, int16_t rot) {
  _type = RK_WIDGET_MY_TYPE;  // Add constant to RadioKitProtocol.h
  rk.x = x;
  rk.y = y;
  rk.height = h;
  rk.width = w;
  rk.rotation = rot;
  rk.value = 0;
  rk.state = false;
  rk.label = "";
  rk.icon = "";
}

void RK_MyWidget::encode(uint8_t* buf, uint8_t& len) {
  buf[0] = _type;
  buf[1] = rk.value;
  buf[2] = rk.state ? 1 : 0;
  len = 3;
  // Add string encoding as needed
}

void RK_MyWidget::decode(const uint8_t* buf, uint8_t len) {
  if (len >= 3) {
    rk.value = (int8_t)buf[1];
    rk.state = buf[2] != 0;
  }
}
```

### Step 3: Register in RadioKitWidgets.h

```cpp
// RadioKitWidgets.h
#include "widgets/MyWidget.h"
```

### Step 4: Add type constant to RadioKitProtocol.h

```cpp
#define RK_WIDGET_MY_TYPE 0x0N  // Next available type constant
```

### Step 5: Handle in protocol encode/decode

Update `RadioKitProtocol.cpp` to handle the new widget type in the frame parser.

## Widget Type Constants

Current allocations in `RadioKitProtocol.h`:

| Constant | Type | Value |
|----------|------|-------|
| `RK_WIDGET_BUTTON` | PushButton/ToggleButton | 0x01 |
| `RK_WIDGET_SLIDER` | Slider/GasPedal | 0x02 |
| `RK_WIDGET_JOYSTICK` | Joystick | 0x03 |
| `RK_WIDGET_KNOB` | Knob/SteeringWheel | 0x04 |
| `RK_WIDGET_SLIDE_SWITCH` | SlideSwitch/RockerSwitch | 0x05 |
| `RK_WIDGET_LED` | LED | 0x06 |
| `RK_WIDGET_TEXT` | Text/Serial/SerialMonitor | 0x07 |
| `RK_WIDGET_MULTI` | MultipleButton/MultipleSelect | 0x08 |
| `RK_WIDGET_TELEMETRY` | Telemetry | 0x09 |

## Variant Pattern

Widgets with variants (e.g., `RK_Slider` / `RK_GasPedal`) share a base type but differ in behavior:

```cpp
class RK_GasPedal : public RK_Slider {
public:
  RK_GasPedal(uint8_t x, uint8_t y, uint8_t height);
  // Inherits encode/decode from RK_Slider
  // Constructor auto-sets spring centering and alt shape
};
```

The `variant` field in JSON config distinguishes them. The protocol uses the same type byte.

## Length Limits

| Field | Max Length |
|-------|-----------|
| `label` | 32 chars |
| `icon` | 24 chars |
| `onText` / `offText` | 32 chars |
| `content` (Text) | 32 chars |
| `items[].label` | 32 chars |
| `items[].icon` | 24 chars |
| Widget name (identifier) | 32 chars |

## Important Notes

1. **Widget names use `snake_case`** — e.g., `button_1`, `slider_2`, `my_widget`
2. **String fields must be string literals** — not dynamically allocated
3. **Protocol encoding is positional** — fields are packed by byte offset, not length-prefixed
4. **Shadow comparison is byte-level** — `memcmp()` on the encoded buffer
5. **Constructor sets defaults** — all `rk` fields should have sensible initial values
