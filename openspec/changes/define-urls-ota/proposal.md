## Why

Currently, filesystem repository URLs (`fs_url`) and OTA firmware URLs (`ota_url`) are stored in ESP32 Flash NVS (`rk_fs_url`, `rk_ota_url`), which creates unnecessary NVS overhead and causes URLs to be lost whenever flash is erased during flashing (`--erase`). Furthermore, OTA firmware updates cannot be enabled dynamically from the user's sketch because OTA feature reporting relies on a compile-time macro (`#if defined(RK_ENABLE_OTA)`) that is not visible when the library (`RadioKit.cpp`) is compiled, causing the `FIRMWARE` (OTA) tab in the companion app to be omitted.

By switching `fs_url` and `ota_url` to `#define` / C++ config constants and introducing a runtime `RadioKit.enableOTA()` API, we eliminate NVS flash storage for project URLs, support direct `platformio.ini` compile flags, and guarantee that the OTA firmware tab is dynamically activated when configured in the sketch.

## What Changes

- **Compile-time Link Definitions**: Use `#ifndef RK_FS_URL` / `#define RK_FS_URL ""` and `#ifndef RK_OTA_URL` / `#define RK_OTA_URL ""` in `RadioKitConfig.h` and default `RadioKit.config.fs_url` / `RadioKit.config.ota_url` to them.
- **Direct Link Streaming**: Update `_handleSettingsGetLinksInfo()` in `RadioKit.cpp` to stream `config.fs_url` and `config.ota_url` directly from memory/flash ROM instead of reading from NVS.
- **NVS Key Removal**: Remove `RK_NVS_KEY_FS_URL`, `RK_NVS_KEY_OTA_URL`, and related NVS read/write logic.
- **Runtime OTA Enablement**: Add `void enableOTA()` and `bool isOtaReady()` in `RadioKitClass`.
- **Dynamic Feature Reporting**: Update `_handleSettingsGetFeatures()` in `RadioKit.cpp` to check `isOtaReady()` dynamically (mirroring `isFsReady()`), properly setting `RK_SETTINGS_FEATURE_OTA` in the feature bitmask.
- **Designer Codegen**: Update `JsonArduinoGenerator` to emit `#define RK_FS_URL "..."` / `#define RK_OTA_URL "..."` and `RadioKit.enableOTA()` in `initRadioKit()`.
- **User Sketch Updates**: Update `RADIOKIT.h` in `RC_brain` to call `RadioKit.enableOTA()`.

## Capabilities

### New Capabilities
- `ota-runtime-enablement`: Runtime activation and feature reporting for OTA updates via `RadioKit.enableOTA()`.

### Modified Capabilities
- `repo-info-protocol`: Switch `fs_url` and `ota_url` source of truth from NVS partition keys to C++ compile-time config strings in `RadioKit.config`.

## Impact

- **Firmware (`rk-arduino`)**: `RadioKitConfig.h`, `RadioKitClass.h`, `RadioKit.cpp`, `RadioKitNVS.h`.
- **Code Generation**: `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart`.
- **Documentation & Specs**: `website/src/content/docs/arduino/protocol.mdx` and OpenSpec delta specs.
