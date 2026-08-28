# RadioKit
The Open source alternative to RemoteXY

Build beautiful UIs for your Arduino projects and control it with RadioKit app over BLE, Serial, WiFi, or the Cloud relay.

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
├── website/               # Astro/Starlight documentation site
├── flatpak/               # Flatpak packaging
└── .github/workflows/     # CI configuration
```

---

## Documentation

| Resource | Description |
|----------|-------------|
| [Arduino Setup](https://rambros3d.github.io/RadioKit/arduino/setup/) | Install and write your first sketch |
| [Widgets Reference](https://rambros3d.github.io/RadioKit/arduino/widgets/) | Complete widget API |
| [UI Layout](https://rambros3d.github.io/RadioKit/arduino/ui-layout/) | Coordinate system and sizing |
| [Protocol Spec](https://rambros3d.github.io/RadioKit/arduino/protocol/) | Binary packet format |
| [Flutter Widgets](https://rambros3d.github.io/RadioKit/widgets/overview/) | Flutter widget library API |
| [Remote Access API](llm-docs/API.md) | HTTP API for test automation |
| [Agent Test Manual](llm-docs/AGENT-TEST.md) | End-to-end testing guide |
| [AI Agent Guidelines](AGENTS.md) | Conventions for AI coding agents |

---

# Buy Official Boards
TrackLink and Gtrack boards can be purchased from [**Elecrow.com**](https://www.elecrow.com/store/RamBros3D)

Elecrow is our manufacturing partner, more than a hundred boards sold to our happy supporters.

---

# Endorsements
Thanks to everyone who helped in this journey.

## OSHWLab & JLCPCB
All of our development prototypes are sponsored by OSHWLab.

If you are interested in PCB design, definitely checkout their [**Spark 2026 competition**](https://oshwlab.com/activities/easyeda-spark-2026?inviter=shreeramlive)
- Free Materials (PCB, Assembly, 3D printing and CNC services)
- Massive $85,000 prize pool

JLCPCB provides the fastest lead time at unbelievable prices.

## Freebuff
Unlike the other coding agents which provide "free trials", [**Freebuff is always free**](https://freebuff.com/), fully supported by ads.

Even in the limited tier; This is surprisingly good for most developement tasks.

Vibe code notice: this app was fully vibecoded with llms.
