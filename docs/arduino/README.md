# RadioKit Arduino Library

> Control your Arduino projects from a mobile app over BLE or Serial

---

## What is RadioKit?

RadioKit is a powerful, object-oriented Arduino library (v3.0) that bridges your hardware and a highly customizable mobile dashboard. It allows you to build industrial-grade control interfaces using simple C++ structures.

### Key Features

- **Hardware Agnostic**: Supports ESP32 (NimBLE), Nordic nRF52, STM32, and any board with a Hardware Serial port.
- **Tailored Memory Model**: Each widget only consumes the RAM it needs — no dynamic allocation.
- **Zero Configuration**: The UI is defined in your Arduino code; the app dynamically builds the dashboard upon connection.
- **Reliable Communication**: Built-in sequence tracking and retransmission for critical commands (VAR_UPDATE, META_UPDATE).
- **Spring Physics**: High-fidelity spring simulations for sliders, knobs, and joysticks.
- **Multiple Transports**: BLE (NimBLE) and Serial (USB CDC, FTDI, CP210x, CH340).

## Sections

- **[Getting Started](setup.md)**: Install the library and create your first sketch.
- **[Widgets Reference](widgets.md)**: Explore the available input and output controls.
- **[UI & Layout](ui_layout.md)**: Learn how to position and scale your widgets.
- **[Protocol Specification](protocol.md)**: Details on the binary packet format (for advanced users).

## Installation

### PlatformIO (Recommended)

```ini
lib_deps =
    h2zero/NimBLE-Arduino@^2.1.0
    RadioKit=symlink://./arduino-library
```

### Arduino IDE

1. Download the latest release from [GitHub](https://github.com/rambros3d/RadioKit/releases).
2. Extract the ZIP into your `Documents/Arduino/libraries` folder.
3. Restart your Arduino IDE.
4. Try the example in `File -> Examples -> RadioKit -> SerialTest`.

## Quick Start Example

```cpp
#include <RadioKitLib.h>

// ── Widget declarations (global scope) ────────────────────────────────
RK_PushButton fireBtn({.x=20, .y=60, .height=20, .width=0, .rotation=0, .icon="flame", .label="Fire", .active=false});
RK_ToggleButton power({.x=20, .y=80, .height=20, .width=0, .rotation=0, .label="Power", .active=false});
RK_Slider level({.x=100, .y=60, .height=12, .width=100, .rotation=0, .label="Level", .active=false, .value=0});
RK_Knob pan({.x=170, .y=40, .height=25, .width=0, .rotation=0, .icon="knob", .label="Pan", .active=false, .centering=RK_SPRING_CENTER});
RK_Joystick joy({.x=160, .y=70, .height=25, .width=0, .rotation=0, .label="Stick", .active=false});
RK_LED status({.x=20, .y=20, .height=15, .width=0, .rotation=0, .label="Status", .active=false});
RK_Text uptime({.x=20, .y=10, .height=10, .width=0, .rotation=0, .label="Uptime", .active=false});

void setup() {
  Serial.begin(1000000);
  
  RadioKit.config.name = "MyRobot";
  RadioKit.config.description = "Robot Controller v3.0";
  RadioKit.config.theme = "default";
  RadioKit.config.password = "1234";  // optional
  
  RadioKit.begin();
  RadioKit.startSerial(Serial);  // or startBLE("MyRobot")
}

void loop() {
  RadioKit.update();
  
  // ── Read inputs ────────────────────────────────────────────────────
  if (fireBtn.isPressed()) { /* fire! */ }
  if (power.get()) { /* power on */ }
  
  int8_t levelVal = level.get();  // -100 to +100
  int8_t panVal = pan.get();      // -100 to +100
  int8_t joyX = joy.getX();       // -100 to +100
  int8_t joyY = joy.getY();       // -100 to +100
  
  // ── Update outputs ─────────────────────────────────────────────────
  static uint32_t lastSec = 0;
  uint32_t nowSec = millis() / 1000;
  if (nowSec != lastSec) {
    lastSec = nowSec;
    char buf[32];
    snprintf(buf, sizeof(buf), "%lus", (unsigned long)nowSec);
    uptime.set(buf);
  }
  
  // LED colour reflects level
  if (levelVal < 0) {
    status.setColor(RK_RED);
  } else if (levelVal == 0) {
    status.setColor(RK_YELLOW);
  } else {
    status.setColor(RK_GREEN);
  }
}
```

## Architecture (v3.0)

### Object-Oriented Design

- **`RadioKitClass`** — Main controller, manages configuration and transport
- **`RadioKit_Widget`** — Base class for all widgets
- **Widget Classes** — `RK_PushButton`, `RK_ToggleButton`, `RK_Slider`, `RK_Knob`, `RK_Joystick`, `RK_LED`, `RK_Text`, `RK_MultipleButton`, `RK_MultipleSelect`, `RK_SlideSwitch`
- **Props Structs** — Tailored data containers (e.g., `RK_ButtonProps`, `RK_SliderProps`) that minimize RAM usage

### Memory Model

- Fixed-size widget pool (`RADIOKIT_MAX_WIDGETS`, default 32)
- No dynamic allocation after construction
- Each widget type has a baseline height and width
- Height and Width parameters control physical dimensions

### Communication Protocol

- **Service UUID**: `0000FFE0-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID**: `0000FFE1-0000-1000-8000-00805F9B34FB`
- **Packet Format**: `START(0x55) + LENGTH(2 LE) + CMD(1) + PAYLOAD(N) + CRC16(2 LE)`
- **CRC**: CRC-16/CCITT (poly 0x1021, init 0xFFFF)

See [Protocol Specification](protocol.md) for details.

## Supported Hardware

| Platform | BLE | Serial | Notes |
|----------|-----|--------|-------|
| **ESP32** | [X] NimBLE | [X] USB CDC, FTDI | Fully supported |
| **nRF52** | [X] Native | [X] UART | Nordic SDK |
| **STM32** | [-] | [X] UART | Use Serial only |
| **SAMD** | [-] | [X] UART | Use Serial only |

## Examples

- **`SerialTest`** — Full feature demo over USB Serial (LED, buttons, sliders, knobs, joysticks)
- **`BasicSwitch`** — Minimal BLE example (toggle switch + LED)
- **`JoystickMotor`** — Joystick controlling a servo
- **`SliderServo`** — Slider controlling a servo

## API Reference

See [Widgets Reference](widgets.md) for complete documentation of all widget classes, methods, and properties.

## Troubleshooting

### BLE Not Connecting
- Ensure NimBLE-Arduino is installed (v2.1.0+)
- Check that your board supports BLE (ESP32, nRF52)
- Try restarting the app and toggling airplane mode

### Serial Not Working
- Verify Serial.begin() is called before RadioKit.startSerial()
- Check baud rate matches (1000000 recommended)
- On Web Serial, ensure correct port is selected

### Widgets Not Updating
- Call RadioKit.update() in every loop() iteration
- Check connection status with RadioKit.isConnected()
- Verify widget IDs are unique

## License

MIT — see [LICENSE](../LICENSE).
