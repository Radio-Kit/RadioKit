---
name: radiokit-transport
description: Guide for developing or modifying transport layer implementations in RadioKit. This skill should be used when working on BLE, Serial, WiFi, or Cloud transports on either the Arduino (C++) or Flutter (Dart) side, or when modifying the frame protocol.
---

# RadioKit Transport Layer Development

## Overview

This skill covers the transport layer architecture that enables communication between ESP32 devices and the Flutter companion app. Transports are pluggable — BLE, Serial, WiFi, and Cloud can run simultaneously. The same frame protocol is used across all transports.

## Architecture

```
ESP32 (rk-arduino)                    Flutter (radiokit-app)
┌─────────────────┐                   ┌─────────────────────┐
│  Widget Layer    │                   │  Control Screen      │
│  (rk fields)     │                   │  (widget UI)         │
├─────────────────┤                   ├─────────────────────┤
│  Protocol Layer  │  ←── frames ──→  │  ProtocolService     │
│  (RadioKitProtocol)                 │  (protocol_service)  │
├─────────────────┤                   ├─────────────────────┤
│  Transport Layer │  ←── bytes ───→  │  TransportService    │
│  BLE / WiFi /    │                   │  (abstract class)    │
│  Serial / Cloud  │                   │                      │
└─────────────────┘                   └─────────────────────┘
```

## Frame Protocol

All transports use the same binary frame format:

```
[type] [sub] [len_hi] [len_lo] [payload...]
  1B     1B     1B        1B      0-16384B
```

### Frame Types

| Type | Name | Direction | Purpose |
|------|------|-----------|---------|
| 0x01 | WIDGET | Bidirectional | Widget state sync |
| 0x02 | WIDGET_INIT | Device→App | Full widget state on connect |
| 0xAA | FS | Bidirectional | Filesystem operations |
| 0xBB | OTA | App→Device | Firmware update |
| 0xCC | SETTINGS | Bidirectional | Device config (name, theme, etc.) |
| 0xDD | INFO | Device→App | Device info response |
| 0xEE | PRINT | Device→App | Debug/console output |
| 0xFF | AUTH | Bidirectional | Password authentication |

### FS Sub-commands (0xAA)

| Sub | Name | Direction |
|-----|------|-----------|
| 0x01 | LIST | App→Device |
| 0x02 | READ | App→Device |
| 0x03 | WRITE | App→Device |
| 0x04 | DELETE | App→Device |
| 0x05 | MKDIR | App→Device |
| 0x06 | RENAME | App→Device |
| 0x07 | FORMAT | App→Device |
| 0x08 | REPLACE | App→Device |
| 0x09 | CRC32 | App→Device |
| 0x80+ | (responses) | Device→App |

## Arduino-Side Transports & Command Architecture

### Directory Structure

```
rk-arduino/src/
  core/
    ICommandHandler.h      # Command handler interface contract
    CommandDispatcher.h/.cpp # Header-based command routing engine
    TransportManager.h/.cpp  # Multi-transport registration and broadcasting
  handlers/
    ControlCommandHandler.h/.cpp  # 0x55 Widget control command handler
    SettingsCommandHandler.h/.cpp # 0xDD Settings command handler
    FsCommandHandler.h/.cpp       # 0xAA Filesystem command handler
    OtaCommandHandler.h/.cpp      # 0xBB OTA firmware update handler
    PrintCommandHandler.h/.cpp    # 0xEE Print/log output handler
  connection/
    RadioKitTransport.h    # Base transport interface
    RadioKitBLE.h/.cpp     # NimBLE-Arduino BLE transport
    RadioKitSerial.h/.cpp  # Serial/UART transport
    RadioKitWiFi.h/.cpp    # WebSocket server transport
    RadioKitCloud.h/.cpp   # Cloud relay WebSocket client
```

### Modular Command Dispatching

Commands are routed by `CommandDispatcher` based on frame header command bytes:

```cpp
// Registering a command handler with CommandDispatcher
CommandDispatcher::instance().registerHandler(0x55, &controlHandler);
CommandDispatcher::instance().registerHandler(0xAA, &fsHandler);

// TransportManager handles multi-transport management and frame broadcast
TransportManager::instance().registerTransport(&RadioKitBLEInstance);
TransportManager::instance().sendPacket(pktBuf, pktLen);
```

### Transport Interface

```cpp
class RadioKitTransport {
public:
  virtual void begin() = 0;
  virtual void update() = 0;
  virtual bool isConnected() = 0;
  virtual void sendPacket(const uint8_t* data, uint8_t len) = 0;
  virtual void disconnect() = 0;
};
```

### BLE Transport (RadioKitBLE)

- Uses NimBLE-Arduino library
- 6 BLE characteristics for different protocols
- Advertising name prefixed with `RK_`
- MTU negotiation: requests 512, uses `_negotiatedMtu - 3` for notify chunks
- Re-entrant send guard: queues packets in `_pendingBuf[16388]` if a send is in progress
- Retry: 10 attempts with linear backoff (10ms to 250ms)
- Pacing: `delay(_connIntervalMs * 5)` between multi-notification chunks

### WiFi Transport (RadioKitWiFi)

- WebSocket server on port 5555
- AP mode: SSID `RK_<name>` (always open, auth via PWD_AUTH)
- STA mode: connects to configured network
- mDNS advertising: `_radiokit._tcp`
- Requires `-D RADIOKIT_ENABLE_WIFI` build flag

### Cloud Transport (RadioKitCloud)

- WebSocket client to Rust relay server
- Ed25519 challenge-response authentication
- Auto-reconnect with exponential backoff
- Requires WiFi + `-D RADIOKIT_ENABLE_WIFI`

### Serial Transport (RadioKitSerial)

- Works with any Arduino `Stream`
- Recommended baud: 1000000
- Connection detection: 3s timeout after last packet

## Flutter-Side Transports

### Transport Interface

```dart
abstract class TransportService {
  Future<void> connect();
  Future<void> disconnect();
  bool get isConnected;
  Stream<Uint8List> get onData;
  Future<void> send(Uint8List data);
}
```

### Transport Implementations

```
radiokit-app/lib/services/
  ble_transport.dart          # BLE via universal_ble
  ble_service_impl.dart       # BLE service wrapper
  serial_service_flserial.dart # Linux serial via flserial
  serial_service_fsc.dart     # Flutter Serial Communication
  serial_service_raw_usb.dart # Android raw USB
  serial_service_web.dart     # Web Serial API
  websocket_service.dart      # WiFi/Cloud WebSocket
  demo_transport.dart         # In-memory demo transport
  debug_transport.dart        # Debug/testing transport
```

### ProtocolService

`ProtocolService` (in `protocol_service.dart`) handles frame parsing on the Flutter side:

```dart
class ProtocolService {
  void onFrame(Uint8List frame);  // Parse incoming frames
  // Dispatches to widget state, FS responses, auth, etc.
}
```

## Multi-Transport

Multiple transports run simultaneously on the Arduino side. `RadioKit.isConnected()` returns true if ANY transport is connected. Packets are broadcast to all connected transports.

```cpp
RadioKit.startBLE("Device");
RadioKit.startSerial(Serial);
RadioKit.startWiFi();  // All three active simultaneously
```

## Authentication Flow

```
App sends AUTH frame (0xFF) with password
Device validates:
  - Full access (device password) → 0x00
  - Widgets-only (user password) → 0x01
  - Denied → 0x02
Auth resets on transport disconnect
```

## Key Implementation Details

1. **Packet size limit**: `RK_MAX_PACKET_SIZE = 768` bytes (BLE), up to 16KB for FS operations
2. **MTU chunking**: BLE notifications are chunked to `_negotiatedMtu - 3` bytes
3. **Re-entrant safety**: BLE send uses a `_sending` guard with pending buffer queue
4. **Connection detection**: Each transport has its own timeout mechanism
5. **Frame routing**: Sub-command byte at position 1 routes FS/OTA/Settings/Print frames
6. **Shadow comparison**: Widget state is compared byte-level before sending to avoid redundant frames
