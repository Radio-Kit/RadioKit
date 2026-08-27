---
name: radiokit-transports
description: Guide for using RadioKit transport layers (BLE, Serial, WiFi, Cloud). Use this skill when configuring connectivity, debugging transport issues, or building multi-transport firmware.
---

# RadioKit Transports

## Overview

RadioKit supports four transport layers. Each runs independently and can be active simultaneously. All outgoing packets are broadcast to all active transports.

| Transport | Protocol | Direction | Range | Auth |
|-----------|----------|-----------|-------|------|
| BLE | NimBLE | Bidirectional | ~10m | Password-based |
| Serial | UART/USB | Bidirectional | Wired | Bypass (physical access) |
| WiFi | WebSocket | Bidirectional | LAN/Internet | Password-based |
| Cloud | WSS Relay | Bidirectional | Global | Ed25519 challenge-response |

## BLE Transport (Default)

Always available. No build flags required.

```cpp
void setup() {
  RadioKit.begin();
  RadioKit.startBLE();                // Uses config.name
  RadioKit.startBLE("CustomName");    // Override advertised name
}
```

**Characteristics** (service `0000FFE0`):
| UUID | Purpose | Direction |
|------|---------|-----------|
| `0xFFE1` | Widget protocol (0x55) | Bidirectional |
| `0xFFE2` | Filesystem (0xAA) | Bidirectional |
| `0xFFE3` | OTA (0xBB) | Bidirectional |
| `0xFFE4` | Settings (0xDD) | Bidirectional |
| `0xFFE5` | Print stream (0xEE) | Device -> App |

**Behavior**:
- Advertised name is prefixed with `RK_` (e.g., `RK_MyDevice`)
- MTU negotiated on connect (default 20, up to 517)
- Connection interval reported via `getConnIntervalMs()`
- Pending buffer for re-entrant writes (16KB) prevents dropped frames during flash operations
- Deferred FS/OTA processing to avoid blocking NimBLE host task

**Status methods**:
```cpp
RadioKitBLE.getNegotiatedMtu()   // Current MTU
RadioKitBLE.getConnIntervalMs()  // Connection interval in ms
RadioKitBLE.updateAdvertisingName("NewName");  // Change name at runtime
```

## Serial Transport

Always available. No build flags required.

```cpp
void setup() {
  Serial.begin(115200);
  RadioKit.begin();
  RadioKit.startSerial(Serial);       // Use HardwareSerial
  RadioKit.startSerial(Serial1);      // Use second UART
}
```

**Behavior**:
- Wraps any Arduino `Stream` (Serial, Serial1, SoftwareSerial, etc.)
- Connection timeout: 30 seconds (no data = disconnect)
- Serial source **bypasses all auth gates** -- physical access = full access
- Uses same framing protocol as BLE (0x55 header)

**Use cases**:
- STM32 / RP2040 (BLE not available)
- Debug console
- Wired controllers
- USB CDC connections

## WiFi Transport

Requires `-DRK_ENABLE_WIFI` build flag.

```cpp
void setup() {
  RadioKit.config.sta_ssid = "MyWiFi";
  RadioKit.config.sta_password = "MyPassword";
  RadioKit.begin();
  RadioKit.startWiFi();
}
```

**Behavior**:
- WebSocket server on port 5555
- **AP mode**: SSID `RK_<device_name>`, open (auth via PWD_AUTH protocol)
- **STA mode**: Connects to configured network, falls back to AP if connection fails
- mDNS: `_radiokit._tcp` (discoverable on LAN)
- Max 4 concurrent clients, 30s auth timeout per client
- Auto-reconnect STA with exponential backoff

**Status methods**:
```cpp
RadioKitWiFi.isApMode()          // True if in AP mode
RadioKitWiFi.getLocalIp()        // Current IP address
RadioKitWiFi.getClientAuthLevel(clientNum)  // Auth level of client
```

**WiFi setup patterns**:

*AP-only mode* (no STA credentials):
```cpp
RadioKit.config.name = "MyDevice";
RadioKit.begin();
RadioKit.startWiFi();  // Creates AP "RK_MyDevice"
```

*STA + fallback to AP*:
```cpp
RadioKit.config.sta_ssid = "HomeWiFi";
RadioKit.config.sta_password = "password";
RadioKit.begin();
RadioKit.startWiFi();  // Tries STA, falls back to AP
```

*STA-only mode* (no AP fallback):
```cpp
RadioKit.config.sta_ssid = "HomeWiFi";
RadioKit.config.sta_password = "password";
RadioKit.begin();
RadioKit.startWiFi();
// Note: AP is always created as fallback for auth
```

**Runtime WiFi config** (via NVS):
```cpp
RKNvs::writeString("rk_sta_ssid", "NewSSID");
RKNvs::writeString("rk_sta_pwd", "NewPassword");
RKNvs::commit();
// Reboot to apply
```

## Cloud Transport

Requires `-DRK_ENABLE_WIFI -DRK_ENABLE_CLOUD` build flags. WiFi must be started first.

```cpp
void setup() {
  RadioKit.config.sta_ssid = "MyWiFi";
  RadioKit.config.sta_password = "password";
  RadioKit.config.cloud_url = "wss://relay.example.com:443";
  RadioKit.config.cloud_account = "64char_hex_public_key";
  RadioKit.begin();
  RadioKit.startWiFi();
  RadioKit.startCloud();  // After startWiFi()
}
```

**Behavior**:
- Outbound WebSocket client (WSS) to relay server
- Auto-registers device on connect using public key as identity
- 30s heartbeat ping
- Auto-reconnect with exponential backoff (1s -> 60s max)
- Bidirectional frame relay through Rust relay server

**Auth flow**:
1. Device connects to relay via WSS
2. Sends registration with public key as identity
3. Relay pairs device with the Flutter app account
4. Frames relay bidirectionally

**Status methods**:
```cpp
RadioKitCloud.isRegistered()  // True if registered with relay
RadioKitCloud.setCloudUrl("wss://new-relay:443");
RadioKitCloud.setAccount("new_pubkey_hex");
```

## Multi-Transport Setup

All transports can run simultaneously. Broadcast goes to all:

```cpp
void setup() {
  Serial.begin(115200);
  RadioKit.config.name = "MultiTransport";
  RadioKit.config.sta_ssid = "WiFi";
  RadioKit.config.sta_password = "pass";
  RadioKit.config.cloud_url = "wss://relay.example.com";
  RadioKit.config.cloud_account = "abc123...";

  initRadioKit();
  RadioKit.begin();

  RadioKit.startSerial(Serial);  // Wired debug
  RadioKit.startBLE();           // Wireless nearby
  RadioKit.startWiFi();          // LAN control
  RadioKit.startCloud();         // Remote access
}
```

**Recommended priority**: Serial -> BLE -> WiFi -> Cloud

## Transport Selection Guide

| Scenario | Recommended Transport |
|----------|----------------------|
| Quick prototyping | Serial |
| Mobile app nearby | BLE |
| LAN controller | WiFi |
| Remote access | WiFi + Cloud |
| STM32 / RP2040 | Serial |
| Battery-powered | BLE (lower power) |
| High throughput | WiFi |

## Authentication

### Two-tier model

| Level | Set By | Access |
|-------|--------|--------|
| Device | `RadioKit.setConfig(..., "devicePass", ...)` | Full: config, FS, OTA, factory reset |
| User | `RadioKit.setConfig(..., ..., "userPass")` | Widgets only |

Serial bypasses all auth. BLE and WiFi require password authentication.

### Setting passwords

```cpp
// In setup, after RadioKit.begin():
RadioKit.setConfig(nullptr, nullptr, "device_secret", "user_secret");
```

### Runtime auth check

```cpp
void loop() {
  RadioKit.update();

  if (RadioKit.hasFullAccess()) {
    // Device-level operations allowed
  }

  if (RadioKit.isAuthenticated()) {
    // Any level of auth
  }
}
```

## Debugging Transports

### Check connection status

```cpp
if (RadioKit.isConnected()) {
  Serial.println("A client is connected");
  Serial.print("RSSI: ");
  Serial.println(RadioKit.getRssi());
}
```

### Print API for debugging

```cpp
RadioKit.println("Sensor reading:");
RadioKit.printf("Temperature: %.1f C\n", temp);
RadioKit.printf("Battery: %d%%\n", battery);
```

Output appears in the Flutter app's console tab.

### WiFi info request (from app)

The app can request WiFi status:
- Signal strength
- IP address
- Connection mode (AP/STA)
- Client count

## Platform Support Matrix

| Feature | ESP32 | STM32 | RP2040 |
|---------|-------|-------|--------|
| BLE | Yes | No | No |
| Serial | Yes | Yes | Yes |
| WiFi | Yes | No | Pico W only |
| Cloud | Yes | No | Pico W only |
| OTA | Yes | No | No |
| Filesystem | Yes | No | No |
| NVS | Yes | No | No |
