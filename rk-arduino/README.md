# RadioKit Arduino Library

RadioKit Arduino library (v2.0) — define your UI in C++ and control it from the RadioKit companion app over BLE, Serial, WiFi, or Cloud relay.

## Structure

```
rk-arduino/
├── src/
│   ├── RadioKitLib.h           # Main user-facing header — include this in your sketch
│   ├── RadioKitConfig.h        # Library constants, enums, type IDs, limits
│   ├── RadioKitProtocol.h/cpp  # Protocol v3 packet definitions and helpers
│   ├── RadioKitWidgets.h       # Convenience header — includes all widget classes
│   ├── RadioKit.cpp            # Main RadioKitClass implementation
│   ├── widgets/
│   │   ├── Widget.h            # Base class for all widgets
│   │   ├── Button.h            # RK_PushButton, RK_ToggleButton
│   │   ├── SlideSwitch.h       # RK_SlideSwitch, RK_RockerSwitch
│   │   ├── Slider.h            # RK_Slider, RK_GasPedal
│   │   ├── Knob.h              # RKKnob, RK_SteeringWheel
│   │   ├── Joystick.h          # RK_Joystick (2-axis)
│   │   ├── LED.h               # RK_LED (RGB output indicator)
│   │   ├── Text.h              # RK_Text (read-only text display)
│   │   ├── Multiple.h          # RK_MultipleButton, RK_MultipleSelect
│   │   └── Telemetry.h         # RK_Telemetry (display-only metrics)
│   └── connection/
│       ├── RadioKitTransport.h  # Transport interface (base class)
│       ├── RadioKitBLE.h        # BLE transport (NimBLE)
│       ├── RadioKitSerial.h     # Serial transport (USB/UART)
│       ├── RadioKitWiFi.h       # WiFi transport (WebSocket server)
│       ├── RadioKitCloud.h      # Cloud relay transport (WebSocket client)
│       ├── RadioKitFS.h         # Bulk filesystem protocol (LittleFS)
│       ├── RadioKitFsHandlers.h # Default filesystem handlers
│       ├── RadioKitSettings.h   # Settings protocol (0xDD)
│       ├── RadioKitNVS.h        # NVS config persistence
│       └── RadioKitOTA.h        # Over-the-air firmware updates
│
├── examples/
│   ├── SerialTest/              # Full feature demo over USB Serial
│   ├── BasicSwitch/             # Minimal BLE: toggle switch + LED
│   ├── JoystickMotor/           # Joystick controlling a servo
│   ├── SliderServo/             # Slider controlling a servo
│   ├── BLE_RC_Truck/            # RC truck: BLE + dual motor control
│   ├── Filesystem_LED/          # BLE + LittleFS bulk filesystem demo
│   ├── FsCommandTest/           # Filesystem command testing
│   └── WiFiCloudSwitch/         # BLE + WiFi + Cloud relay: multi-transport demo
│
├── library.json                 # PlatformIO library metadata
├── library.properties           # Arduino IDE library metadata
├── keywords.txt                 # Arduino IDE syntax highlighting
└── .clang-format                # C++ formatting rules
```

## Transports

| Transport | Activation | Use case |
|-----------|-----------|----------|
| **BLE** | `RadioKit.startBLE(name)` | Local control via RadioKit app (NimBLE on ESP32) |
| **Serial** | `RadioKit.startSerial(Serial)` | USB/UART communication (1000000 baud recommended) |
| **WiFi** | `RadioKit.startWiFi()` | Local WiFi WebSocket server on port 5555 (requires `-D RADIOKIT_ENABLE_WIFI`) |
| **Cloud** | `RadioKit.startCloud()` | Internet relay via WebSocket (requires WiFi first) |

Multiple transports can run simultaneously. The library broadcasts widget state changes across all active transports automatically.

## Widgets

| Widget | Class | Type | Description |
|--------|-------|------|-------------|
| Push Button | `RK_PushButton` | Input | Momentary (true while held) |
| Toggle Button | `RK_ToggleButton` | Input | Latching on/off |
| Slide Switch | `RK_SlideSwitch` | Input | iOS-style slide toggle |
| Rocker Switch | `RK_RockerSwitch` | Input | Rocker-style on/off |
| Slider | `RK_Slider` | Input | Linear -100..+100 |
| Gas Pedal | `RK_GasPedal` | Input | Slider variant, springs to min |
| Knob | `RK_Knob` | Input | Rotary -100..+100 |
| Steering Wheel | `RK_SteeringWheel` | Input | Knob variant, springs to center |
| Joystick | `RK_Joystick` | Input | 2-axis (-100..+100 each) |
| Multi Button | `RK_MultipleButton` | Input | Radio-style button group |
| Multi Select | `RK_MultipleSelect` | Input | Checkbox-style multi-select |
| LED | `RK_LED` | Output | RGB indicator |
| Text | `RK_Text` | Output | Read-only text display |
| Serial Monitor | `RK_Serial` | Output | Serial console in the app |
| Telemetry | `RK_Telemetry` | Output | Display-only metrics |

## Quick Start

```cpp
#include <RadioKitLib.h>

// ── 1. Declare widgets globally (self-registering) ────────────
RK_PushButton fire({.x=20, .y=50, .height=15, .icon="flame", .label="Fire"});
RK_ToggleButton power({.x=20, .y=80, .height=15, .icon="power", .label="Power"});
RK_Slider throttle({.x=100, .y=60, .height=12, .width=80, .label="Throttle"});
RK_LED status({.x=20, .y=20, .height=15, .label="Status"});

// ── 2. setup() ────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  RadioKit.config.name = "MyRobot";
  RadioKit.config.description = "Robot Controller v2.0";
  RadioKit.config.theme = RK_DEFAULT;

  RadioKit.begin();
  RadioKit.startBLE("MyRobot");   // or startSerial(Serial)
}

// ── 3. loop() ─────────────────────────────────────────────────
void loop() {
  RadioKit.update();

  if (fire.isPressed()) { /* fire while held */ }
  if (fire.clicked())   { /* fire once per press */ }
  if (power.get())      { /* power is ON */ }

  int8_t speed = throttle.get();  // -100 to +100

  // Update output widgets
  status.setColor(power.get() ? RK_GREEN : RK_RED);
}
```

## Build

### PlatformIO

Each example is self-contained with its own `platformio.ini`. Build from the example directory:

```bash
cd rk-arduino/examples/SerialTest
pio run                    # build
pio run -t upload          # flash to board
```

Add the library to your own project:

```ini
lib_deps =
    h2zero/NimBLE-Arduino@^2.1.0
    RadioKit=symlink://../rk-arduino
```

For WiFi/Cloud support, add the build flag:

```ini
build_flags =
    -D RADIOKIT_ENABLE_WIFI
```

### Arduino IDE

1. Download the latest release from [GitHub](https://github.com/rambros3d/RadioKit/releases)
2. Extract the ZIP into `Documents/Arduino/libraries/RadioKit`
3. Restart the Arduino IDE
4. Open `File -> Examples -> RadioKit -> SerialTest`

## Examples

| Example | Transport | Features |
|---------|-----------|----------|
| **SerialTest** | USB Serial | All widgets, full feature demo |
| **BasicSwitch** | BLE | Minimal: toggle switch + LED |
| **JoystickMotor** | BLE | Joystick → servo motor control |
| **SliderServo** | BLE | Slider → servo position control |
| **BLE_RC_Truck** | BLE | RC truck: dual motor, steering |
| **Filesystem_LED** | BLE | LittleFS: browse, read, write files |
| **FsCommandTest** | Serial | FS command validation |
| **WiFiCloudSwitch** | BLE+WiFi+Cloud | Multi-transport with Ed25519 auth |

## Key Config

Set these in `setup()` before calling `RadioKit.begin()`:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `const char*` | `"RadioKit Device"` | Device name displayed in the app |
| `password` | `const char*` | `""` | Connection password (empty = none) |
| `description` | `const char*` | `""` | Device description |
| `version` | `const char*` | `"1.0.0"` | Firmware version string |
| `theme` | `const char*` | `"default"` | UI skin name |
| `orientation` | `uint8_t` | `RK_LANDSCAPE` | `RK_LANDSCAPE` or `RK_PORTRAIT` |
| `sta_ssid` | `const char*` | `""` | WiFi STA SSID (empty = AP mode) |
| `sta_password` | `const char*` | `""` | WiFi STA password |
| `cloud_url` | `const char*` | `""` | Relay server URL |
| `cloud_account` | `const char*` | `""` | Public key hex for Ed25519 auth |

## Documentation

- **[Widgets Reference](https://rambros3d.github.io/RadioKit/arduino/widgets/)** — Complete widget API
- **[UI Layout](https://rambros3d.github.io/RadioKit/arduino/ui-layout/)** — Coordinate system and sizing
- **[Protocol Spec](https://rambros3d.github.io/RadioKit/arduino/protocol/)** — Binary packet format (v3)
- **[Remote Access API](../llm-docs/API.md)** — HTTP REST API for automated testing
- **[Agent Test Manual](../llm-docs/AGENT-TEST.md)** — End-to-end testing guide
