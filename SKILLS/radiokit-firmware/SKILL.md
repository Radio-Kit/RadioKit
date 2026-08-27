---
name: radiokit-firmware
description: Complete guide for building Arduino firmware with the RadioKit library. Use this skill when creating, modifying, or debugging RadioKit-based firmware for ESP32, STM32, or RP2040.
---

# RadioKit Firmware Development

## Overview

RadioKit is an Arduino library that provides a wireless UI framework for microcontrollers. It bridges widgets (buttons, sliders, LEDs, etc.) declared in firmware to a companion Flutter app over BLE, Serial, WiFi, or Cloud transports. The library handles all protocol encoding/decoding, transport management, and state synchronization automatically.

**Platforms**: ESP32 (full), STM32 (Serial-only), RP2040 (Serial-only, Pico W has WiFi)
**Protocol version**: 5
**Max widgets**: 16 per device

## Project Structure

Every RadioKit firmware project has two key files:

```
<sketch_dir>/
  <sketch>.cpp       # Main Arduino sketch (setup + loop)
  RADIOKIT.h         # Config, build flags, widget declarations
```

For PlatformIO projects, also add `platformio.ini`.

## Step-by-Step Setup

### 1. Create RADIOKIT.h

```cpp
/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "config": {
    "name": "MyDevice",
    "description": "A custom controller",
    "theme": "dragon",
    "transports": {
      "ble": { "enabled": true },
      "wifi": { "enabled": false, "ssid": "", "pass": "" },
      "cloud": { "enabled": false, "account": "", "relay": "" }
    }
  },
  "canvas": { "size": [200, 100] },
  "pages": [
    {
      "name": "Controls",
      "orientation": "landscape",
      "widgets": []
    }
  ]
}
RADIOKIT_Designer_Config__*/

#pragma once
#include <RadioKitLib.h>

// Widget declarations (global = self-registering)
RK_PushButton btn_power(20, 60, 20);
RK_LED led_status(115, 29, 28);
RK_Slider slider_speed(20, 20, 15, 80);

inline void initRadioKit() {
  // 1. Configure
  RadioKit.config.name = "MyDevice";
  RadioKit.config.description = "A custom controller";
  RadioKit.config.theme = "dragon";

  // 2. Post-construction widget config
  btn_power.rk.onText = "ON";
  btn_power.rk.offText = "OFF";
  led_status.rk.color = RK_GREEN;
  slider_speed.rk.centering = RK_SPRING_CENTER;

  // 3. Initialize library
  RadioKit.begin();

  // 4. Start transports (after begin)
  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
}
```

### 2. Create the Sketch

```cpp
#include "RADIOKIT.h"

void setup() {
  Serial.begin(115200);

  // Initialize RadioKit (config, begin, and transports are all inside initRadioKit)
  initRadioKit();

  // Optional: set passwords at runtime
  RadioKit.setConfig(nullptr, nullptr, "device_pass", "user_pass");
}

void loop() {
  RadioKit.update();  // MUST call every iteration

  // Read inputs from app
  if (btn_power.rk.state) {
    digitalWrite(LED_BUILTIN, HIGH);
  } else {
    digitalWrite(LED_BUILTIN, LOW);
  }

  // Write outputs to app
  led_status.rk.state = digitalRead(SENSOR_PIN);
  slider_speed.rk.value = map(analogRead(POT_PIN), 0, 4095, -100, 100);
}
```

## RK_Config Reference

All fields are set on `RadioKit.config` before calling `RadioKit.begin()`:

| Field | Type | Default | Max Length | Description |
|-------|------|---------|------------|-------------|
| `name` | `const char*` | `"RadioKit Device"` | 32 | Device name (BLE advertised name, AP SSID prefix) |
| `description` | `const char*` | `""` | 128 | Device description |
| `password` | `const char*` | `""` | 32 | Device password (full access) |
| `version` | `const char*` | `"1.0.0"` | - | Firmware version |
| `type` | `const char*` | `""` | - | Device type (e.g. "IOT", "Robot") |
| `theme` | `const char*` | `"dragon"` | - | UI theme: `"dragon"`, `"neon"`, `"minimal"` |
| `orientation` | `uint8_t` | `0` (landscape) | - | `0`=Landscape, `1`=Portrait |
| `width` | `uint8_t` | `0` | - | Canvas width (0 = auto) |
| `height` | `uint8_t` | `0` | - | Canvas height (0 = auto) |
| `transport` | `uint8_t` | `0` (BLE) | - | **Vestigial** -- transport is now selected via `transports` object in JSON config and NVS flags |
| `baudrate` | `uint32_t` | `1000000` | - | Serial baud rate |
| `sta_ssid` | `const char*` | `""` | 32 | WiFi STA SSID |
| `sta_password` | `const char*` | `""` | 64 | WiFi STA password |
| `cloud_url` | `const char*` | `""` | 128 | Cloud relay URL (wss://...) |
| `cloud_account` | `const char*` | `""` | 64 | Ed25519 public key hex |
| `device_icon` | `const char*` | `""` | 32 | Icon name from designer registry |
| `architecture` | `uint8_t` | auto-detected | - | **Read-only** -- chip architecture (set by `RK_ARCH_DETECTED`) |
| `libversion` | `const char*` | compile-time | - | **Read-only** -- library version string |

## Build Flags

Enable features via `platformio.ini` build_flags:

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps =
    stevemejia/RadioKit@^2.0.0
build_flags =
    -D RK_ENABLE_WIFI
    -D RK_ENABLE_OTA
    -D RK_ENABLE_FS
board_build.filesystem = littlefs
```

| Flag | Purpose | Required For |
|------|---------|-------------|
| `RK_ENABLE_WIFI` | WiFi WebSocket transport | WiFi, Cloud |
| `RK_ENABLE_OTA` | Over-the-air firmware updates | OTA |
| `RK_ENABLE_FS` | LittleFS filesystem | Filesystem |
| `RK_ENABLE_CLOUD` | Cloud relay client | Cloud (also needs WIFI) |

BLE and Serial are always available (no flags needed).

## Essential API

### Setup Methods

```cpp
RadioKit.begin();                              // Initialize library, call after config
RadioKit.startBLE(const char* name = nullptr); // Start BLE (NimBLE)
RadioKit.startSerial(Stream& stream);          // Start Serial transport
RadioKit.startWiFi();                          // Start WiFi WebSocket server
RadioKit.startCloud();                         // Start cloud relay client
RadioKit.setNumPages(uint8_t n);               // Set total page count (call before begin)
RadioKit.setPageNames(const char* const* names); // Set page name array (call before begin)
RadioKit.setPageOrientations(const uint8_t* or); // Set per-page orientations: 0=landscape, 1=portrait (call before begin)
RadioKit.setCanvasFlags(uint8_t flags);         // Set canvas display flags: 0x01=showPageBar, 0x02=showControlPageBar (call before begin)
RadioKit.setActivePage(uint8_t page);          // Switch active page at runtime
RadioKit.getActivePage();                      // Get current page index
RadioKit.getNumPages();                        // Get total page count
```

### Loop Methods

```cpp
RadioKit.update();                             // Poll transports, sync state (call every loop)
RadioKit.pushUpdate(uint8_t widgetId);         // Force-push widget state
RadioKit.pushMetaUpdate(uint8_t widgetId);     // Force-push widget metadata (strings)
```

### Widget Visibility (firmware-controlled)

Widgets can be hidden from the app UI at runtime. Hidden widgets are excluded from CONF_DATA, VAR_DATA, and META_DATA — the app never creates a WidgetConfig for them.

```cpp
led_status.setHidden(true);      // hide from app UI (auto-rebuilds CONF_DATA)
led_status.setHidden(false);     // show again (auto-rebuilds CONF_DATA)
led_status.hidden();             // query current state (bool)

slider.setLabelHidden(true);     // hide label only (widget still visible)
slider.setLabelHidden(false);    // show label again
slider.labelHidden();            // query current state (bool)
```

**Behavior:**
- `setHidden()` / `setLabelHidden()` auto-trigger CONF_DATA + VAR_DATA rebuild on next `update()` cycle
- Hidden widgets are excluded from all wire payloads (CONF_DATA, VAR_DATA, META_DATA)
- Hidden widgets are skipped in `update()` change detection (no shadow comparison)
- Hidden widgets are skipped in `_handleSetInput` (no incoming value deserialization)
- Page switch (`setActivePage()`) also respects hidden state — hidden widgets are excluded from the new page's CONF_DATA

### Status Methods

```cpp
RadioKit.isConnected()    // True if any transport has a peer
RadioKit.getRssi()        // Signal strength (BLE RSSI or WiFi equivalent)
RadioKit.widgetCount()    // Number of registered widgets
```

### Print API (transport-agnostic logging)

```cpp
RadioKit.print("Hello");
RadioKit.println("World");
RadioKit.printf("Temp: %.1f C\n", temp);
RadioKit.printFlush();  // Force-flush buffer immediately
```

Output is buffered into 0xEE frames and sent over all active transports. Displays in the Flutter app's console.

### Authentication

```cpp
// Set config in NVS (any param can be nullptr to skip)
RadioKit.setConfig("NewName", "NewDesc", "devicePass", "userPass");

// Authenticate (returns RK_PWD_AUTH_DEVICE/USER/DENIED)
uint8_t level = RadioKit.authenticate("password");

// Check state
RadioKit.isAuthenticated()  // Any auth succeeded (or no passwords set)
RadioKit.hasFullAccess()    // Device-level access granted
```

### Filesystem

```cpp
RadioKit.enableFS();        // Mount LittleFS (requires RK_ENABLE_FS)
RadioKit.beginFs();         // Alias for enableFS()
RadioKit.isFsReady();       // Check if mounted
RadioKit.formatFs();        // Format (destructive)
```

### NVS (Non-Volatile Storage)

```cpp
RKNvs::writeString("key", "value");
RKNvs::readString("key", buf, sizeof(buf));
RKNvs::writeU8("key", 42);
RKNvs::readU8("key", &val);
RKNvs::commit();            // Flush to flash
RKNvs::eraseAll();          // Factory reset
```

## Critical Rules

1. **`RadioKit.update()` MUST be called every `loop()` iteration** -- without it, no transport communication happens.
2. **Widgets are self-registering** -- declare as globals, never manually register.
3. **Config before `begin()`** -- set all `RadioKit.config.*` fields before calling `RadioKit.begin()`.
4. **Transports after `begin()`** -- call `startBLE()`, `startSerial()`, `startWiFi()`, `startCloud()` after `begin()`.
5. **Max 16 widgets** -- excess widgets are silently dropped.
6. **String fields must be `const char*`** -- point to string literals, not dynamically allocated buffers.
7. **Set `rk` fields directly** -- the library's shadow comparison detects changes and auto-pushes.
8. **NVS overrides compile-time config** -- after first boot, NVS is the source of truth.
9. **Mandatory Flash Erase on Upload** -- Every time code is uploaded to a target device (via PlatformIO, esptool, OTA, or app flasher), the upload MUST include the flash erase option (`-erase` / `eraseAll: true`) unless previous settings explicitly need to be preserved. This prevents stale NVS settings (such as old BLE advertised names or outdated WiFi credentials) from persisting and overriding new sketch code.

## Example Projects

| Example | Transport | Features |
|---------|-----------|----------|
| `BasicSwitch` | Serial (USB) | Minimal rocker switch + LED, Serial-only |
| `SerialSimple` | Serial | Minimal serial-only example for RP2040 |
| `JoystickMotor` | BLE | 2-axis joystick controlling motor |
| `SliderServo` | BLE | Slider mapped to servo angle |
| `BLE_RC_Truck` | BLE | Multi-widget RC controller |
| `Filesystem_LED` | BLE + FS | Filesystem with LED control |
| `FsCommandTest` | BLE + FS | FS REPLACE/CRC32 command testing |
| `WiFiCloudSwitch` | BLE + WiFi + Cloud | Full-stack cloud relay |
| `MultiPageController` | BLE | Multi-page UI demo |
