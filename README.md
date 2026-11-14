# RadioKit
The Open-Source Alternative to RemoteXY

Build beautiful UIs for your Arduino projects and control them with the RadioKit app over BLE, USB Serial, WiFi, or Cloud Relay.

---

## Repository Structure

RadioKit is organized into dedicated repositories under the [@Radio-Kit](https://github.com/Radio-Kit) organization. This repository contains the reference Flutter companion application, Flutter widget library, AI agent skills, and test harnesses.

```
RadioKit/
├── radiokit-app/          # Reference Flutter companion application
│   ├── lib/              # Multiplatform app source (Android, iOS, macOS, Windows, Linux)
│   │   ├── screens/      # Control UI, Designer, Flasher, LittleFS, System
│   │   ├── services/     # BLE, Serial, WebSocket, Cloud, In-App MCP Server
│   │   ├── providers/    # App state management (MultiDevice, FollowRemote, Settings)
│   │   └── widgets/      # App chrome, logs, inspector widgets
│   ├── assets/           # Bundled demo layouts, skills, and templates
│   └── test/             # Unit tests and MCP protocol tests
│
├── flutter-widgets/      # Reusable Flutter widget library for RadioKit
│   ├── lib/              # UI widgets (buttons, sliders, joysticks, gauges, displays)
│   └── example/          # Interactive widget playground app
│
├── SKILLS/               # AI agent skills & bundled markdown manuals
│   ├── radiokit-remote/  # In-App MCP server specification & tool schemas
│   ├── radiokit-firmware/# Firmware development loop, configs & recipes
│   ├── radiokit-widgets/ # Hardware widget constructors & I/O bindings
│   └── llms.txt          # LLM discovery index
│
├── llm-docs/             # In-depth agent manuals & protocol specs
│   ├── API.md            # MCP protocol specification & 26 tool references
│   └── AGENT-TEST.md     # Automated E2E testing manual via MCP
│
├── flatpak/              # Linux Flatpak packaging manifests & metadata
├── scripts/              # Packaging and release automation scripts
├── test_mcp_e2e.py       # Automated end-to-end verification script for In-App MCP
└── .github/workflows/    # CI and multiplatform release workflows
```

### Dedicated Subprojects

The hardware library and relay server live in dedicated repositories:

| Subproject | Repository | Description |
| :--- | :--- | :--- |
| **RK-Arduino** | [Radio-Kit/RK-Arduino](https://github.com/Radio-Kit/RK-Arduino) | Arduino and ESP32 C++ library for widgets, transports & LittleFS |
| **RadioKit-Relay** | [Radio-Kit/RadioKit-Relay](https://github.com/Radio-Kit/RadioKit-Relay) | High-performance Rust WebSocket cloud relay server |

---

## In-App Model Context Protocol (MCP) Server

RadioKit embeds a native **Model Context Protocol (MCP)** server on port `7007` over HTTP/SSE. AI agents connect directly to the running companion app to discover and call tools autonomously.

- **Port**: `7007` (accessible locally or via `adb forward tcp:7007 tcp:7007` / USB tethering)
- **Transport**: Server-Sent Events (`GET /sse`) + JSON-RPC 2.0 messages (`POST /messages?sessionId=...`)
- **26 Typed Tools**: BLE/serial device discovery, pairing, widget inspection & mutation, LittleFS filesystem operations, block-by-block OTA firmware flashing, NVS config, reboot/reset, and ESP32 serial flasher.
- **Dynamic Resources**: Live MCU serial console (`radiokit://console`), active widget tree (`radiokit://widgets`), filesystem tree (`radiokit://fs`), and bundled documentation (`radiokit://docs`).
- **Follow Remote Mode**: Invocations drive live UI screen navigation and edge glow visual feedback on the companion device.

---

## Documentation

| Resource | Description |
| :--- | :--- |
| [Official Documentation](https://radiokit.app/) | Setup guides, tutorials, and widget references |
| [Arduino Library (RK-Arduino)](https://github.com/Radio-Kit/RK-Arduino) | Hardware library, examples, and PlatformIO setup |
| [Model Context Protocol Server](llm-docs/API.md) | In-App MCP server specification, 26 tools & resources |
| [Automated Testing Manual](llm-docs/AGENT-TEST.md) | Driving end-to-end device testing via MCP |
| [Agent Skills Index](SKILLS/SKILLS.md) | AI coding agent skills for firmware & companion app |
| [LLM Discovery](SKILLS/llms.txt) | Compact LLM prompt context & tool signatures |

---

## Buy Official Boards
TrackLink and Gtrack boards can be purchased from [**Elecrow.com**](https://www.elecrow.com/store/RamBros3D).

Elecrow is our manufacturing partner, with more than a hundred boards sold to our happy supporters.

---

## Endorsements
Thanks to everyone who helped in this journey.

### OSHWLab & JLCPCB
All of our development prototypes are sponsored by OSHWLab.

If you are interested in PCB design, definitely check out their [**Spark 2026 competition**](https://oshwlab.com/activities/easyeda-spark-2026?inviter=shreeramlive):
- Free Materials (PCB, Assembly, 3D printing, and CNC services)
- Massive $85,000 prize pool

JLCPCB provides the fastest lead time at unbelievable prices.

### Freebuff
Unlike other coding agents that provide "free trials", [**Freebuff is always free**](https://freebuff.com/), fully supported by ads.

Even in the limited tier, this is surprisingly good for most development tasks.

> **Vibe code notice**: this app was fully vibecoded with LLMs.
