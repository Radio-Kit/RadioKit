# RadioKit

Open source alternative to RemoteXY, build amazing UIs for your Arduino projects using a simple C++ API and a native Flutter companion app.

## Overview

RadioKit lets you define your UI directly in Arduino code and see it instantly in a smartphone app.

### Features

- **Pure Arduino**: Define your UI in Arduino code with a clean object-oriented API
- **Multiple Transports**: BLE (NimBLE), Serial (USB/UART), Wi-Fi, and Cloud relay
- **Theme Gallery**: Multiple built-in skins (dragon, neon, minimal, cyberpunk, military, retro)
- **Cross-Platform**: Flutter-based client app runs on Android, iOS, Linux, and Web

### Quick Start

```cpp
#include <RadioKitLib.h>

// Widget declarations (minimal constructors)
RK_PushButton    fireBtn(20, 50, 15);    // x, y, height
RK_ToggleButton  power(20, 80, 15);
RK_Slider        slider(100, 60, 12, 80);
RK_Knob          pan(170, 40, 20);
RK_Joystick      joy(160, 70, 20);
RK_LED           status(20, 20, 15);
RK_Text          uptime(20, 10, 10);

// Post-construction configuration (rk fields)
fireBtn.rk.label   = "Fire";
fireBtn.rk.icon    = "flame";
power.rk.label     = "Power";
slider.rk.label    = "Level";
pan.rk.label       = "Pan";
pan.rk.centering   = RK_SPRING_CENTER;
joy.rk.label       = "Stick";
status.rk.label    = "Status";
uptime.rk.label    = "Uptime";

void setup() {
  RadioKit.config.name = "MyRobot";
  RadioKit.config.description = "Robot Controller";
  RadioKit.config.theme = RK_DEFAULT;
  RadioKit.begin();
  RadioKit.startBLE("MyRobot");  // or startSerial(Serial)
}

void loop() {
  RadioKit.update();

  // Read widget states directly from rk fields
  if (power.rk.state) { /* power on */ }
  if (fireBtn.rk.state) { /* fire! (momentary) */ }

  // Read values
  int8_t panVal  = pan.rk.value;
  int8_t joyX    = joy.rk.xvalue;
  int8_t joyY    = joy.rk.yvalue;

  // Set widget state — auto-synced on next RadioKit.update()
  static char uptimeBuf[16];
  snprintf(uptimeBuf, sizeof(uptimeBuf), "%lu s", millis() / 1000);
  uptime.rk.content = uptimeBuf;
}
```

See [Getting Started](arduino/setup.md) for the full API reference.

### Project Structure

```
RadioKit/
├── rk-arduino/                # Arduino library (v2.0)
│   ├── src/                   # Core library headers & implementation
│   │   ├── RadioKitLib.h      # Main entry point
│   │   ├── RadioKitConfig.h   # Configuration & constants
│   │   ├── RadioKitProtocol.h # Protocol v3 definitions
│   │   ├── widgets/           # All widget implementations
│   │   └── connection/        # BLE, Serial, WiFi & Cloud transports
│   └── examples/              # Example sketches
│
├── flutter-widgets/           # Flutter widget library
│   ├── lib/                   # Widget implementations
│   └── example/               # Example app
│
├── radiokit-app/              # Reference Flutter companion app
│   ├── lib/                   # App source
│   └── pubspec.yaml
│
└── docs/                      # Documentation
```

### Documentation

- **[Arduino Library](arduino/setup.md)** — Setup, API reference, and examples
- **[Widgets Reference](arduino/widgets.md)** — Complete widget API
- **[UI Layout](arduino/ui_layout.md)** — Coordinate system and sizing
- **[Protocol Spec](arduino/protocol.md)** — Binary packet format details
- **[Flutter Widgets](flutter-widgets/README.md)** — Flutter widget API

### Development

- **Arduino Library**: See [library.json](https://github.com/rambros3d/RadioKit/blob/main/rk-arduino/library.json) for dependencies
- **Flutter App**: See [pubspec.yaml](https://github.com/rambros3d/RadioKit/blob/main/radiokit-app/pubspec.yaml) for dependencies

### License

MIT — see [LICENSE](../LICENSE) files in each repository.
