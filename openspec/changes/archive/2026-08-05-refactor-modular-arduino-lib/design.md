## Context

The `rk-arduino` library core resides in `RadioKit.cpp` (102.4 KB), which handles packet reception, command routing, NVS configuration, widget state synchronization, LittleFS file transfers, and OTA firmware updates in one giant file.

This refactoring breaks down `RadioKit.cpp` into modular subsystems using an `ICommandHandler` interface and a `TransportManager` to improve maintainability, reduce compilation times, and allow dead-code elimination of unused features.

## Goals / Non-Goals

**Goals:**
- Decompose `RadioKit.cpp` into core lifecycle modules (`src/core/`) and protocol command handlers (`src/handlers/`).
- Create `ICommandHandler` interface for modular packet dispatching (`0x55`, `0xAA`, `0xBB`, `0xDD`, `0xEE`).
- Create `TransportManager` to manage active transports dynamically and broadcast packet updates.
- Enable conditional feature compilation via macro guards (`#ifdef RK_ENABLE_FS`, `#ifdef RK_ENABLE_OTA`).
- Maintain 100% backward compatibility with all existing user sketches and generated `RADIOKIT.h` headers.

**Non-Goals:**
- Modifying binary frame protocol specifications (0x55, 0xAA, 0xBB, 0xDD, 0xEE formats).
- Altering user sketch API syntax (`RadioKit.begin()`, `RadioKit.startBLE()`, etc.).

## Decisions

### 1. `ICommandHandler` Interface
- **Decision**: Define `ICommandHandler` abstract class in `src/core/ICommandHandler.h`. Each protocol (`Control`, `Settings`, `Filesystem`, `OTA`, `Print`) implements `ICommandHandler`.
- **Rationale**: Isolates protocol handling logic into single-responsibility classes. Unused protocol handlers can be compiled out cleanly.

### 2. `TransportManager` Subsystem
- **Decision**: Introduce `TransportManager` in `src/core/TransportManager.h` that manages a dynamic collection of active `RadioKitTransport` instances.
- **Rationale**: Simplifies broadcasting (`pushUpdate(id)`, `println()`) across BLE, Serial, WiFi, and Cloud without branching logic in core `RadioKitClass`.

### 3. Folder Reorganization (`src/core/` & `src/handlers/`)
- **Decision**: Group internal architecture files under `src/core/` and protocol handlers under `src/handlers/`.

## Risks / Trade-offs

- **[Risk] Arduino IDE Library Compilation Pathing** → *Mitigation*: Ensure all headers are included via relative paths or exported in `RadioKitLib.h` so standard Arduino IDE flat compile rules work seamlessly.
- **[Risk] Microcontroller RAM overhead from virtual dispatch** → *Mitigation*: Use static singleton handler instances or light function pointers to keep RAM footprint low.

## Migration Plan

1. Create `ICommandHandler` and `TransportManager` in `src/core/`.
2. Extract protocol handlers (`ControlCommandHandler`, `SettingsCommandHandler`, `FsCommandHandler`, `OtaCommandHandler`, `PrintCommandHandler`) into `src/handlers/`.
3. Refactor `RadioKitClass` and `RadioKit.cpp` to use the new subsystems.
4. Run PlatformIO / Arduino build validation across example sketches.
