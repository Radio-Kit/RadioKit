# RadioKit

Open source alternative to RemoteXY — build beautiful UIs for your Arduino projects using a simple C++ API and a native Flutter companion app.

Define your UI directly in Arduino code and see it instantly in the smartphone app over BLE, Serial, WiFi, or the Cloud relay.

---

## Structure

```
RadioKit/
├── rk-arduino/           # Arduino library
│   ├── src/              # Core library headers & implementation
│   │   ├── widgets/      # All widget implementations
│   │   └── connection/   # BLE, Serial, WiFi, Cloud transports
│   └── examples/         # Example sketches (PlatformIO)
│
├── flutter-widgets/      # Flutter widget library
│   ├── lib/              # Widget implementations
│   └── example/          # Example Flutter app
│
├── radiokit-app/          # Reference Flutter companion app
│   ├── lib/              # App source
│   │   ├── screens/      # UI screens
│   │   ├── services/     # BLE, Serial, WebSocket, cloud services
│   │   ├── providers/    # State management
│   │   └── widgets/      # Reusable widgets
│   └── assets/demos/     # Demo JSON configs
│
├── radiokit-relay/        # Rust WebSocket relay server
│   ├── src/              # Relay, session, rate limiter
│   └── Dockerfile
│
├── docs/                  # Docsify documentation site
├── llm-docs/              # AI agent reference docs
├── flatpak/               # Flatpak packaging
└── .github/workflows/     # CI configuration
```

---

## Quick Start

### 1. Install the Arduino library

**PlatformIO** (recommended):
```ini
lib_deps =
    h2zero/NimBLE-Arduino@^2.1.0
    RadioKit=symlink://./rk-arduino
```

**Arduino IDE**: Download from [GitHub Releases](https://github.com/rambros3d/RadioKit/releases) and extract into `Documents/Arduino/libraries`.

### 2. Write your sketch

```cpp
#include <RadioKitLib.h>

RK_PushButton fire({.x=20, .y=50, .height=15, .icon="flame", .label="Fire"});
RK_LED status({.x=20, .y=20, .height=15, .label="Status"});

void setup() {
  RadioKit.config.name = "MyRobot";
  RadioKit.begin();
  RadioKit.startBLE("MyRobot");
}

void loop() {
  RadioKit.update();
  if (fire.isPressed()) { /* fire! */ }
}
```

### 3. Connect with the companion app

```bash
cd radiokit-app
flutter run -d android   # or ios / linux / web
```

Scan for nearby devices and tap your board. The UI appears automatically.

---

## Features

- **Pure Arduino API** — Define UI in C++ with a clean object-oriented interface
- **Multiple Transports** — BLE (NimBLE), Serial (USB/UART), WiFi (WebSocket), Cloud relay
- **Ed25519 Cloud Auth** — Secure challenge-response authentication via Rust relay
- **Rich Widget Set** — Buttons, sliders, knobs, joysticks, LEDs, text display, serial monitor, multi-select
- **Theme System** — Multiple built-in skins with SVG-based rendering + spring physics
- **Filesystem Explorer** — Browse, upload, download files on the MCU via BLE/Serial
- **OTA Updates** — Over-the-air firmware updates from the app
- **Remote Access API** — HTTP REST API for test automation (port 7007)
- **Cross-Platform** — Android, iOS, Linux, Web

---

## Documentation

| Resource | Description |
|----------|-------------|
| [Arduino Setup](docs/arduino/setup.md) | Install and write your first sketch |
| [Widgets Reference](docs/arduino/widgets.md) | Complete widget API |
| [UI Layout](docs/arduino/ui_layout.md) | Coordinate system and sizing |
| [Protocol Spec](docs/arduino/protocol.md) | Binary packet format |
| [Flutter Widgets](docs/flutter-widgets/README.md) | Flutter widget library API |
| [Remote Access API](llm-docs/API.md) | HTTP API for test automation |
| [Agent Test Manual](llm-docs/AGENT-TEST.md) | End-to-end testing guide |
| [AI Agent Guidelines](AGENTS.md) | Conventions for AI coding agents |

---

## License

MIT — see [LICENSE](LICENSE).