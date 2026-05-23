# RadioKit Library - Functions Reference

> This document reflects the **v3.0 Object-Oriented API** using **Tailored Initializers**.

---

## Table of Contents

1. [Setup & Sketch Structure](#1-setup--sketch-structure)
2. [RadioKit (Main Object)](#2-radiokit-main-object)
3. [Widget Classes](#3-widget-classes)
4. [Constants & Enums](#4-constants--enums)

---

## 1. Setup & Sketch Structure

Every RadioKit sketch follows a simple three-part pattern. 

```cpp
#include <RadioKit.h>

// ── 1. Widget declarations (global scope) ────────────────────────────────
// Each widget self-registers on construction

RK_PushButton fireBtn({ .x = 20, .y = 50, .height = 15, .width = 0, .rotation = 0, .icon = "flame", .label = "Fire" });
RK_ToggleButton power({ .x = 20, .y = 80, .height = 15, .width = 0, .rotation = 0, .label = "Power" });
RK_Slider throttle({ .x = 100, .y = 60, .height = 12, .width = 80, .rotation = 0, .label = "Throttle", .value = 0 });
RK_Knob steering({ .x = 170, .y = 40, .height = 20, .width = 0, .rotation = 0, .centering = RK_SPRING_CENTER, .label = "Steer" });
RK_Joystick joy({ .x = 160, .y = 70, .height = 20, .width = 0, .rotation = 0, .label = "Stick" });
RK_LED status({ .x = 20, .y = 20, .height = 15, .width = 0, .rotation = 0, .label = "Status" });
RK_Text uptime({ .x = 20, .y = 10, .height = 10, .width = 0, .rotation = 0, .label = "Uptime" });

// ── 2. setup() ───────────────────────────────────────────────────────────
void setup() {
    RadioKit.config.name = "GP7 Locomotive";
    RadioKit.config.password = "1234";
    RadioKit.config.theme = "retro"; // Controller skin name or GitHub URL
    RadioKit.begin();
    RadioKit.startBLE("Train_01");
}

// ── 3. loop() ────────────────────────────────────────────────────────────
void loop() {
    RadioKit.update();
    
    // Read widget states
    if (fireBtn.isPressed()) { triggerFire(); }
    if (power.get()) { enableSystems(); }
    
    // Update outputs
    int8_t steer = steering.get();
    int8_t throttle = throttle.get();
    
    String statusText;
    statusText = "Speed: " + String(throttle) + "%";
    uptime.set(statusText);
}
```

### Key Points

- **Widgets are declared globally** — They self-register on construction via their initializer list `{ ... }`.
- **`RadioKit.begin()` commits configuration** — Must be called before `startBLE()` or `startSerial()`.
- **`RadioKit.update()` must be called every loop** — Processes incoming packets and manages state. Never block with `delay()`.
- **Initializer lists bridge Props and Classes** — The `{ ... }` syntax creates a `RK_*Props` struct which is passed to the widget constructor.

---

## 2. RadioKit (Main Object)

### `begin()`

Commits and synchronizes configuration. Must be called in `setup()` before starting any transport.

```cpp
void begin();
```

### `config` (Object)

Global settings object. Configure **before** calling `begin()` — fields are read-only after.

#### User Configurable

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `name` | `const char*` | Device/model name. Sent to app on connection. | `"RadioKit Device"` |
| `password` | `const char*` | Optional connection password (empty = none). | `""` |
| `description` | `const char*` | Short overview of device function. | `""` |
| `version` | `const char*` | User-defined firmware version (e.g. `"1.0.4"`). | `"1.0.0"` |
| `type` | `const char*` | Device category (e.g. `"truck"`, `"robot"`). | `""` |
| `theme` | `const char*` | Skin name string (e.g. "dark") or URL. | `"default"` |
| `orientation` | `uint8_t` | `RK_LANDSCAPE` (default) or `RK_PORTRAIT`. | `RK_LANDSCAPE` |
| `width` | `uint8_t` | Canvas width in virtual units (0–200, 0 = auto). | `0` |
| `height` | `uint8_t` | Canvas height in virtual units (0–200, 0 = auto). | `0` |

#### Read-Only (Set by Library)

| Field | Type | Description |
|-------|------|-------------|
| `architecture` | `uint8_t` | Detected hardware platform (`RK_ARCH_ESP32`, etc.). |
| `libversion` | `const char*` | Current RadioKit library version string. |

### `startBLE(const char* deviceName = nullptr)`

Initialises BLE (NimBLE) and starts advertising.

```cpp
void startBLE(const char* deviceName = nullptr);
```

- **`deviceName`** — Overrides `config.name` for BLE advertising. If `nullptr`, uses `config.name`.
- Uses NimBLE on ESP32, Nordic SoftDevice on nRF52.
- Service UUID: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic UUID: `0000FFE1-0000-1000-8000-00805F9B34FB`

### `startSerial(Stream& stream)`

Attaches to a pre-initialised serial stream (USB CDC, UART, WebSerial).

```cpp
void startSerial(Stream& stream);
```

- **`stream`** — Reference to a `Stream` object (e.g., `Serial`, `Serial1`, `SerialUSB`).
- The sketch **must** call `stream.begin(baud)` before this.
- Baud rate is unrestricted; 1000000 recommended.
- Supports WebSerial (Chrome/Edge) for browser-based control.

### `update()`

Processes incoming data, manages connections, and handles reliability.

```cpp
void update();
```

- **Must be called every loop iteration** — Do not block with `delay()`.
- Handles packet parsing, ACKs, retransmissions, and state sync.
- Typical call time: < 1ms when idle.

### `pushUpdate(uint8_t widgetId)`

Enqueues a reliable `VAR_UPDATE` for the specified widget. Use when firmware changes a widget's state programmatically.

```cpp
void pushUpdate(uint8_t widgetId);
```

- **`widgetId`** — Index of the widget (0-based, sequential order of declaration).
- The library tracks pending updates and retries on failure (200ms interval, 5 max retries).
- Example: `RadioKit.pushUpdate(slider.widgetId);`

### `pushMetaUpdate(uint8_t widgetId)`

Enqueues a reliable `META_UPDATE` for widget metadata (label, icon, etc.).

```cpp
void pushMetaUpdate(uint8_t widgetId);
```

### `isConnected()` / `getRssi()`

Status queries.

```cpp
bool isConnected() const;  // Returns true if transport is connected
int8_t getRssi();          // Returns RSSI in dBm (127 if N/A)
```

---

## 3. Widget Classes

RadioKit v3.0 uses a **Props + Class** pattern. Each widget has:

1. A **Props struct** (e.g., `RK_SliderProps`) — Plain data container with fields.
2. A **Class** (e.g., `RK_Slider`) — Active controller with methods.

Instantiation uses an initializer list that implicitly creates the Props:

```cpp
RK_Slider slider({ .x = 100, .y = 60, .height = 12, .width = 80, .rotation = 0, .label = "Speed", .value = 0 });
// { ... } creates RK_SliderProps, RK_Slider constructor consumes it
```

### Available Widgets

| Widget | Class | Props Struct | Direction | Description |
|--------|-------|--------------|-----------|-------------|
| PushButton | `RK_PushButton` | `RK_ButtonProps` | Input | Momentary (true while held) |
| ToggleButton | `RK_ToggleButton` | `RK_ButtonProps` | Input | Latching on/off switch |
| MultipleButton | `RK_MultipleButton` | `RK_MultipleProps` | Input | Radio-style group (bitmask) |
| MultipleSelect | `RK_MultipleSelect` | `RK_MultipleProps` | Input | Checkbox group (bitmask) |
| SlideSwitch | `RK_SlideSwitch` | `RK_SlideSwitchProps` | Input | iOS-style slide toggle |
| Slider | `RK_Slider` | `RK_SliderProps` | Input | Linear -100..+100 |
| Knob | `RK_Knob` | `RK_KnobProps` | Input | Rotary -100..+100 |
| Joystick | `RK_Joystick` | `RK_JoystickProps` | Input | 2-axis (-100..+100 each) |
| LED | `RK_LED` | `RK_LEDProps` | Output | Colour indicator |
| Text | `RK_Text` | `RK_DisplayProps` | Output | Read-only text display |
| Serial | `RK_Serial` | `RK_DisplayProps` | Output | Serial Monitor in app |

### Common Fields (all widgets)

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `x`, `y` | `uint8_t` | Center position (0–200) | 100, 100 |
| `height` | `uint8_t` | Physical height (0–200) | 15 |
| `width` | `uint8_t` | Physical width (0 = auto) | 0 |
| `rotation` | `int16_t` | Rotation in degrees (clockwise) | 0 |
| `icon` | `const char*` | Icon name from skin | `nullptr` |
| `label` | `const char*` | Text label above widget | `nullptr` |

### Method Interface (Read/Write)

Best for standard control logic:

```cpp
// Buttons
bool isPressed();  // PushButton: true while held
bool clicked();    // PushButton: true once per click
bool get();        // ToggleButton/Switch: current state
void set(bool);    // Force update app-side state

// Slider / Knob
int8_t get();      // Returns -100 to +100
void set(int8_t);  // Force update app position

// Joystick
int8_t getX();     // X axis (-100 to +100)
int8_t getY();     // Y axis (-100 to +100)

// Multiple
uint8_t get();     // Returns bitmask
bool get(uint8_t i); // Returns true if bit i is set
void clear();      // Remove all items from pool
void add(RK_Item); // Add item to pool (max 8)
void remove(uint8_t index); // Remove item from pool index
void setIcon(const char*);  // Update group icon

// LED
void on();
void off();
void setColor(uint32_t rgba); // e.g. 0x00FF00
void setRed/Green/Blue(uint8_t);
void setOpacity(uint8_t);

// Display / Serial
void set(const char*);
void set(const String&);
const char* get();
void print(...);
void println(...);
void clear();
```

### Props Interface (Deep Access)

Best for dynamic UI changes:

```cpp
slider.props.label = "Volume";   // Change label
slider.props.value = 50;         // Direct value assignment
led.props.red = 255;             // Modify colour
```

---

## 4. Constants & Enums

### Architecture (`config.architecture`)

Detected hardware platform (read-only):

| Constant | Value | Platform |
|----------|-------|----------|
| `RK_ARCH_UNKNOWN` | 0 | Unknown/Unsupported |
| `RK_ARCH_ESP32` | 1 | ESP32 (NimBLE) |
| `RK_ARCH_NORDIC` | 2 | nRF52/nRF53 series |
| `RK_ARCH_SAMD` | 3 | SAMD21/SAMD51 (Zero, MKR) |
| `RK_ARCH_STM32` | 4 | STM32 series |

### UI Skins (`config.theme`)

Theme is passed as a string. Available built-in themes:

| Theme Name | Description |
|------------|-------------|
| `"default"` | Light blue, modern (default) |
| `"dark"` | Dark mode |
| `"retro"` | CRT green phosphor |
| `"futuristic"` | Futuristic blue |
| `"military"` | Military green |
| `"cyberpunk"` | Cyberpunk neon |
| `"neon"` | Neon glow |
| `"minimal"` | Flat, minimal |
| `"https://..."` | Custom skin from GitHub ZIP |

### Slider / Knob / Joystick Spring Modes

Passed as `centering` field:

| Constant | Value | Behaviour |
|----------|-------|-----------|
| `RK_SPRING_NONE` | 0 | No spring return (stays where released) |
| `RK_SPRING_CENTER` | 1 | Springs to 0 (centre) on release |
| `RK_SPRING_TOP` | 2 | Springs to −100 on release (Vertical) |
| `RK_SPRING_BOTTOM` | 3 | Springs to +100 on release (Vertical) |
| `RK_SPRING_LEFT` | 4 | Springs to −100 on release (Horizontal) |
| `RK_SPRING_RIGHT` | 5 | Springs to +100 on release (Horizontal) |

When using `RK_SliderProps` or `RK_KnobProps`, set the `centering` field directly. This value is packed into the `VARIANT` byte in the protocol.

### LED Colours

RGB hex values for `setColor()`:

| Constant | Hex | Components |
|----------|-----|------------|
| `RK_OFF` | `0x000000` | (0, 0, 0) |
| `RK_RED` | `0xFF0000` | (255, 0, 0) |
| `RK_GREEN` | `0x00FF00` | (0, 255, 0) |
| `RK_BLUE` | `0x0000FF` | (0, 0, 255) |
| `RK_YELLOW` | `0xFFFF00` | (255, 255, 0) |

### Protocol Version

```cpp
#define RK_PROTOCOL_VERSION 0x03  // Protocol v3
#define RK_LIB_VERSION "2.0.0"    // Library version
```

---

## Best Practices

1. **Always call `update()`** — Never block in `loop()` with `delay()` or long computations.
2. **Declare widgets globally** — They self-register on construction.
3. **Configure before `begin()`** — `config` fields are read-only after `begin()`.
4. **Use `pushUpdate()` for programmatic changes** — Keeps the app in sync when firmware modifies widget state.
5. **Keep `loop()` fast** — Defer heavy work to timers or state machines.
6. **Check `isConnected()`** — Before sending critical updates.
7. **Use the Props interface for runtime changes** — Modify `widget.props.label`, `widget.props.value`, etc., then call `pushMetaUpdate()` or `pushUpdate()`.

## See Also

- **[Widgets Reference](widgets.md)** — Complete widget API details
- **[UI Layout](ui_layout.md)** — Coordinate system and sizing details
- **[Protocol Specification](protocol.md)** — Binary packet format details