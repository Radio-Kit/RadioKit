# RadioKit Skills

Modular skill packages for AI agents working on the RadioKit project. Each skill provides specialized knowledge, workflows, and conventions for a specific domain.

## Skills

| Skill | Component | When to Use |
|-------|-----------|-------------|
| [radiokit-example](radiokit-example/SKILL.md) | rk-arduino | Creating new ESP32 Arduino example sketches, writing `RADIOKIT.h` configs, setting up `platformio.ini` |
| [radiokit-widget](radiokit-widget/SKILL.md) | rk-arduino | Adding or modifying widget classes, `rk` structs, protocol encoding in `rk-arduino/src/widgets/` |
| [radiokit-transport](radiokit-transport/SKILL.md) | Both | Working on BLE/Serial/WiFi/Cloud transports, frame protocol, connection handling on either side |
| [radiokit-flutter](radiokit-flutter/SKILL.md) | radiokit-app | Adding screens, providers, services, or modifying app architecture in the Flutter companion app |
| [radiokit-designer](radiokit-designer/SKILL.md) | radiokit-app | Working with the visual Designer, JSON config schema, Arduino codegen, inspector panels |
| [radiokit-testing](radiokit-testing/SKILL.md) | Both | Writing unit/integration tests, running CI validation, creating fake transports and test helpers |
| [radiokit-relay](radiokit-relay/SKILL.md) | radiokit-relay | Developing, deploying, or testing the Rust WebSocket relay server, Ed25519 auth, Docker deployment |

## Quick Reference

### Arduino Development (C++)
- **New example project** -- Start with `radiokit-example`
- **New/modified widget type** -- Start with `radiokit-widget`
- **Transport changes** -- Start with `radiokit-transport`

### Flutter App Development (Dart)
- **New screen or provider** -- Start with `radiokit-flutter`
- **Designer/codegen changes** -- Start with `radiokit-designer`
- **Writing tests** -- Start with `radiokit-testing`

### Rust Relay Development
- **Relay server changes** -- Start with `radiokit-relay`

### Cross-Cutting
- **Protocol or frame format changes** -- Start with `radiokit-transport`
- **Testing any component** -- Start with `radiokit-testing`
