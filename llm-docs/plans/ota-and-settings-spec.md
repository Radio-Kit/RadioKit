# BLE OTA + Model Settings — Specification

## Overview

Implement two features:
1. **BLE OTA firmware updates** using a custom protocol (own prefix byte `0xBB`) over the existing BLE transport, instead of NimBLEOta (which cannot share the existing NimBLEServer)
2. **Model Settings in the Designer UI** — Enable OTA and Enable Filesystem toggles stored as a top-level `features` key in the JSON config

---

## Part 1: Custom OTA Protocol (Prefix `0xBB`)

### 1.1 Rationale
- NimBLEOta (`h2zero/NimBLEOta`) creates its own `NimBLEServer` internally — it cannot attach to our existing server (service `0xFFE0`).
- Running two independent BLE servers on one ESP32 is problematic (only one can advertise at a time).
- **Solution**: A custom OTA protocol with its own prefix byte (`0xBB`), following the same architecture as the FS protocol (`0xAA`).
- Benefits: no external library dependency, works over BLE and Serial, reuses existing transport infra.

### 1.2 Protocol Frame Format

OT framing follows the same pattern as FS (`RadioKitFS.h/cpp`) but with a different start byte:

```
[0xBB] [subCmd(1)] [len(2 LE)] [payload...] [crc16(2 LE)]
```
- **Start byte**: `0xBB`
- **subCmd**: operation code (listed below)
- **len**: payload length (2 bytes, little-endian)
- **payload**: operation-specific data
- **crc16**: CCITT CRC-16 over header + payload (2 bytes, little-endian)

### 1.3 Sub-Commands

| SubCmd | Name | Direction | Payload |
|--------|------|-----------|---------|
| `0x01` | OTA_BEGIN | App → Device | [firmwareSize(4 LE)] |
| `0x02` | OTA_CHUNK | App → Device | [offset(4 LE)] [data...] |
| `0x03` | OTA_END | App → Device | [crc32(4 LE)] |
| `0x04` | OTA_ABORT | App → Device | (empty) |
| `0x81` | OTA_ACK | Device → App | [errorCode(1)] |
| `0x82` | OTA_PROGRESS | Device → App | [received(4 LE)] [total(4 LE)] |

- OTA_PROGRESS fires every **5% progress change or every 50 chunks**, whichever comes first. At 4KB chunks and 1MB firmware (~256 chunks), this generates ~20 progress notifications — enough for a smooth progress bar without excessive BLE traffic.
- Response sub-cmds set bit 7 (0x80) — same `ACK-mask` pattern as the FS protocol.
- OTA frames are dispatched via a dedicated parser (`rk_otaRxFeedByte`), parallel to the widget (`0x55`) and FS (`0xAA`) parsers. All three parsers share the same byte stream in `RadioKitBLE::_onWrite()`.

### 1.4 Arduino Side (ESP32 Firmware)

#### 1.4.1 File Layout
```
src/connection/
  RadioKitOTA.h        # OTA transport declarations, parser, frame builder
  RadioKitOTA.cpp      # OTA implementation using ESP32 Update.h
```

- **No NimBLEOta dependency.** Uses `esp_ota_ops.h` / `Update.h` directly.
- OTA operations are **not transport-layer callbacks** — they live one level above the transport, in `RadioKit.cpp`'s `_onPacket`/`_onFsPacket`/`_onOtaPacket` dispatch.

#### 1.4.2 Parser Integration

In `RadioKitBLE::_onWrite()`, the byte dispatch currently handles:
- `0x55` → widget parser (`rk_rxFeedByte`)
- `0xAA` → FS parser (`rk_fsRxFeedByte`)

Add:
- `0xBB` → OTA parser (`rk_otaRxFeedByte`)

Same rules apply: if a parser is mid-frame, all bytes go to that parser exclusively.

> **Dispatch priority** (when no parser is active): Widget (`0x55`) → FS (`0xAA`) → OTA (`0xBB`). Widget is real-time control traffic, FS is bulk data, OTA is rare. This ordering ensures control responsiveness during file transfers. The `_onWrite()` dispatch checks `rk_rxIsActive()` first, then `rk_fsRxIsActive()`, then `rk_otaRxIsActive()`.

#### 1.4.3 OTA Handler (RadioKit.cpp)

```cpp
void RadioKitClass::_onOtaPacket(uint8_t subCmd,
                                 const uint8_t* payload,
                                 uint16_t payloadLen) {
    switch (subCmd) {
        case RK_OTA_BEGIN:  _handleOtaBegin(payload, payloadLen);  break;
        case RK_OTA_CHUNK:  _handleOtaChunk(payload, payloadLen);  break;
        case RK_OTA_END:    _handleOtaEnd(payload, payloadLen);    break;
        case RK_OTA_ABORT:  _handleOtaAbort();                     break;
    }
}
```

#### 1.4.4 OTA Begin Handler
- Receives `firmwareSize` (4 bytes LE).
- Calls `Update.begin(firmwareSize)`.
- If successful: sends `OTA_ACK` with error code 0.
- If insufficient space: sends `OTA_ACK` with error code `ERR_NO_SPACE`.

#### 1.4.5 OTA Chunk Handler
- Receives `offset` (4 bytes LE) + `data[...]`.
- Validates `offset` matches expected next offset (sequential delivery check). If mismatch, sends `OTA_ACK` with error code `ERR_SEQ`.
- Calls `Update.write(data, len)`.
- Sends `OTA_ACK` with error code 0 on success.
- Sends `OTA_PROGRESS` notifications periodically (every 5% progress change or every 50 chunks, whichever comes first).

#### 1.4.6 OTA End Handler
- Receives `crc32` (4 bytes LE) of the full firmware.
- Calls `Update.end()`.
- If CRC matches: sends `OTA_ACK(0)`, then calls `esp_restart()` immediately.
- If CRC mismatch: sends `OTA_ACK(ERR_CRC)`, calls `Update.abort()` to clean up the OTA partition, then calls `esp_restart()` to reboot into the old firmware. Without this reboot, the OTA partition is in an inconsistent state and subsequent OTA attempts will fail.

**Error recovery**: If any chunk transfer fails mid-way (timeout, flash error), `Update.abort()` must be called to release the OTA partition. The device does NOT reboot — it returns to normal operation and can accept a new OTA_BEGIN.

#### 1.4.7 Cancel/Abort Mid-Transfer
- On the Flutter side, the progress overlay has a cancel button.
- On cancel, send `OTA_ABORT` and stop the chunk loop.
- On the ESP32 side: `OTA_ABORT` handler calls `Update.abort()` to release the OTA partition, then returns to normal operation (does NOT reboot).
- After cancel, the device is ready to accept a new OTA_BEGIN.

#### 1.4.8 Compile-Time Guard

```cpp
// RadioKitConfig.h
#define RADIOKIT_FEATURE_OTA
```

When defined, `RadioKit.cpp` includes OTA dispatch and handlers. When not defined, OTA code is excluded (saves flash).

### 1.5 Flutter Side (RadioKit App)

#### 1.5.1 Protocol Constants
- Add `kOtaStartByte = 0xBB` to `protocol.dart`.
- Add sub-command constants: `kOtaBegin`, `kOtaChunk`, `kOtaEnd`, `kOtaAbort`, `kOtaAck`, `kOtaProgress`.
- Add error codes: `kOtaErrOk`, `kOtaErrNoSpace`, `kOtaErrCrc`, `kOtaErrFlash`.

#### 1.5.2 Protocol Service (OtaProtocolService)
New file: `flutter-app/lib/services/ota_protocol_service.dart`
- `buildOtaBegin(int firmwareSize)` → `Uint8List` frame
- `buildOtaChunk(int offset, Uint8List data)` → `Uint8List` frame
- `buildOtaEnd(int crc32)` → `Uint8List` frame
- `buildOtaAbort()` → `Uint8List` frame
- `parseOtaAck(Uint8List payload)` → `int?` error code
- `parseOtaProgress(Uint8List payload)` → `(int received, int total)?`

#### 1.5.3 DeviceProvider — OTA Methods
- Add `_handleOtaPacket()` → dispatched from `_handleFsPacket` companion (or separate `_handleOtaPacket` callback in transport).
- Add `sendOtaBegin(int size)`, `sendOtaChunk(int offset, Uint8List data)`, `sendOtaEnd(int crc32)` methods.
- Add `Future<bool> uploadFirmware(Uint8List firmware, void Function(int, int)? onProgress)` — orchestrates the full flow.
- Progress callback reports `(bytesSent, total)` for the progress bar.

#### 1.5.4 Active Link Card — UPDATE FIRMWARE Button
- In `_ActiveLinkSection` (`models_tab.dart`), add a button when `deviceProvider.hasOta`:
  - Label: "UPDATE FIRMWARE"
  - Icon: `Icons.system_update_alt_rounded`
  - Style: `OutlinedButton.icon` matching FILESYSTEM button aesthetics
  - Position: Below FILESYSTEM button (if FS also enabled) or standalone

#### 1.5.5 OTA Flow (Flutter)

```
User taps UPDATE FIRMWARE
  → File picker opens (.bin files)
  → User selects firmware file
  → Send OTA_BEGIN (total size)
  → If ACK(OK):
      → Loop: send OTA_CHUNK (4096 bytes each)
      → Update progress bar (percentage + KB/s)
      → On each chunk ACK, send next chunk
      → Per-chunk timeout: 10s, retry up to 3×
      → On 3× timeout → OTA_ABORT + error dialog
  → Send OTA_END (CRC32 of whole file)
  → If ACK(OK):
      → Show "Verifying..." → "Rebooting..."
      → Start scanning for device to re-advertise
      → Auto-reconnect (see §1.5.7)
  → If ERR_CRC:
      → ESP32 called Update.abort() + esp_restart()
      → Show "CRC mismatch — device rebooting, try again"
  → If any other error:
      → Show error dialog with retry option
```

- Chunk size: **4096 bytes** (matching FS read/write chunk size for consistency).
- CRC32: computed client-side before sending (same `zlib.crc32` algorithm as FS upload).
- **Serial (not pipelined)**: Each chunk waits for an ACK before sending the next. Pipelining would save ~35ms per chunk (~9-18s for 1-2MB) but adds significant complexity for error recovery. For firmware OTA, reliability trumps speed.

#### 1.5.6 Progress UI
- Modal overlay with:
  - `LinearProgressIndicator` (percentage)
  - Transfer speed (KB/s) calculated from bytes/time
  - Status text: "Uploading firmware..." → "Verifying..." → "Rebooting..."
  - A cancel button that sends `OTA_ABORT`
  - Styled consistently with FS transfer status bar

#### 1.5.7 Post-OTA Auto-Reconnect
- Add `DeviceConnectionState.otaRebooting` state to the connection state machine.
- After `OTA_END` ACK with success:
  1. Show "Rebooting..." status
  2. Wait for device disconnection (BLE drops)
  3. Start scanning for device — **scan strategy**:
     a. First: scan by original MAC address (if available on this platform)
     b. Fallback: scan by device name prefix (RK_*)
     c. Last resort: scan for any RadioKit device advertising the FFE0 service
  4. Set a 30s timeout
  5. If device found: auto-connect using same `connectToDevice()` flow
  6. If timeout: show "Device didn't come back — tap to reconnect"

> ⚠️ **Edge case**: ESP32 can use random BLE addresses that change on reboot. If MAC-based scanning fails, the name-prefix fallback handles this. On iOS, peripheral identifiers persist across reboots — use the original peripheral ID for reconnection.

- Add a cancel button to the "Rebooting..." screen that exits the otaRebooting state and returns to the models screen.

#### 1.5.8 HTTP API (Deferred)
- `POST /api/ota/upload` — accepts `{"data": "<base64_firmware>"}`
- Relays firmware to ESP32 using the same `uploadFirmware()` method
- Returns progress/status during the operation
- **Deferred to a later phase** — not part of v1 implementation

---

## Part 2: Model Settings in Designer UI

### 2.1 JSON Schema Changes

Add `features` as a **top-level key** in the JSON config:

```json
{
  "version": 1,
  "config": { ... },
  "canvas": { ... },
  "widgets": [ ... ],
  "features": {
    "ota": false,
    "filesystem": false
  }
}
```

- `ota`: bool, default false. Whether the firmware includes OTA support.
- `filesystem`: bool, default false. Whether the firmware includes filesystem support.
- These are **config annotations for firmware code generation** — they control what code is emitted in `RadioKit_UI.h`.
- Future features can be added by extending the `features` object.

### 2.2 DesignerState Changes (flutter-library)

- Add `Map<String, dynamic> _features = {'ota': false, 'filesystem': false};` field.
- Add getters: `bool get featureOta`, `bool get featureFilesystem`.
- Add setters: `void setFeatureOta(bool v)`, `void setFeatureFilesystem(bool v)`.
- Each setter calls `_pushUndo()` first then updates the map.
- **Undo semantics**: Feature toggles are NOT undoable (same pattern as `_connectionType`, `_modelName`). The undo stack only snapshots `_elements` — model-level config changes do not push undo. Call `_mutationCount++` so unsaved-changes detection works.
- Include `features` in `toJson()` and `loadFromJson()`.

### 2.3 DesignerInspector — New FEATURES Section

Add a new section to the inspector panel when **no widget is selected** (the "Model Settings" view):

```
┌───────────────────── FEATURES ──────────────────────┐
│                                                       │
│   [Enable OTA] .................. toggle (✔)          │
│   Only available for BLE transport                     │
│                                                       │
│   [Enable Filesystem] ........... toggle               │
│   Include LittleFS support                              │
│                                                       │
└───────────────────────────────────────────────────────┘
```

- Placement: Below CANVAS section, before widget-specific sections.
- Styled using `InspectorFieldBuilders.buildSection(tokens, 'FEATURES', [...])`.
- OTA toggle: disabled/grayed out when `state.connectionType != 'ble'` (OTA only works over BLE).
- Each toggle shows a descriptive subtitle below, with a help icon tooltip.

### 2.4 Feature Detection Protocol

#### 2.4.1 Widget Protocol Command
- Add `RK_CMD_GET_FEATURES = 0x15` to `RadioKitProtocol.h`.
- Response: `RK_CMD_FEATURES_DATA = 0x16` (response immediately after request — keeps pair visually adjacent).
- Payload: 1-byte bitmask:
  - Bit 0: OTA supported (1 = yes)
  - Bits 1-7: reserved for future features

#### 2.4.2 Flutter Protocol Constants
- Add `kCmdGetFeatures = 0x15`, `kCmdFeaturesData = 0x16` to `protocol.dart`.
- Add `buildGetFeatures()` to `ProtocolService`.

#### 2.4.3 DeviceProvider — Feature Detection
- Add `_handleFeaturesData()` — parses 1-byte payload, stores `_deviceFeatures`.
- Add `sendGetFeatures()` — Completer-based with 3s timeout (same pattern as `sendGetBleInfo()`).
- Add `bool get hasOta => (_deviceFeatures & 0x01) != 0`.
- Call `unawaited(sendGetFeatures())` after config loads — **fire-and-forget**, don't block connection flow.
- On timeout (old firmware that doesn't support `0x15`): return null, `hasOta` stays false — **button hidden entirely**.
- Add `case kCmdFeaturesData:` to `_handlePacket()` dispatch.

### 2.5 Code Generation Impact

- `JsonArduinoGenerator.generate()` reads `features` from JSON config top-level.
- When `filesystem: true`, includes:
  - `#include <LittleFS.h>`
  - `RKFs::begin()` and FS initialization code
  - `_transport->setFsCallback(...)` in `startBLE()`/`startSerial()`
- When `ota: true`, includes:
  - `#include "connection/RadioKitOTA.h"`
  - `rk_otaInit(...)` in initialization
  - `_transport->setOtaCallback(...)` for dispatch
  - `#define RADIOKIT_FEATURE_OTA`
- When both false: minimal firmware without FS or OTA.

### 2.6 Feature Detection Guarantee
- The MCU **always responds** to `CMD_GET_FEATURES` (0x15) — no old firmware support needed.
- A short timeout (e.g. 2s) is kept as a defensive programming measure, but in practice the response always arrives.
- When the response arrives: `_deviceFeatures` is set from the 1-byte bitmask, and `hasOta` reflects bit 0.
- The OTA button appears in the Active Link Card whenever `hasOta` is true (firmware compiled with `RADIOKIT_FEATURE_OTA`).

---

## Summary of Changes vs Original Spec

| Change | Original | Corrected |
|--------|----------|-----------|
| OTA approach | NimBLEOta library | Custom `0xBB` protocol over existing transport |
| OTA dep | NimBLEOta (external) | `Update.h` (built-in ESP32) |
| FEATURES_DATA cmd | `0x10` | `0x16` (adjacent to request `0x15`) |
| JSON features key | Inside `config` | Top-level |
| Old FW compat | Shown disabled | Hidden entirely |
| HTTP OTA endpoint | `POST /api/fs/ota` | `POST /api/ota/upload` (deferred) |
| State machine | — | Added `otaRebooting` state |
| Undo for features | Not specified | Not undoable (matches _connectionType pattern) |
| OTA prefix byte | Widget protocol (`0x55`) | Dedicated `0xBB` (like FS `0xAA`) |

---

## Implementation Order

1. **Arduino side**: OTA protocol files (`RadioKitOTA.h/.cpp`), dispatch in `RadioKitBLE::_onWrite()`, handler in `RadioKit.cpp`, `CMD_GET_FEATURES` handler
2. **Flutter protocol**: Add commands to `protocol.dart` + `ota_protocol_service.dart` + `device_provider.dart` (features + OTA methods)
3. **Flutter UI**: OTA button in `_ActiveLinkSection` + OTA progress overlay + file picker flow
4. **Flutter OTA upload**: `uploadFirmware()` with chunk loop and CRC verification
5. **Post-OTA reconnect**: `otaRebooting` state + auto-scan + reconnect
6. **Designer settings**: `features` in `designer_state.dart` + inspector FEATURES section
7. **Code generation**: Update `JsonArduinoGenerator` for features
8. **HTTP API**: `POST /api/ota/upload` (deferred phase)
9. **Testing**: Flash firmware with/without OTA/FS, verify detection and OTA transfer

---

## Key Files Changed

| File | Change |
|------|--------|
| `arduino-library/src/RadioKitProtocol.h` | Add `RK_CMD_GET_FEATURES` (0x15), `RK_CMD_FEATURES_DATA` (0x16), `RK_START_BYTE_OTA` (0xBB), OTA sub-commands |
| `arduino-library/src/RadioKit.h` | Add `_handleGetFeatures()`, `_onOtaPacket()`, OTA handlers |
| `arduino-library/src/RadioKit.cpp` | Add dispatch for 0x15 + 0xBB, OTA handler implementations |
| `arduino-library/src/connection/RadioKitOTA.h` | New file: OTA parser, frame builder, declarations |
| `arduino-library/src/connection/RadioKitOTA.cpp` | New file: OTA implementation using Update.h |
| `arduino-library/src/connection/RadioKitBLE.cpp` | Add 0xBB dispatch in `_onWrite()`, setOtaCallback |
| `arduino-library/src/connection/RadioKitBLE.h` | Add OTA callback type, `_otaPacketCallback` field |
| `arduino-library/src/connection/RadioKitTransport.h` | Add `setOtaCallback()` virtual method |
| `arduino-library/src/RadioKitConfig.h` | Add `RADIOKIT_FEATURE_OTA` / `RADIOKIT_FEATURE_FS` defines |
| `arduino-library/src/connection/RadioKitFS.h` | Minor: add OTA alongside FS in header comments |
| `flutter-app/lib/models/protocol.dart` | Add kCmdGetFeatures (0x15), kCmdFeaturesData (0x16), OTA start byte + sub-commands |
| `flutter-app/lib/services/protocol_service.dart` | Add `buildGetFeatures()` |
| `flutter-app/lib/services/ota_protocol_service.dart` | New file: OTA frame builders + parsers |
| `flutter-app/lib/providers/device_provider.dart` | Add features detection, OTA upload methods, `otaRebooting` state |
| `flutter-app/lib/screens/home/models_tab.dart` | Add UPDATE FIRMWARE button to _ActiveLinkSection |
| `flutter-app/lib/screens/designer/widgets/designer_inspector.dart` | Add FEATURES section with OTA/FS toggles |
| `flutter-app/lib/screens/designer/codegen/json_arduino_generator.dart` | Generate FS/OTA code based on features |
| `flutter-library/lib/src/models/designer_state.dart` | Add features field, getters, setters, toJson/loadFromJson |
| `flutter-app/lib/services/remote_access_service.dart` | (Deferred) POST /api/ota/upload endpoint |
