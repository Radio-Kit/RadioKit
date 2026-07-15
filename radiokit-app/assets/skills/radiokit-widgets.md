---
name: radiokit-widgets
description: Guide for using all widget types in RadioKit firmware. Use this skill when adding widgets to an Arduino sketch, reading input values, or updating output state from code.
---

# RadioKit Widgets (Firmware Reference)

## Overview

Widgets are the core UI primitives in RadioKit. Each widget is a C++ class declared as a global variable. On construction, it self-registers with the RadioKit library. You interact with widgets through their public `rk` struct fields.

**Direction model**:
- **Input widgets** (app -> device): Buttons, Sliders, Joysticks, Knobs, Switches -- the app sends state TO the firmware.
- **Output widgets** (device -> app): LEDs, Text -- the firmware sends state TO the app.
- **Bidirectional**: Some widgets can be both (e.g., ToggleButton state can be set from either side).

## General Pattern

```cpp
// 1. Declare globally (auto-registers with RadioKit)
RK_PushButton myButton(20, 60, 20);    // x, y, height, [width], [rotation]

// 2. Configure in setup (optional)
myButton.rk.onText = "ON";
myButton.rk.offText = "OFF";

// 3. Read input in loop
if (myButton.rk.state) { /* button is pressed */ }

// 4. Write output in loop
myLed.rk.state = true;
```

## Input Widgets

### RK_PushButton

Momentary push button. State is `true` while pressed, `false` when released.

```cpp
RK_PushButton btn(20, 60, 20);          // x, y, height
RK_PushButton btn(20, 60, 20, 40);      // with width
RK_PushButton btn(20, 60, 20, 40, 90);  // with rotation
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `state` | `bool` | true/false | Current press state |
| `icon` | `const char*` | max 24 chars | Icon name |
| `onText` | `const char*` | max 32 chars | Text when active |
| `offText` | `const char*` | max 32 chars | Text when inactive |
| `label` | `const char*` | max 32 chars | Display label |

### RK_ToggleButton

Toggle button. State latches on each press.

```cpp
RK_ToggleButton toggle(20, 60, 20);
```

Same rk fields as PushButton. `state` toggles between `true`/`false` on each press.

### RK_Slider

Continuous slider with range -100 to +100.

```cpp
RK_Slider slider(20, 20, 15, 80);       // x, y, height, width
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `value` | `int8_t` | -100..+100 | Current slider position |
| `centering` | `uint8_t` | 0-5 | Spring behavior (see below) |
| `detents` | `uint8_t` | 0-63 | Snap positions (0 = continuous) |
| `label` | `const char*` | max 32 chars | Display label |

**Spring constants**:
```cpp
RK_SPRING_NONE    // 0 - No spring return
RK_SPRING_CENTER  // 1 - Springs to center (0)
RK_SPRING_MIN     // 2 - Springs to min (-100)
RK_SPRING_MAX     // 3 - Springs to max (+100)
RK_SPRING_TOP     // 4 - Springs to top (-100, vertical)
RK_SPRING_BOTTOM  // 5 - Springs to bottom (+100, vertical)
```

### RK_GasPedal

Gas pedal variant of Slider. Auto-set to spring-center from min.

```cpp
RK_GasPedal pedal(20, 60, 30);
```

Same fields as Slider. Default: `centering = RK_SPRING_MIN`.

### RK_Joystick

2-axis joystick. Both axes range -100 to +100.

```cpp
RK_Joystick joy(20, 20, 40);            // Square joystick
RK_Joystick joy(20, 20, 40, 40);        // Rectangular
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `xvalue` | `int8_t` | -100..+100 | Horizontal axis |
| `yvalue` | `int8_t` | -100..+100 | Vertical axis |
| `enabled` | `bool` | true/false | Joystick active state |
| `centering` | `uint8_t` | 0-5 | Spring behavior |
| `icon` | `const char*` | max 24 chars | Center icon |
| `label` | `const char*` | max 32 chars | Display label |

### RK_Knob

Rotary knob. Value -100 to +100 mapped to angular range.

```cpp
RK_Knob knob(100, 50, 25);
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `value` | `int8_t` | -100..+100 | Knob position |
| `startAngle` | `int16_t` | degrees | Min angle (default -135) |
| `endAngle` | `int16_t` | degrees | Max angle (default +135) |
| `centering` | `uint8_t` | 0-5 | Spring behavior |
| `detents` | `uint8_t` | 0-63 | Snap positions |
| `centerIcon` | `const char*` | max 24 chars | Center position icon |

### RK_SteeringWheel

Steering wheel variant of Knob. Auto-set to spring-center.

```cpp
RK_SteeringWheel wheel(100, 50, 30);
```

Same fields as Knob. Default: `centering = RK_SPRING_CENTER`.

### RK_SlideSwitch

Physical slide switch emulation.

```cpp
RK_SlideSwitch slide(20, 60, 15);
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `state` | `bool` | true/false | Switch position |
| `onText` | `const char*` | max 32 chars | ON label |
| `offText` | `const char*` | max 32 chars | OFF label |
| `label` | `const char*` | max 32 chars | Display label |

### RK_RockerSwitch

Rocker switch variant of SlideSwitch.

```cpp
RK_RockerSwitch rocker(20, 60, 15);
```

Same fields as SlideSwitch.

### RK_MultipleButton

Segmented button group. Selects one option from a list.

```cpp
RK_MultipleButton multi(20, 60, 15, 80);

// Configure items in setup
multi.rk.itemCount = 3;
multi.rk.items[0].label = "Low";
multi.rk.items[1].label = "Med";
multi.rk.items[2].label = "High";
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `value` | `uint8_t` | 0-7 | Selected item index |
| `variant` | `uint8_t` | 0-2 | `RK_SEGMENTS(0)`, `RK_GRID(1)`, `RK_WHEEL(2)` |
| `itemCount` | `uint8_t` | 0-8 | Number of items |
| `items[n].label` | `const char*` | max 32 chars | Item label |
| `items[n].icon` | `const char*` | max 24 chars | Item icon |

### RK_MultipleSelect

Multi-select checkbox group. Value is a bitmask.

```cpp
RK_MultipleSelect multi(20, 60, 15, 80);
multi.rk.itemCount = 4;
multi.rk.items[0].label = "Red";
multi.rk.items[1].label = "Green";
multi.rk.items[2].label = "Blue";
multi.rk.items[3].label = "White";
```

`rk.value` is a bitmask: bit 0 = item 0 selected, bit 1 = item 1, etc.

## Output Widgets

### RK_LED

LED indicator with color, shape, and animation.

```cpp
RK_LED led(115, 29, 28);
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `state` | `bool` | true/false | LED on/off |
| `color` | `uint32_t` | 0xRRGGBB | LED color |
| `ledState` | `uint8_t` | 0-3 | Animation mode |
| `shape` | `uint8_t` | 0-3 | LED shape |
| `timing` | `uint16_t` | ms | Blink/breathe period |
| `label` | `const char*` | max 32 chars | Display label |

**Color constants**:
```cpp
RK_OFF      // 0x000000
RK_RED      // 0xFF0000
RK_GREEN    // 0x00FF00
RK_BLUE     // 0x0000FF
RK_YELLOW   // 0xFFFF00
```

**LED state constants**:
```cpp
RK_LED_STATE_OFF     // 0 - Off
RK_LED_STATE_ON      // 1 - Solid on
RK_LED_STATE_BLINK   // 2 - Blinking
RK_LED_STATE_BREATHE // 3 - Breathing effect
```

**Shape constants**:
```cpp
RK_LED_SHAPE_CIRCLE  // 0
RK_LED_SHAPE_SQUARE  // 1
RK_LED_SHAPE_DIAMOND // 2
RK_LED_SHAPE_STAR    // 3
```

### RK_Text

Text display widget. Write content from firmware.

```cpp
RK_Text tempDisplay(20, 20, 10, 60);
```

| rk Field | Type | Range | Description |
|----------|------|-------|-------------|
| `content` | `const char*` | max 32 chars | Text content to display |
| `label` | `const char*` | max 32 chars | Display label |

```cpp
// Update text in loop
char buf[16];
snprintf(buf, sizeof(buf), "%.1f C", readTemperature());
tempDisplay.rk.content = buf;
```

### RK_Serial / RK_SerialMonitor

Text widget that also implements Arduino `Print`. Can write to it like Serial.

```cpp
RK_Serial console(20, 20, 10, 100);

// Use like Serial:
console.println("Hello from device");
console.printf("Value: %d\n", sensorValue);
```

## Bidirectional Widgets

These widgets can receive state from the app AND send state from firmware:

```cpp
// App sets state, firmware reads it
if (toggle.rk.state) { /* ... */ }

// Firmware sets state, app displays it
toggle.rk.state = !toggle.rk.state;
```

## Telemetry Widgets

Telemetry widgets are NOT rendered on the control canvas. They appear in the active link card in the Flutter app.

```cpp
RK_Telemetry temperature("temperature");
RK_Telemetry battery("battery");

// Configure in setup
temperature.rk.icon = "thermometer";
temperature.rk.unit = "C";
battery.rk.icon = "battery";
battery.rk.unit = "%";

// Update in loop
char buf[16];
snprintf(buf, sizeof(buf), "%.1f", readTemp());
temperature.rk.content = buf;

snprintf(buf, sizeof(buf), "%d", batteryPercent());
battery.rk.content = buf;
```

## Position and Layout

All positioned widgets use a virtual coordinate system (0-200 for x/y, 0-200 for height/width):

```cpp
RK_PushButton btn(20, 60, 20);           // x=20, y=60, height=20
RK_Slider slider(20, 20, 15, 80);       // x=20, y=20, height=15, width=80
```

- `x`, `y`: Top-left position
- `height`: Widget height (or diameter for round widgets)
- `width`: Widget width (0 = auto/aspect ratio)
- `rotation`: Rotation in degrees (-180 to +180)

## Style Constants

Apply visual styles to widgets:

```cpp
myButton.rk.style = RK_PRIMARY;   // 0 - Default
myButton.rk.style = RK_DIM;       // 1 - Subdued
myButton.rk.style = RK_SUCCESS;   // 2 - Green tint
myButton.rk.style = RK_WARNING;   // 3 - Yellow tint
myButton.rk.style = RK_DANGER;    // 4 - Red tint
```

## String Length Limits

| Field | Max Length |
|-------|-----------|
| `label` | 32 chars |
| `icon` | 24 chars |
| `onText` / `offText` | 32 chars |
| `content` (Text/Serial) | 32 chars |
| Widget name (identifier) | 32 chars |
| `items[].label` | 32 chars |
| `items[].icon` | 24 chars |

## Common Patterns

### Toggle Output Based on Input

```cpp
RK_ToggleButton powerBtn(20, 60, 20);
RK_LED powerLed(115, 29, 28);

void loop() {
  RadioKit.update();
  powerLed.rk.state = powerBtn.rk.state;
  digitalWrite(RELAY_PIN, powerBtn.rk.state ? HIGH : LOW);
}
```

### Map Slider to Servo

```cpp
RK_Slider servoSlider(20, 20, 15, 80);
Servo myServo;

void setup() {
  myServo.attach(SERVO_PIN);
}

void loop() {
  RadioKit.update();
  int angle = map(servoSlider.rk.value, -100, 100, 0, 180);
  myServo.write(angle);
}
```

### Map Joystick to Motor Speed

```cpp
RK_Joystick joy(20, 20, 40);

void loop() {
  RadioKit.update();
  int speed = map(joy.rk.yvalue, -100, 100, -255, 255);
  if (speed > 0) {
    analogWrite(MOTOR_FWD, speed);
    analogWrite(MOTOR_REV, 0);
  } else {
    analogWrite(MOTOR_FWD, 0);
    analogWrite(MOTOR_REV, -speed);
  }
}
```

### MultipleButton Mode Selector

```cpp
RK_MultipleButton modeBtn(20, 60, 15, 80);

void setup() {
  modeBtn.rk.itemCount = 3;
  modeBtn.rk.items[0].label = "Auto";
  modeBtn.rk.items[1].label = "Manual";
  modeBtn.rk.items[2].label = "Sleep";
}

void loop() {
  RadioKit.update();
  switch (modeBtn.rk.value) {
    case 0: runAutoMode(); break;
    case 1: runManualMode(); break;
    case 2: enterSleep(); break;
  }
}
```
