# RadioKit Library - Widgets Reference


## Table of Contents

1. [Widget Composition (Specific Props)](#1-widget-composition-specific-props)
2. [Widget Class Reference](#2-widget-class-reference)
   - [PushButton & ToggleButton](#pushbutton--togglebutton)
   - [MultipleButton / MultipleSelect](#multiplebutton--multipleselect)
   - [SlideSwitch](#slideswitch)
   - [Slider](#slider)
   - [Knob](#knob)
   - [Joystick](#joystick)
   - [LED](#led)
   - [Text](#text)
3. [Constants & Enums](#3-constants--enums)

---

## 1. Widget Composition (Specific Props)

In v3.0, each widget uses its own **Tailored Struct**. Every widget provides the same core fields (`x`, `y`, `height`, `width`, `rotation`), but only allocates memory for features it actually uses.

### Hybrid Access Model

Every widget provides two ways to access its data:

#### A. The Method Interface (Read/Write)

Best for standard control logic. Clean, type-safe, and self-documenting.

```cpp
if (btn.isPressed()) { ... }     // Checking a button state
int8_t val = sld.get();          // Reading slider position
```

#### B. The Props Interface (Deep Access)

Best for dynamic UI changes. Since `props` is public, you can modify any part of the widget's metadata at runtime.

```cpp
slider.props.label = "Volume";   // Changing a label dynamically
slider.props.value = 50;         // Direct value assignment
```

### Instantiation Pattern

RadioKit uses a specialized pattern that bridges **Data (Props)** and **Logic (Classes)**:

1. **The Struct**: `RK_SliderProps` is a plain data container (POD).
2. **The Class**: `RK_Slider` is the active controller with methods.
3. **The Bridge**: When you instantiate a widget, you pass an **initializer list** `{ ... }`. The compiler implicitly creates the `Props` struct and hands it to the `Class` constructor.

```cpp
// { ... } creates the Props, RK_Slider creates the Controller
RK_Slider speed({ .x=100, .y=60, .height=10, .width=80, .rotation=50 });
```

### Common Variables

All widgets share these positional and dimensional parameters:

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `x`, `y` | `uint8` | Center position in virtual canvas (0–200). | 100, 100 |
| `height` | `uint8` | Physical height in virtual units (0–100). | 10 |
| `width` | `uint8` | Physical width in virtual units (0–200). | 0 (Auto) |
| `rotation` | `int16` | Rotation in degrees (clockwise). | 0 |
| `icon` | `const char*` | Icon name from skin (e.g., "wifi", "power"). | `nullptr` |
| `label` | `const char*` | Text label above/beside widget. | `nullptr` |
| `active` | `bool` | Whether the widget is actively being manipulated in the app. | `false` |
| `state` / `value` | `bool`/`float` | Primary state or value of the widget. | varies |

### Layout Calculation

The final physical size on screen is defined by explicit **Height** and **Width** values:

1. **Height**: Directly sets the vertical span of the widget in the virtual 200x100 canvas.
2. **Width**: Sets the horizontal span. 
   - If set to `0` (default for most widgets), the widget uses its internal **Default Aspect Ratio** based on its current `height`.
   - If set to a non-zero value, it overrides the aspect ratio and sets the width directly.
   - **Fixed Aspect Widgets**: Some widgets (like Buttons, Knobs, Joysticks) enforce a fixed aspect ratio. For these widgets, the `width` parameter is ignored even if set, and the width is always calculated from the `height`.

> **Tip:** Use `height` as your primary sizing handle. Only set `width` for widgets where you need to stretch the content (like Sliders or Text boxes).

---

## 2. Widget Class Reference

### PushButton & ToggleButton

The primary binary input widgets.

- **PushButton**: Momentary interaction (returns `true` only while held).
- **ToggleButton**: Latched interaction (toggles between `true` and `false` on tap).

**Structure:**

```cpp
struct RK_ButtonProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon  = nullptr;
    const char* onText = nullptr;
    const char* offText = nullptr;
    const char* label = nullptr;
    bool        active = false;
    bool        state = false;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `isPressed()` | `props.state == true` | Returns `true` if actively pressed (PushButton only). |
| `clicked()` | — | Returns `true` only once per press/release cycle. |
| `get()` | `props.state == true` | Returns `true` if active/toggled (ToggleButton). |
| `set(bool)` | `props.state = val;` | Force update the app-side state. |
| `setIcon(char*)` | `props.icon = val;` | Updates icon (e.g. `"power"`, `"wifi"`). |

**Examples:**

```cpp
// A momentary fire button with an icon
RK_PushButton fire({
    .x = 20, .y = 50,
    .height = 20,
    .width = 0,
    .rotation = 0,
    .icon = "flame",
    .label = "FIRE"
});

// A master power toggle
RK_ToggleButton power({
    .x = 20, .y = 80,
    .height = 20,
    .width = 0,
    .rotation = 0,
    .icon = "power",
    .onText = "ON",
    .offText = "OFF",
    .label = "Power"
});

// Usage in loop()
void loop() {
    RadioKit.update();
    
    if (fire.isPressed()) {
        // Activate while held
        triggerFire();
    }
    
    if (power.get()) {
        // Power is ON
        enableSystems();
    }

    if (fire.clicked()) {
        // Run once when fire button is first pressed
        playFireSound();
    }
}
```

---
### MultipleButton / MultipleSelect

Selection groups (Radio or Checkbox). State is an **8-bit Bitmask** (max 8 items).

> **Skin folders**: `multiple_button/` for button style, `multiple_select/` for select/checkbox style. Assets reside in the respective directories of a skin pack.

**Widget Structure:**

```cpp
struct RK_MultipleProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    uint8_t     variant = 0;   // 0=MultipleButton (radio), 1=MultipleSelect (checkbox)
    std::initializer_list<RK_Item> items = {};
    const char* label = nullptr;
    bool        active = false;
    uint8_t     value = 0;     // Bitmask (bit 0 = item 0, bit 1 = item 1, etc.)
};
```

**Item Structure:**

```cpp
struct RK_Item {
    const char* label = nullptr; // Display text
    const char* icon  = nullptr; // Optional icon name
    uint8_t     pos   = 255;     // Fixed bitmask position (0-7). 255 = auto-assign.
};
```

> **Note:** These widgets use a **Fixed 8-Slot Memory Pool** managed by the class. The `initializer_list` in the struct passes your initial items into this pre-allocated storage (max 8 items).

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.value` | Returns current bitmask (`uint8_t`). |
| `get(index)` | `(props.value & (1 << index))` | Returns `true` if index is active. |
| `active()` | `props.active` | Returns active state. |
| `clear()` | — | Removes all items from the pool. |
| `add(RK_Item)` | — | Adds an item to the pool (Max 8). |
| `remove(index)` | — | Removes an item by pool index (0-7). |

**Example:**

```cpp
RK_MultipleSelect toolbar({
    .x = 100, .y = 20,
    .height = 10,
    .width = 0,
    .rotation = 0,
    .items = {
        { .label = "WiFi",   .icon = "wifi",   .pos = 0 },
        { .label = "BT",     .icon = "bluetooth", .pos = 1 },
        { .label = "GPS",    .icon = "satellite", .pos = 2 }
    },
    .label = "Systems",
    .active = true
});

void loop() {
    RadioKit.update();
    
    uint8_t mask = toolbar.get();
    
    if (toolbar.get(0)) {  // WiFi selected (bit 0)
        enableWiFi();
    }
    if (toolbar.get(1)) {  // BT selected (bit 1)
        enableBluetooth();
    }
}
```

---

### SlideSwitch

slide switch for binary on/off control.

**Structure:**

```cpp
struct RK_SlideSwitchProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon  = nullptr;
    uint8_t     variant = 0;     // 0=Slide Switch (default), 1=Rocker Switch
    const char* onText = nullptr;
    const char* offText = nullptr;
    const char* label = nullptr;
    bool        active = false;
    bool        state = false;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.state == true` | Returns `true` if active. |
| `set(bool)` | `props.state = val;` | Force update the app-side state. |
| `setIcon(char*)` | `props.icon = val;` | Updates icon. |

**Example:**

```cpp
RK_SlideSwitch headlights({
    .x = 50, .y = 60,
    .height = 15,
    .width = 0,
    .rotation = 0,
    .icon = "sun",
    .onText = "ON",
    .offText = "OFF",
    .label = "Headlights",
    .state = false
});

void loop() {
    RadioKit.update();
    digitalWrite(LED_PIN, headlights.get() ? HIGH : LOW);
}
```

---

### Slider

Linear analog input control (−100 to +100).

RadioKit v1.6+ uses a **Spring Simulation Engine** for the slider thumb. The skin definition (`config.json`) determines the aesthetic character (damping, stiffness) of the return animation.

The `centering` field determines the spring behavior of the slider (see [Spring Modes](setup.md#3-spring-modes)).

**Structure:**

```cpp
struct RK_SliderProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height   = 10;
    uint8_t     width    = 0;
    int16_t     rotation = 0;
    const char* icon     = nullptr;
    uint8_t     centering = RK_SPRING_NONE; // Spring behaviour (see Setup)
    uint8_t     variant = 0;     // 0=Slider, 1=Gas Pedal
    const char* label    = nullptr;
    bool        active = false;
    int8_t      value     = 0;      // -100 to +100
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.value` | Returns position (−100 to +100). |
| `set(int8_t)` | `props.value = val;` | Force update app position (−100..+100). |
| `centering()`| `props.centering`| Returns the spring mode. |

**Examples:**

```cpp
// Continuous horizontal slider, full range
RK_Slider throttle({
    .x = 50, .y = 40,
    .height = 10,
    .width = 80,   // Explicit width
    .rotation = 0,
    .label = "Throttle",
    .centering = RK_SPRING_NONE,
    .value = 0
});

// Spring-returns to minimum (Gas Pedal)
RK_GasPedal gas({
    .x = 80, .y = 40,
    .height = 10,
    .width = 0,
    .rotation = 0,
    .label = "Gas",
    .centering = RK_SPRING_LEFT  // Springs to -100 on release
});

void loop() {
    RadioKit.update();
    int8_t gasVal = gas.get();  // -100 to +100
    setMotorSpeed(map(gasVal, -100, 100, 0, 255));
}
```

---

### Knob

Rotary analog input control (−100 to +100). Identical wire format to `RK_Slider` but rendered as a 270° circular arc knob with a vertical-drag gesture.

Like the Slider, the Knob utilizes the **Spring Simulation Engine** for consistent, premium haptic response when returning to center.

**Structure:**

```cpp
struct RK_KnobProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height   = 10;
    uint8_t     width    = 0;
    int16_t     rotation = 0;
    const char* icon     = nullptr; // Shown on knob face
    int16_t     startAngle = -135; // Start angle in degrees
    int16_t     endAngle   = 135;  // End angle in degrees
    uint8_t     centering = RK_SPRING_NONE;
    const char* label    = nullptr;
    bool        active = false;
    int8_t      value     = 0; // -100 to +100
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `get()` | `props.value` | Returns position (−100 to +100). |
| `set(int8_t)` | `props.value = val;` | Force update app position (−100..+100). |
| `centering()`| `props.centering`| Returns the spring mode. |

**Examples:**

```cpp
RK_Knob pan({
    .x = 100, .y = 60,
    .height = 20,
    .width = 0,
    .rotation = 0,
    .centering = RK_SPRING_CENTER,
    .label = "Pan"
});

// Volume knob (continuous, 12 o'clock = 0)
RK_Knob vol({
    .x = 140, .y = 40,
    .height = 10,
    .width = 0,
    .rotation = 0,
    .icon = "volume-2",
    .label = "Vol"
});

void loop() {
    RadioKit.update();
    int8_t panPos = pan.get();
    setPanPosition(panPos);
}
```

---

### Joystick

2-axis analog controller (−100 to +100). 

**Structure:**

```cpp
struct RK_JoystickProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon = nullptr;
    bool        enabled = true;
    uint8_t     centering = RK_SPRING_CENTER; // See Spring Modes in Setup
    const char* label = nullptr;
    bool        active = false;
    int8_t      xvalue = 0;   // -100 to +100
    int8_t      yvalue = 0;   // -100 to +100
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `getX()` | `props.xvalue` | Returns X-axis (−100 to +100). |
| `getY()` | `props.yvalue` | Returns Y-axis (−100 to +100). |

**Joystick Spring Modes (`centering`):**

| Constant | Name | Behavior |
|----------|------|----------|
| `RK_SPRING_NONE` | **No Spring** | Both axes stay where released. |
| `RK_SPRING_CENTER` | **Full Spring** | Both axes spring to center (Default). |
| `RK_SPRING_TOP` | **Throttle (Top)** | Y-axis springs to −100 on release. |
| `RK_SPRING_BOTTOM`| **Throttle (Bottom)**| Y-axis springs to +100 on release. |
| `RK_SPRING_LEFT` | **Horizontal Only** | X-axis springs to −100 on release. |
| `RK_SPRING_RIGHT` | **Horizontal Only** | X-axis springs to +100 on release. |

**Example:**

```cpp
RK_Joystick drive({
    .x = 180, .y = 50,
    .height = 20,
    .width = 0,
    .rotation = 90,   // Rotate for vertical layout
    .centering = RK_SPRING_NONE, // No centering (tank-style)
    .label = "Drive"
});

void loop() {
    RadioKit.update();
    
    int8_t x = drive.getX();  // Left/Right
    int8_t y = drive.getY();  // Forward/Back
    
    // Differential drive
    int16_t left  = y + x;
    int16_t right = y - x;
    
    setMotorSpeeds(left, right);
}
```

---


### LED

Visual status indicator (Arduino → App). 

> **Skin folder**: `led/` – assets for the LED widget live in this directory of a skin pack.

**Structure:**

```cpp
struct RK_LEDProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width = 0;
    int16_t     rotation = 0;
    const char* icon  = nullptr;
    const char* label = nullptr;
    bool        active = false;
    bool        state = false;
    uint8_t     red = 255, green = 0, blue = 0;
    uint8_t     opacity = 255;
};
```

**Class Interface:**

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `on()` | `props.state = true;` | Turns LED ON. |
| `off()` | `props.state = false;` | Turns LED OFF. |
| `setIcon(char*)` | `props.icon = val;` | Updates icon (e.g. `"battery"`). |
| `setColor(uint32_t)` | — | Accepts 6-digit (RGB) or 8-digit (RGBA) hex. |
| `setOpacity(uint8_t)` | `props.opacity = val;` | Sets transparency (0-255). |
| `setRed(uint8_t)` | `props.red = val;` | Sets red component (0-255). |
| `setGreen(uint8_t)` | `props.green = val;` | Sets green component (0-255). |
| `setBlue(uint8_t)` | `props.blue = val;` | Sets blue component (0-255). |

**Example:**

```cpp
RK_LED telemetryOK({
    .x = 10, .y = 10,
    .height = 14,
    .width = 0,
    .rotation = 0,
    .icon = "check-circle",
    .label = "Status",
    .state = true,
    .red = 0, .green = 255, .blue = 0 // Green
});

void loop() {
    RadioKit.update();
    
    if (linkEstablished) {
        telemetryOK.on();
        telemetryOK.setColor(0x00FF00); // Green
    } else {
        telemetryOK.off();
    }
}
```

---

### Display

Dynamic text display label (Arduino → App). Read-only.

> **Skin folder**: `display/` – the read-only text widget uses the `display/` directory in a skin pack.

**Structure:**

```cpp
struct RK_DisplayProps {
    uint8_t     x = 0, y = 0;
    uint8_t     height = 10;
    uint8_t     width  = 0;
    int16_t     rotation = 0;
    const char* label = nullptr;
    bool        active = false;
    const char* text = nullptr;
};
```

> [!WARNING]
> Display widgets (`RK_Text`, `RK_Serial`) do not support icons or emojis. Use standard ASCII characters for reliable display.

| Function | Variable (Direct Access) | Description |
|----------|--------------------------|-------------|
| `set(const char*)` | `props.text = val;` | Force set/overwrite the entire text content. |
| `print(...)` | — | Standard Arduino print. Appends to buffer. |
| `println(...)` | — | Standard Arduino print with newline. |
| `clear()` | — | Clears the current text buffer. |

**Example:**

// UI-based text label
RK_Text status({
    .x = 50, .y = 10,
    .height = 10,
    .width = 100,
    .label = "LOG:",
    .text = "System Ready"
});

// Serial Monitor in the app
RK_Serial serialMonitor({
    .x = 100, .y = 80,
    .height = 20,
    .width = 180,
    .label = "Serial Console"
});

void loop() {
    RadioKit.update();
    
    static uint32_t lastUpdate = 0;
    if (millis() - lastUpdate > 1000) {
        lastUpdate = millis();
        
        status.clear();
        status.print("Uptime: ");
        status.print(millis() / 1000);
        status.print("s");

        serialMonitor.println("Log entry at " + String(millis()));
    }
}
```

---

## 3. Constants & Enums

### Architecture (`architecture`)

Detected hardware platform (read-only via `RadioKit.config.architecture`):

| Constant | Value | Platform |
|----------|-------|----------|
| `RK_ARCH_UNKNOWN` | 0 | Unknown/Unsupported |
| `RK_ARCH_ESP32` | 1 | ESP32 (NimBLE) |
| `RK_ARCH_NORDIC` | 2 | nRF52/nRF53 series |
| `RK_ARCH_SAMD` | 3 | SAMD21/SAMD51 (Arduino Zero, MKR) |
| `RK_ARCH_STM32` | 4 | STM32 series (Blue Pill, etc.) |

---

### Slider / Knob / Joystick Centering Modes

Passed as the `centering` field of `RK_SliderProps` / `RK_KnobProps` / `RK_JoystickProps`:

| Constant | Value | Behaviour |
|----------|-------|-----------|
| `RK_SPRING_NONE` | 0 | No spring return — stays where released (default). |
| `RK_SPRING_CENTER` | 1 | Springs to 0 (centre) on release. |
| `RK_SPRING_LEFT` | 2 | Springs to −100 on release (Horizontal). |
| `RK_SPRING_RIGHT` | 3 | Springs to +100 on release (Horizontal). |
| `RK_SPRING_TOP` | 4 | Springs to −100 on release (Vertical). |
| `RK_SPRING_BOTTOM` | 5 | Springs to +100 on release (Vertical). |

Note: Slider and Knob only supports `RK_SPRING_NONE`, `RK_SPRING_CENTER`, `RK_SPRING_LEFT`, and `RK_SPRING_RIGHT`.

---

### UI Theme Identifiers

String-based identifiers for UI skins. Pass to `RadioKit.config.theme`:

| Identifier | Description |
|------------|-------------|
| `"default"` | RAMBROS theme (default) |
| `"neon"` | Cyberpunk neon |
| `"minimal"` | Flat, minimal |
| `"https://..."` | Custom skin pack URL (GitHub raw ZIP) |

**Example:**

```cpp
RadioKit.config.theme = "default";
// or
RadioKit.config.theme = "https://github.com/user/radiokit-skin/archive/main.zip";
```

---

### LED Colours

RGB hex values for `setColor()` or individual component setters:

| Name | Hex | Components (R,G,B) |
|------|-----|--------------------|
| `RK_OFF` | `0x000000` | (0, 0, 0) |
| `RK_RED` | `0xFF0000` | (255, 0, 0) |
| `RK_GREEN` | `0x00FF00` | (0, 255, 0) |
| `RK_BLUE` | `0x0000FF` | (0, 0, 255) |
| `RK_YELLOW` | `0xFFFF00` | (255, 255, 0) |

**Example:**

```cpp
led.setColor(RK_GREEN);
// or
led.setRed(0);
led.setGreen(255);
led.setBlue(0);
```

---

## Best Practices

1. **Always call `update()`** — Never block in `loop()` with `delay()` or long computations.
2. **Declare widgets globally** — They self-register on construction.
3. **Configure before `begin()`** — `config` fields are read-only after `begin()`.
4. **Use `pushUpdate()` for programmatic changes** — Keeps the app in sync when firmware modifies widget state.
5. **Keep `loop()` fast** — Defer heavy work to timers or state machines.
6. **Check `isConnected()`** — Before sending critical updates.
7. **Use `centering`** — For tactile, physical-feeling controls.
8. **Respect the 8-item limit** — `MultipleButton`/`MultipleSelect` have a fixed pool of 8 slots.

## See Also

- **[Getting Started](setup.md)** — Installation and first sketch
- **[UI Layout](ui_layout.md)** — Coordinate system and sizing details
- **[Protocol Specification](protocol.md)** — Binary packet format details
