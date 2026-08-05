## 1. Core Architecture Abstractions (`rk-arduino/src/core/`)

- [x] 1.1 Create `ICommandHandler.h` interface for protocol command processing.
- [x] 1.2 Create `TransportManager.h` and `TransportManager.cpp` for multi-transport registration and packet broadcasting.
- [x] 1.3 Create `CommandDispatcher.h` and `CommandDispatcher.cpp` for header-based packet routing.

## 2. Protocol Command Handlers (`rk-arduino/src/handlers/`)

- [x] 2.1 Extract control widget packet processing (`0x55`) into `ControlCommandHandler.cpp`.
- [x] 2.2 Extract settings and NVS authentication handling (`0xDD`) into `SettingsCommandHandler.cpp`.
- [x] 2.3 Extract LittleFS bulk file protocol handling (`0xAA`) into `FsCommandHandler.cpp`.
- [x] 2.4 Extract OTA firmware update packet handling (`0xBB`) into `OtaCommandHandler.cpp`.
- [x] 2.5 Extract remote console print stream packet handling (`0xEE`) into `PrintCommandHandler.cpp`.

## 3. Core Class Refactoring (`rk-arduino/src/`)

- [x] 3.1 Refactor `RadioKitClass` in `RadioKitClass.h` to use `TransportManager` and `CommandDispatcher`.
- [x] 3.2 Refactor `RadioKit.cpp` into lightweight core lifecycle and sketch API entry point.
- [x] 3.3 Ensure `#ifdef` macro guards cleanly isolate optional FS and OTA handlers during compilation.

## 4. Verification and Build Validation

- [x] 4.1 Validate compilation of example sketches in `rk-arduino/examples/` using PlatformIO / Arduino CLI.
- [x] 4.2 Run integration protocol tests to verify packet serialization/deserialization backwards compatibility.
