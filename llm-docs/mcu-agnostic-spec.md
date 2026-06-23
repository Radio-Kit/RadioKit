# MCU-Agnostic Library Architecture

## Summary

Make the RadioKit Arduino library and generated RADIOKIT.h configuration microcontroller-agnostic. The same library compiles cleanly on ESP32, nRF52, STM32, and RP2040. Transports that aren't available on a given platform silently compile to no-ops. The radio protocol stays identical across all platforms so the Flutter app can talk to any device.

---

## 1. Target Platforms

| Platform | BLE | WiFi | Serial | NVS | OTA | FS |
|----------|-----|------|--------|-----|-----|----|
| ESP32 / ESP32-S3 | NimBLE | WiFi.h | USB CDC / UART | nvs_flash | esp_ota | LittleFS |
| nRF52832 / nRF52840 | Adafruit Bluefruit | -- | UART | Preferences (FlashStorage) | -- | LittleFS |
| STM32F4 / STM32H7 | -- (serial-only) | -- | UART | EEPROM emulation | -- | LittleFS |
| RP2040 (Pico W) | -- (serial-only) | arduino-pico WiFi | USB CDC / UART | -- | -- | LittleFS |

**Note:** nRF52 BLE support via Adafruit Bluefruit is planned but deferred to a follow-up PR. The initial multi-MCU PR focuses on serial-only on non-ESP32 platforms.

---

## 2. Design Decisions

| Decision | Answer |
|----------|--------|
| Target MCUs | ESP32, nRF52, STM32, RP2040 |
| nRF52 BLE stack | Adafruit Bluefruit (deferred to follow-up) |
| Missing transport behavior | Silent no-op — `startWiFi()` on STM32 compiles but prints a message and returns |
| Config struct fields | Keep all fields in `RK_Config` (sta_ssid, cloud_url, etc.) — unused on non-ESP32, no conditional compilation |
| BLE abstraction | Compile-time swap — separate `RadioKitBLE_NimBLE.cpp` and `RadioKitBLE_Bluefruit.cpp` files, swapped via `#ifdef` in `RadioKitBLE.h`. No virtual dispatch. |
| WiFi strategy | Platform WiFi — ESP32 uses WiFi.h, RP2040 uses arduino-pico WiFi. Same WebSocket protocol on top. |
| Serial transport | Keep `startSerial(Stream& stream)` as-is. Works everywhere. |
| Persistent storage | Platform-native — ESP32 uses nvs_flash, nRF52 uses Preferences, STM32 uses EEPROM emulation |
| Designer MCU selection | No MCU picker in designer. All features shown. Decision happens at compile time. |
| Runtime transport detection | No. Compile-time only. If compiled in, it's available. |
| Protocol format | Identical binary frame format on all platforms (0x55 widgets, 0xAA FS, 0xBB OTA, 0xDD settings, 0xEE print) |
| Flash/RAM budget | No constraint — focus on correctness first |

---

## 3. Architecture: Compile-Time Transport Gating

### 3.1 Current Pattern (ESP32-only)

WiFi and Cloud are already gated by `#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)` in the library source. This pattern extends cleanly to multi-MCU.

### 3.2 New Pattern

Each transport source file wraps its entire implementation in a platform + feature guard:

```cpp
// RadioKitWiFi.cpp
#if defined(RK_HAS_WIFI)
#include "RadioKitWiFi.h"
// ... full implementation ...
#else
// Silent no-op stubs
void RadioKitWiFi::begin(...) { Serial.println("WiFi: not available on this platform"); }
void RadioKitWiFi::update() {}
// ...
#endif
```

### 3.3 Platform Capability Defines

In `RadioKitConfig.h`, after the `RK_ARCH_DETECTED` block:

```cpp
// ── Platform capabilities (auto-detected from architecture) ──
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
  #define RK_HAS_BLE
  #define RK_HAS_WIFI
  #define RK_HAS_NVS
  #define RK_HAS_OTA
  #define RK_HAS_FS
#elif RK_ARCH_DETECTED == RK_ARCH_NORDIC
  #define RK_HAS_BLE       // Adafruit Bluefruit
  #define RK_HAS_FS
  // #define RK_HAS_NVS   // via Preferences library (deferred)
#elif RK_ARCH_DETECTED == RK_ARCH_STM32
  #define RK_HAS_FS
#elif RK_ARCH_DETECTED == RK_ARCH_RP2040
  #define RK_HAS_WIFI      // Pico W only
  #define RK_HAS_FS
#endif
```

### 3.4 User Feature Overrides

In the generated `RADIOKIT.h`, the `#define` directives become requests — the library decides whether to honor them based on platform capabilities:

```cpp
#define RADIOKIT_FEATURE_BLE
#define RADIOKIT_FEATURE_WIFI    // ignored on STM32/nRF52
#define RADIOKIT_FEATURE_FS
```

The library header `RadioKitConfig.h` resolves the final capability:

```cpp
// User requested BLE, platform supports BLE → enable
#if defined(RADIOKIT_FEATURE_BLE) && defined(RK_HAS_BLE)
  #define RK_BLE_ENABLED
#endif

// User requested WiFi, platform supports WiFi → enable
#if defined(RADIOKIT_FEATURE_WIFI) && defined(RK_HAS_WIFI)
  #define RK_WIFI_ENABLED
#endif

// etc.
```

The `start*()` methods check `RK_*_ENABLED` at compile time:

```cpp
void RadioKitClass::startWiFi() {
#if defined(RK_WIFI_ENABLED)
  // ... actual implementation ...
#else
  RadioKit.print("WiFi: not available on this platform\n");
#endif
}
```

---

## 4. File Changes

### 4.1 Library Core

| File | Change |
|------|--------|
| `RadioKitConfig.h` | Add `RK_HAS_BLE`, `RK_HAS_WIFI`, `RK_HAS_NVS`, `RK_HAS_OTA`, `RK_HAS_FS` based on `RK_ARCH_DETECTED`. Add `RK_BLE_ENABLED`, `RK_WIFI_ENABLED`, etc. resolution from user defines + platform caps. |
| `RadioKitLib.h` | Replace `#if defined(ESP32)` guards with `#if defined(RK_BLE_ENABLED)` / `#if defined(RK_WIFI_ENABLED)` etc. |
| `RadioKit.cpp` | Replace all `#if defined(ESP32)` with `#if defined(RK_*_ENABLED)`. The `startWiFi()`, `startBLE()`, `startCloud()` methods become no-ops when their `RK_*_ENABLED` is not defined. |

### 4.2 Transport Files

| File | Change |
|------|--------|
| `RadioKitBLE.h` | Replace `#include <NimBLEDevice.h>` with `#if defined(RK_BLE_ENABLED)` guard. Forward-declare classes for non-BLE builds. |
| `RadioKitBLE.cpp` | Wrap entire implementation in `#if defined(RK_BLE_ENABLED)`. Add no-op stubs in `#else`. |
| `RadioKitWiFi.h` | Replace `#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)` with `#if defined(RK_WIFI_ENABLED)`. |
| `RadioKitWiFi.cpp` | Same guard replacement. |
| `RadioKitCloud.h` | Replace `#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)` with `#if defined(RK_WIFI_ENABLED)`. |
| `RadioKitCloud.cpp` | Same guard replacement. |
| `RadioKitNVS.h` | Replace `#if defined(ESP32)` with `#if defined(RK_HAS_NVS)`. |
| `RadioKitNVS.cpp` | Same guard replacement. |
| `RadioKitOTA.h` | Add `#if defined(RK_HAS_OTA)` guard. |
| `RadioKitOTA.cpp` | Same guard replacement. |
| `RadioKitSerial.cpp` | Add `#if defined(RK_HAS_BLE)` guard around ESP32-S3 USB stall workaround (only needed on ESP32). |

### 4.3 NVS Abstraction

| Platform | Implementation | API |
|----------|---------------|-----|
| ESP32 | `nvs_flash` API (existing) | `RKNvs::readU8()`, `writeU8()`, `readString()`, `writeString()`, `commit()` |
| nRF52 | `Preferences` library | Same API — `Preferences` is a thin wrapper around flash storage |
| STM32 | EEPROM emulation library | Same API — emulated EEPROM in flash sectors |
| RP2040 | `EEPROM` library | Same API — RP2040 uses flash-based EEPROM emulation |

The `RKNvs` namespace already provides a platform-agnostic API. Each platform gets its own `RadioKitNVS.cpp` implementation selected via `#if RK_ARCH_DETECTED == ...`.

### 4.4 Codegen Changes (`json_arduino_generator.dart`)

The codegen output becomes MCU-agnostic:

```cpp
// Features (user requests — library resolves per platform)
#define RADIOKIT_FEATURE_BLE
#define RADIOKIT_FEATURE_WIFI
#define RADIOKIT_FEATURE_FS

#include <RadioKitLib.h>

// ... widgets ...

static inline void initRadioKit() {
  RadioKit.begin();
  RadioKit.startSerial(Serial);
  RadioKit.startBLE(RadioKit.config.name);  // no-op on STM32
  RadioKit.startWiFi();                      // no-op on STM32/nRF52
  RKFs::begin();                            // no-op if FS not available
}
```

No `#ifdef` guards in generated code — the library handles platform gating internally.

---

## 5. nRF52 BLE Support (Follow-up PR)

### 5.1 Compile-Time Swap

```
rk-arduino/src/connection/
  RadioKitBLE.h           # Common interface header
  RadioKitBLE_NimBLE.cpp  # ESP32 implementation (existing)
  RadioKitBLE_Bluefruit.cpp  # nRF52 implementation (new)
```

`RadioKitBLE.h` selects the implementation:

```cpp
#if defined(RK_BLE_ENABLED)
  #if RK_ARCH_DETECTED == RK_ARCH_ESP32
    #include "RadioKitBLE_NimBLE.h"
  #elif RK_ARCH_DETECTED == RK_ARCH_NORDIC
    #include "RadioKitBLE_Bluefruit.h"
  #endif
#endif
```

Both implementations expose the same public API:
- `begin(name)`
- `sendPacket(data, len)`
- `update()`
- `isConnected()`
- `disconnect()`
- `getRssi()`

### 5.2 Adafruit Bluefruit Differences

| Aspect | NimBLE (ESP32) | Bluefruit (nRF52) |
|--------|---------------|-------------------|
| Service UUID | 0xFFE0 | Custom 128-bit UUID |
| Characteristics | 5 (widget, FS, OTA, settings, print) | 5 (same protocol) |
| MTU | Auto-negotiated (up to 517) | Fixed 20 (default), configurable |
| Advertising | `NimBLEDevice::startAdvertising()` | `bleuart.begin()`, `Bluefruit.Advertising.addService()` |
| Notifications | `notify()` on characteristic | `notify()` on BLEUART |
| Write handler | `NimBLECharacteristicCallbacks::onWrite` | `BLECharacteristic::setWriteCallback` |

The protocol layer (frame parsing, widget serialization) is transport-agnostic and shared.

---

## 6. RP2040 WiFi Support (Follow-up PR)

### 6.1 Architecture

RP2040 Pico W uses `WiFi.h` from the `arduino-pico` core, which provides a similar API to ESP32's WiFi.h. The WebSocket server uses the same `WebSocketsServer` library.

### 6.2 Guard Pattern

```cpp
// RadioKitWiFi.cpp
#if defined(RK_WIFI_ENABLED)
  #if RK_ARCH_DETECTED == RK_ARCH_ESP32
    #include <WiFi.h>
  #elif RK_ARCH_DETECTED == RK_ARCH_RP2040
    #include <WiFi.h>  // arduino-pico provides this
  #endif
  // ... shared WebSocket implementation ...
#endif
```

### 6.3 PlatformIO Configuration

```ini
[env:pico_w]
platform = https://github.com/maxgerhardt/platform-raspberrypi.git
board = rpipicow
framework = arduino
lib_deps =
    bblanchon/ArduinoWebsockets
    bblanchon/ArduinoJson
```

---

## 7. Testing Strategy

### 7.1 CI Matrix

| Platform | Board | Transport | Build |
|----------|-------|-----------|-------|
| ESP32 | ESP32-S3 DevKit | BLE + WiFi + FS + OTA | `pio run` |
| nRF52 | Adafruit Feather nRF52840 | Serial only (BLE deferred) | `pio run` |
| STM32 | Nucleo-64 STM32F446RE | Serial only | `pio run` |
| RP2040 | Raspberry Pi Pico W | Serial + WiFi (deferred) | `pio run` |

### 7.2 Unit Tests

- Compile all examples for each target platform (CI matrix)
- Verify `startWiFi()` on STM32 compiles and prints "not available"
- Verify `startBLE()` on STM32 compiles and prints "not available"
- Verify `RKFs::begin()` works on all platforms with LittleFS
- Verify protocol frame format is identical (same binary output for same widget config)

### 7.3 Hardware Tests

- ESP32: Existing hardware tests continue to pass (regression)
- nRF52: Serial-only connection test via Flutter app
- STM32: Serial-only connection test via Flutter app
- RP2040: WiFi connection test via Flutter app (deferred)

---

## 8. Breaking Changes

- `ENABLE_RK_SERIAL/BLE/WIFI/CLOUD` defines removed (replaced by `RADIOKIT_FEATURE_BLE/WIFI/FS/OTA`)
- `RADIOKIT_ENABLE_WIFI` build flag removed (replaced by `RADIOKIT_FEATURE_WIFI` in sketch header)
- `config.transport` field removed from `RK_Config`
- `RK_Config` struct keeps all fields (sta_ssid, cloud_url, etc.) — they're just unused on non-ESP32
- All 7 Arduino example `RADIOKIT.h` files must be regenerated with the new codegen

---

## 9. Implementation Order

1. **Phase 1 — Core abstraction**: Add `RK_HAS_*` / `RK_*_ENABLED` defines to `RadioKitConfig.h`. Replace `#if defined(ESP32)` guards in `RadioKit.cpp`, `RadioKitLib.h`, and all transport files with the new capability-based guards.

2. **Phase 2 — NVS abstraction**: Implement `RadioKitNVS.cpp` variants for nRF52 (Preferences) and STM32 (EEPROM). ESP32 stays unchanged.

3. **Phase 3 — Serial-only builds**: Verify STM32 and nRF52 compile cleanly with serial-only transport. Create example sketches for each.

4. **Phase 4 — Codegen update**: Update `json_arduino_generator.dart` to emit `RADIOKIT_FEATURE_*` defines and remove `#ifdef` guards from generated start calls.

5. **Phase 5 — CI matrix**: Add STM32 and nRF52 build targets to `.github/workflows/pioarduino-ci.yml`.

6. **Phase 6 — nRF52 BLE (follow-up)**: Implement `RadioKitBLE_Bluefruit.cpp` for nRF52 BLE support.

7. **Phase 7 — RP2040 WiFi (follow-up)**: Add RP2040 Pico W WiFi support.

---

## 10. Edge Cases and Additional Considerations

### 10.1 Print Stream (0xEE)

The print stream is transport-agnostic and broadcasts to all active transports. On non-ESP32 platforms:
- **Serial**: Always available.
- **BLE**: Available when `RK_BLE_ENABLED` is defined.
- **WiFi/Cloud**: Available when `RK_WIFI_ENABLED` is defined.

The print stream is already implemented in `RadioKitPrint.cpp` with no platform-specific code. No changes needed.

### 10.2 Settings Feature Bitmask

The settings protocol (0xDD) sends a feature bitmask to the Flutter app via `_handleSettingsGetFeatures()`. This must be platform-aware:

```cpp
// Before (ESP32-only)
#if defined(ESP32)
    bitmask |= RK_SETTINGS_FEATURE_BLE;
#endif

// After (platform-agnostic)
#if defined(RK_BLE_ENABLED)
    bitmask |= RK_SETTINGS_FEATURE_BLE;
#endif
#if defined(RK_HAS_OTA)
    bitmask |= RK_SETTINGS_FEATURE_OTA;
#endif
#if defined(RK_HAS_FS)
    bitmask |= RK_SETTINGS_FEATURE_FS;
#endif
```

### 10.3 Cloud Without WiFi

Cloud requires WiFi. The library already handles this at runtime — `startCloud()` returns early if `_wifiActive` is false. For non-ESP32 platforms without WiFi, `startCloud()` compiles to a no-op. The Cloud guard in `RadioKitCloud.h` checks `RK_WIFI_ENABLED`.

### 10.4 RadioKitTransport Inheritance Mismatch

BLE inherits from `RadioKitTransport` (virtual interface). WiFi, Cloud, and Serial are separate classes. The compile-time swap for BLE works because BLE is the only transport using the virtual interface. WiFi/Cloud use a simpler guard pattern — entire `.cpp` wraps in `#if defined(RK_WIFI_ENABLED)` with no-op stubs.

### 10.5 PlatformIO Build Flag Migration

The `RADIOKIT_ENABLE_WIFI` build flag in `platformio.ini` is replaced by `RADIOKIT_FEATURE_WIFI` in the sketch header. Existing PlatformIO configs using `-D RADIOKIT_ENABLE_WIFI` must remove the build flag. The feature flag in the sketch header becomes the single source of truth.

### 10.6 WiFi API Differences Between Platforms

ESP32 and RP2040 both provide `WiFi.h` but with different APIs:

| API | ESP32 | RP2040 (arduino-pico) |
|-----|-------|----------------------|
| Station mode | `WiFi.mode(WIFI_STA)` | `WiFi.mode(WIFI_STA)` |
| AP mode | `WiFi.softAP(ssid)` | `WiFi.beginAP(ssid)` |
| IP address | `WiFi.localIP()` | `WiFi.localIP()` |
| Status | `WiFi.status() == WL_CONNECTED` | `WiFi.status() == WL_CONNECTED` |

Platform-specific WiFi setup is handled inside `RadioKitWiFi.cpp` with `#if RK_ARCH_DETECTED` guards. The WebSocket layer (`WebSocketsServer`) is identical on both platforms.

### 10.7 `RK_Config.transport` Vestigial Field

The `RK_Config.transport` field is vestigial. Recommendation: remove it in a follow-up PR. Existing code that sets `config.transport` would break, but no real-world code does this.

### 10.8 OTA on Non-ESP32

OTA uses ESP32's `Update.h` and `esp_ota_ops`. On non-ESP32 platforms, the OTA implementation is guarded with `#if defined(RK_HAS_OTA)`. The settings feature bitmask won't include `RK_SETTINGS_FEATURE_OTA`, so the Flutter app won't show OTA UI for non-ESP32 devices.

### 10.9 FS on Non-ESP32

LittleFS is available on all target platforms. The FS handlers use weak-linked functions so user sketches can override the filesystem backend. No platform-specific changes needed — just ensure `RK_HAS_FS` is defined for all platforms.

### 10.10 ESP32-S3 USB Serial Stall Workaround

`RadioKitSerial.cpp` has a workaround for ESP32-S3's native USB Serial/JTAG controller. This must be guarded with `#if RK_ARCH_DETECTED == RK_ARCH_ESP32` since it's ESP32-specific.

### 10.11 Arduino Core Library Dependencies

Each platform requires different PlatformIO dependencies:

| Platform | Required libs |
|----------|---------------|
| ESP32 | NimBLE-Arduino, ArduinoWebsockets, ArduinoJson |
| nRF52 | Adafruit_BluefruitLibrary, Adafruit_nRF52_Arduino |
| STM32 | (none beyond core) |
| RP2040 | ArduinoWebsockets, ArduinoJson |

The `platformio.ini` for each example must list platform-appropriate `lib_deps`.

---

## 11. Risks and Open Questions

| Risk | Mitigation |
|------|------------|
| NimBLE API changes break nRF52 Bluefruit port | Abstract behind `RK_BLE_ENABLED` — each platform has independent code |
| LittleFS not available on all STM32 boards | Add `RK_HAS_FS` guard — boards without LittleFS get serial-only |
| PlatformIO board definitions vary widely | Test with specific board targets in CI, not generic platform |
| RP2040 WiFi.h API differs from ESP32 WiFi.h | Wrap platform-specific WiFi setup in `RadioKitWiFi.cpp` with `#if RK_ARCH_DETECTED` |
| EEPROM wear on STM32 (no native NVS) | Use EEPROM emulation library with wear-leveling. Document write limits. |
