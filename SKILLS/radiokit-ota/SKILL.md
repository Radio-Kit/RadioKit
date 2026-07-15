---
name: radiokit-ota
description: Guide for over-the-air (OTA) firmware updates with RadioKit. Use this skill when implementing OTA support, managing firmware versions, or handling update failures.
---

# RadioKit OTA (Over-The-Air Updates)

## Overview

RadioKit provides built-in OTA firmware updates. The companion Flutter app can upload new firmware to the device over BLE, WiFi, or Cloud transport. The library handles the entire update protocol internally.

**Requirements**:
- ESP32 only (STM32, RP2040 not supported)
- Build flag: `-DRK_ENABLE_OTA`
- Custom partition table with OTA slots

## Setup

### platformio.ini

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
board_build.partitions = partitions_ota_4MB.csv
build_flags =
    -DRK_ENABLE_OTA
lib_deps =
    stevemejia/RadioKit@^2.0.0
```

### In Sketch

OTA is handled entirely by the library. No firmware code needed beyond the build flag.

```cpp
#include "RADIOKIT.h"

void setup() {
  Serial.begin(115200);
  RadioKit.begin();
  RadioKit.startBLE("MyDevice");
  // OTA is now active -- app can push firmware
}

void loop() {
  RadioKit.update();
}
```

## How It Works

1. **App initiates update** -- Sends `OTA_BEGIN` with firmware size
2. **Device prepares** -- Calls `Update.begin(size)` (ESP32 Arduino core)
3. **App sends chunks** -- `OTA_CHUNK` frames with offset + data
4. **Device writes** -- `Update.write()` for each chunk, sends ACK
5. **App sends CRC** -- `OTA_END` with CRC32 checksum
6. **Device verifies** -- `Update.end()`, sets boot partition, reboots

## OTA Protocol (0xBB)

| Sub-Command | Code | Direction | Payload |
|---|---|---|---|
| `BEGIN` | 0x01 | App->MCU | Firmware size (4 bytes LE) |
| `CHUNK` | 0x02 | App->MCU | Offset (4 bytes LE) + data |
| `END` | 0x03 | App->MCU | CRC32 (4 bytes LE) |
| `ABORT` | 0x04 | App->MCU | (empty) |
| `SET_ERASE_FLAG` | 0x05 | App->MCU | Mode (1 byte) |
| `ACK` | 0x81 | MCU->App | Error code (1 byte) |
| `PROGRESS` | 0x82 | MCU->App | Received (4) + Total (4) bytes |

## Erase Modes

The `SET_ERASE_FLAG` command sets an NVS flag before reboot:

| Mode | Code | Description |
|------|------|-------------|
| None | 0 | Don't erase anything |
| Both | 1 | Erase NVS + FS |
| NVS only | 2 | Erase NVS only |
| FS only | 3 | Erase FS only |

This allows the app to clean up stored credentials or files after an update.

## Error Handling

| Error | Code | Description |
|-------|------|-------------|
| OK | 0 | Success |
| No Space | 1 | Not enough flash space |
| CRC | 2 | Checksum mismatch |
| Flash | 3 | Flash write error |
| Sequence | 4 | Out-of-order chunks |
| Invalid State | 5 | Update not in progress |
| Not Supported | 6 | OTA not compiled in |

## Firmware Version Management

Always update `RadioKit.config.version` when releasing new firmware:

```cpp
RadioKit.config.version = "1.2.0";  // Semantic versioning
```

The app can read this via the settings protocol to check for updates.

## Partition Table

For 4MB ESP32, use this partition layout:

```csv
# Name,   Type, SubType, Offset,  Size,    Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x140000,
app1,     app,  ota_1,   0x150000,0x140000,
spiffs,   data, spiffs,  0x290000,0x170000,
```

This gives:
- ~1.25MB per app slot (enough for most RadioKit sketches)
- ~1.4MB for filesystem
- OTA toggles between app0 and app1

## Best Practices

1. **Test OTA locally first** -- Use Serial transport for initial development
2. **Include version in UI** -- Show firmware version in the app's device info
3. **Handle failures gracefully** -- OTA can fail mid-transfer (network drop, power loss). The device will remain on the old firmware.
4. **Don't erase FS by default** -- Only erase if the update changes the data schema
5. **Use CRC verification** -- The library handles this automatically
6. **Keep a serial fallback** -- If OTA fails completely, Serial can recover the device
