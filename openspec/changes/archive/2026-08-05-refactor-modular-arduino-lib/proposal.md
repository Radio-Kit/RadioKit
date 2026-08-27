## Why

The `rk-arduino` ESP32 C++ library currently relies on a single 102.4 KB monolithic `RadioKit.cpp` file that handles packet parsing, NVS settings, command dispatches, and transport checks in giant `switch` statements. Adding new custom commands, protocol extensions, or custom hardware transports (such as ESP-NOW, Ethernet, or CAN-bus) requires modifying `RadioKit.cpp` and `RadioKitClass`, making maintenance fragile and preventing compile-time dead-code elimination on memory-constrained microcontrollers.

## What Changes

- Decompose `RadioKit.cpp` into focused compilation units under `src/core/` and `src/handlers/`.
- Introduce an `ICommandHandler` interface and `CommandDispatcher` to decouple protocol command processing (`0x55` Control, `0xAA` Filesystem, `0xBB` OTA, `0xDD` Settings, `0xEE` Print Stream).
- Introduce a `TransportManager` class to allow registering and broadcasting across multiple `RadioKitTransport` implementations without hardcoding specific transports in core logic.
- Ensure 100% API compatibility for end-user Arduino sketches using `RadioKit.begin()`, `RadioKit.startBLE()`, `RadioKit.startSerial()`, etc.

## Capabilities

### New Capabilities

- `command-handler-registry`: Interface and registry for modular protocol command handlers (`0x55`, `0xAA`, `0xBB`, `0xDD`, `0xEE`).
- `transport-manager`: Centralized transport manager for registering and broadcasting packets across multiple active transports.
- `subsystem-refactoring`: Decomposition of `RadioKit.cpp` into single-responsibility subsystem modules under `src/core/` and `src/handlers/`.

### Modified Capabilities

<!-- No requirement level changes to existing user-facing APIs or sketch interfaces -->

## Impact

- `rk-arduino/src/RadioKit.cpp`: Refactored from a 102.4 KB monolith into a lightweight core entry point.
- `rk-arduino/src/core/`: Added `RadioKitCore.cpp`, `RadioKitDispatcher.cpp`, `RadioKitRegistry.cpp`.
- `rk-arduino/src/handlers/`: Added `ControlCommandHandler.cpp`, `SettingsCommandHandler.cpp`, `FsCommandHandler.cpp`, `OtaCommandHandler.cpp`, `PrintCommandHandler.cpp`.
- `rk-arduino/src/connection/`: Updated to register with `TransportManager`.
