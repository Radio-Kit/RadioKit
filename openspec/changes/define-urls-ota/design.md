## Context

Previously, remote repository links (`fs_url`) and OTA firmware links (`ota_url`) were written to ESP32 Flash NVS (`rk_fs_url`, `rk_ota_url`) on first boot. This introduced flash wear and caused URLs to be wiped on `--erase` flash cycles. In addition, OTA updates could not be enabled from the sketch because feature detection in `RadioKit.cpp` used an isolated compile-time macro (`#if defined(RK_ENABLE_OTA)`), which failed to detect the macro when defined in the sketch header `RADIOKIT.h`.

## Goals / Non-Goals

**Goals:**
- Eliminate NVS storage for `fs_url` and `ota_url`, moving to `#define` macros and C++ string constants.
- Allow defining `RK_FS_URL` and `RK_OTA_URL` directly in `platformio.ini` or `RADIOKIT.h`.
- Add `RadioKit.enableOTA()` runtime method so sketches activate OTA updates dynamically and report the OTA feature bit in `SETTINGS_CMD_GET_FEATURES`.
- Update Designer Arduino codegen to emit `#define RK_FS_URL`, `#define RK_OTA_URL`, and `RadioKit.enableOTA()`.

**Non-Goals:**
- Backward compatibility with NVS keys `rk_fs_url` and `rk_ota_url` (removed per user directive).
- Dynamic runtime URL rewriting via BLE settings frames.

## Decisions

### 1. Compile-Time Default Macros & Struct Storage
- `RadioKitConfig.h` defines default fallback macros:
  ```cpp
  #ifndef RK_FS_URL
  #define RK_FS_URL ""
  #endif
  #ifndef RK_OTA_URL
  #define RK_OTA_URL ""
  #endif
  ```
- `RK_Config` struct fields initialize from these macros:
  ```cpp
  const char* fs_url  = RK_FS_URL;
  const char* ota_url = RK_OTA_URL;
  ```
- Sketches can override them via `#define RK_FS_URL "..."` before `#include <RadioKitLib.h>`, or via `RadioKit.config.fs_url = "..."` in `initRadioKit()`, or via `-D RK_FS_URL=\"...\"` in `platformio.ini`.

### 2. Direct Streaming in Settings Protocol
- `_handleSettingsGetLinksInfo()` reads directly from `config.fs_url` and `config.ota_url`. Zero NVS interaction.

### 3. Dynamic OTA Feature Reporting
- `RadioKitClass` maintains `bool _otaReady = false;`.
- Calling `RadioKit.enableOTA()` sets `_otaReady = true;`.
- `_handleSettingsGetFeatures()` checks `if (isOtaReady()) { bitmask |= RK_SETTINGS_FEATURE_OTA; }`.
- OTA command handlers (`_handleOtaBegin`, etc.) guard on `if (!_otaReady)`.

## Risks / Trade-offs

- [Risk] If a sketch does not call `RadioKit.enableOTA()`, OTA commands are rejected and the FIRMWARE tab in the app will not appear.
  → Mitigation: Codegen emits `RadioKit.enableOTA();` automatically when an OTA URL or OTA feature is enabled in the designer config.
