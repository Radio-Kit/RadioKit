---
name: radiokit-filesystem
description: Guide for using the RadioKit filesystem (LittleFS) on ESP32. Use this skill when implementing file storage, data logging, configuration persistence, or file management from firmware.
---

# RadioKit Filesystem

## Overview

RadioKit provides a built-in filesystem layer using LittleFS on ESP32. The companion Flutter app can browse, upload, download, and manage files on the device through the same transport used for widgets.

**Requirements**:
- ESP32 only (STM32, RP2040 not supported)
- Build flag: `-DRK_ENABLE_FS`
- `board_build.filesystem = littlefs` in platformio.ini

## Setup

### platformio.ini

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
board_build.filesystem = littlefs
build_flags =
    -DRK_ENABLE_FS
lib_deps =
    stevemejia/RadioKit@^2.0.0
```

### In Sketch

```cpp
#include "RADIOKIT.h"

void setup() {
  Serial.begin(115200);
  RadioKit.begin();
  RadioKit.startBLE("MyDevice");

  // Mount filesystem
  if (RadioKit.enableFS()) {
    RadioKit.println("FS mounted OK");
  } else {
    RadioKit.println("FS mount FAILED");
  }
}
```

## Filesystem API

### Mounting

```cpp
RadioKit.enableFS();     // Mount LittleFS, returns true on success
RadioKit.beginFs();      // Alias for enableFS()
RadioKit.isFsReady();    // Check if mounted
RadioKit.formatFs();     // Format + remount (destructive)
```

### Using LittleFS Directly

Once mounted, use the standard Arduino LittleFS API:

```cpp
#include <LittleFS.h>

// Write a file
File f = LittleFS.open("/data.txt", "w");
if (f) {
  f.println("Hello, filesystem!");
  f.close();
}

// Read a file
File f = LittleFS.open("/data.txt", "r");
if (f) {
  String content = f.readString();
  f.close();
}

// List directory
File root = LittleFS.open("/");
File file = root.openNextFile();
while (file) {
  RadioKit.println(file.name());
  file = root.openNextFile();
}

// Delete a file
LittleFS.remove("/data.txt");

// Check available space
size_t total = LittleFS.totalBytes();
size_t used = LittleFS.usedBytes();
```

## App-Initiated File Operations

The Flutter app can perform these operations remotely through the FS protocol (0xAA):

| Operation | Description |
|-----------|-------------|
| List | List files in a directory |
| Read | Read file content (with offset + length) |
| Write | Write data to file (at offset) |
| Delete | Delete file or directory |
| Mkdir | Create directory |
| Rename | Rename/move file |
| Upload | Stream file upload (begin/chunk/end) |
| Format | Format entire filesystem |
| Info | Get storage usage stats |
| CRC32 | Compute file checksum |

These are handled automatically by the RadioKit library. No firmware code needed.

## Data Logging Pattern

```cpp
#include <LittleFS.h>

RK_Telemetry logCount("log_entries");

void logData(float temperature, float humidity) {
  File f = LittleFS.open("/log.csv", "a");
  if (f) {
    unsigned long ts = millis();
    f.printf("%lu,%.1f,%.1f\n", ts, temperature, humidity);
    f.close();
  }
}

void setup() {
  RadioKit.begin();
  RadioKit.startBLE("Logger");
  RadioKit.enableFS();
  logCount.rk.icon = "file-text";
  logCount.rk.unit = "entries";
}

void loop() {
  RadioKit.update();

  // Log every 10 seconds
  static unsigned long lastLog = 0;
  if (millis() - lastLog > 10000) {
    logData(readTemp(), readHumidity());
    lastLog = millis();

    // Update telemetry
    File f = LittleFS.open("/log.csv", "r");
    if (f) {
      char buf[8];
      snprintf(buf, sizeof(buf), "%d", f.size() / 20);  // ~20 bytes per line
      logCount.rk.content = buf;
      f.close();
    }
  }
}
```

## Configuration Persistence Pattern

```cpp
#include <LittleFS.h>

struct DeviceConfig {
  int brightness;
  int sensitivity;
  char mode[16];
};

DeviceConfig config = {50, 75, "auto"};  // Defaults

void loadConfig() {
  File f = LittleFS.open("/config.dat", "r");
  if (f && f.size() == sizeof(DeviceConfig)) {
    f.read((uint8_t*)&config, sizeof(DeviceConfig));
    f.close();
  }
}

void saveConfig() {
  File f = LittleFS.open("/config.dat", "w");
  if (f) {
    f.write((uint8_t*)&config, sizeof(DeviceConfig));
    f.close();
  }
}

void setup() {
  RadioKit.begin();
  RadioKit.enableFS();
  loadConfig();
}

// Save when slider changes
RK_Slider brightnessSlider(20, 20, 15, 80);
RK_Slider sensitivitySlider(20, 50, 15, 80);

void loop() {
  RadioKit.update();

  if (brightnessSlider.rk.value != config.brightness) {
    config.brightness = brightnessSlider.rk.value;
    saveConfig();
  }
}
```

## JSON Configuration Pattern

```cpp
#include <LittleFS.h>

// Simple JSON read/write without external library
void saveJsonConfig() {
  File f = LittleFS.open("/settings.json", "w");
  if (f) {
    f.printf("{\"brightness\":%d,\"mode\":\"%s\"}",
             config.brightness, config.mode);
    f.close();
  }
}

void loadJsonConfig() {
  File f = LittleFS.open("/settings.json", "r");
  if (f) {
    String json = f.readString();
    f.close();
    // Parse manually or with ArduinoJson
  }
}
```

## Storage Limits

| ESP32 Variant | Flash | Usable FS |
|---------------|-------|-----------|
| ESP32 | 4MB | ~1.5MB |
| ESP32-S2 | 4MB | ~1.5MB |
| ESP32-S3 | 8MB | ~3.5MB |
| ESP32-C3 | 4MB | ~1.5MB |

## Best Practices

1. **Always close files** -- `f.close()` after read/write
2. **Check return values** -- `LittleFS.open()` returns empty File on failure
3. **Don't write too frequently** -- LittleFS has write cycle limits (~100K cycles per block)
4. **Use binary mode** for structured data (`"w"` vs `"wb"`)
5. **Buffer writes** -- Write in chunks, not byte-by-byte
6. **Mount early** -- Call `enableFS()` in `setup()` before any file operations
7. **Handle corruption** -- `formatFs()` is the nuclear option for corrupted filesystems

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `enableFS()` returns false | Flash not formatted | Call `RadioKit.formatFs()` once |
| Files disappear after OTA | OTA erases FS by default | Check erase flag in OTA protocol |
| Upload fails mid-transfer | Not enough space | Check `LittleFS.totalBytes() - LittleFS.usedBytes()` |
| Read returns garbage | File not closed properly | Ensure `f.close()` after writes |
