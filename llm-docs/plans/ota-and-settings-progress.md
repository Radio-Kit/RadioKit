# OTA + Model Settings — Implementation Progress

> Last updated: 2026-06-08

---

## ✅ Part 1: Arduino OTA (Complete — compiled & flashed)

### Protocol Layer (`RadioKitProtocol.h`)

| Constant | Value | Status |
|----------|-------|--------|
| `RK_CMD_GET_FEATURES` | `0x15` | ✅ Added |
| `RK_CMD_FEATURES_DATA` | `0x16` | ✅ Added |
| `RK_FEATURE_OTA` | `(1 << 0)` | ✅ Added |
| `RK_FEATURE_FILESYSTEM` | `(1 << 1)` | ✅ Added |

### OTA Protocol Parser (`RadioKitOTA.h` / `.cpp`)

- **New files**, mirror `RadioKitFS.h/cpp` architecture exactly
- Start byte: `0xBB` (separate from widget `0x55` and FS `0xAA`)
- Frame format: `[0xBB] [SUB_CMD(1)] [LEN_LO(1)] [LEN_HI(1)] [PAYLOAD(N)]`
- Buffer: 4 KB (matching chunk size), no CRC (transport reliability sufficient)
- State machine: `WAIT_START → SUB_CMD → LEN_LO → LEN_HI → PAYLOAD`
- Static `rk_otaTxBuf[]` for outgoing frames
- ✅ File-level statics, no heap allocation

### Transport Layer Integration

**BLE (`RadioKitBLE.h/cpp`):**
- Added `_otaPacketCallback` field + `setOtaCallback()` override
- `_onWrite()` now dispatches across **3 parsers**: widget (0x55) → FS (0xAA) → OTA (0xBB)
- Frame ownership model: active parser gets all bytes; idle parsers dispatch by start byte
- `rk_otaRxReset()` called on disconnect
- ✅ Compiled, verified

**Serial (`RadioKitSerial.h/cpp`):**
- Added `_otaCb` field + `setOtaCallback()` override
- `update()` now feeds all bytes to widget → FS → OTA parsers sequentially
- `rk_otaRxReset()` called on junk recovery timeout
- ✅ Compiled, verified

**Transport Interface (`RadioKitTransport.h`):**
- Added `RK_OtaPacketCallback` typedef
- Added `virtual void setOtaCallback(RK_OtaPacketCallback cb)` (default no-op)

### Feature Detection (`CMD_GET_FEATURES`)

- **`_handleGetFeatures()`** in `RadioKit.cpp`:
  - Builds bitmask from compile-time flags
  - `RK_FEATURE_OTA` set when `RK_HAS_OTA` (ESP32 + Update.h)
  - `RK_FEATURE_FILESYSTEM` set when `RK_FS_HAS_LITTLEFS`
  - Sends 1-byte payload via `RK_CMD_FEATURES_DATA`

### OTA Handlers (`RadioKit.cpp`)

| Handler | Lines | Key Behavior |
|---------|-------|-------------|
| `_onOtaPacket` | 508–523 | Static dispatch: Begin/Chunk/End/Abort |
| `_handleOtaBegin` | 532–573 | `Update.abort()` stale session → `Update.begin(firmwareSize)` → ACK or NO_SPACE |
| `_handleOtaChunk` | 575–649 | Validate offset via `Update.progress()` → `Update.write()` → ACK → periodic progress (every 5% or 50 chunks) |
| `_handleOtaEnd` | 651–722 | `Update.end()` → `esp_ota_get_next_update_partition()` → `esp_ota_set_boot_partition()` → ACK → `esp_restart()` |
| `_handleOtaAbort` | 723–732 | `Update.abort()` — partition released, no reboot |

**Progress tracking:** File-level statics `s_otaLastProgressPct`, `s_otaLastProgressChunk`, `s_otaChunkCount` — reset on each OTA_BEGIN.

**Config:** `RadioKitConfig.h` — added `#define RADIOKIT_FEATURE_FS` (always defined, auto-detects LittleFS via `__has_include`). OTA is gated by `#if defined(ESP32)` in RadioKit.cpp.

### Compilation
- ✅ BasicSwitch example builds and links successfully (ESP32-S3, lolin_s3_mini)
- ✅ Firmware flashed to device and tested

---

## ✅ Part 2: Flutter OTA (Complete — APK builds cleanly)

### Protocol Constants (`protocol.dart`)

| Constant | Value | Status |
|----------|-------|--------|
| `kCmdGetFeatures` | `0x15` | ✅ |
| `kCmdFeaturesData` | `0x16` | ✅ |
| `kFeatureOta` | `1 << 0` | ✅ |
| `kFeatureFilesystem` | `1 << 1` | ✅ |
| `kOtaStartByte` | `0xBB` | ✅ |
| `kOtaHeaderSize` | `4` | ✅ |
| `kOtaMaxPayload` | `4096` | ✅ |
| `kOtaCmdBegin/Chunk/End/Abort` | `0x01–0x04` | ✅ |
| `kOtaRespAck/Progress` | `0x81/0x82` | ✅ |
| `kOtaErrOk/NoSpace/Crc/Flash/Seq/InvalidState/NotSupported` | `0x00–0x06` | ✅ |

### OTA Protocol Service (`ota_protocol_service.dart`)
- **New file**, mirrors `FsProtocolService` architecture
- Frame builders: `buildBegin(int size)`, `buildChunk(int offset, data)`, `buildEnd(int crc32)`, `buildAbort()`
- Frame parser: `parseFrame(List<int>)` → `ParsedOtaPacket`
- Response parsers: `parseAck()` → `int?`, `parseProgress()` → `(int, int)?`

### Buffer Drain (`protocol_service.dart`)
- `drainBuffer()` now detects 0xBB start byte as third protocol alongside 0x55 and 0xAA
- `DrainResult.ota()` constructor added alongside `.widget()` and `.fs()`

### Transport Callback Infrastructure

**`TransportService` (`transport_service.dart`):**
- Added `OtaPacketReceivedCallback` typedef
- Added `onOtaPacketReceived` field

**All 7 transport implementations updated with OTA dispatch:**

| Transport | Status | Details |
|-----------|--------|---------|
| BLE (`ble_service_impl.dart`) | ✅ | `_processBuffer()` dispatches `drained.kind == 'ota'` |
| Android Serial (`serial_service_android.dart`) | ✅ | Same pattern |
| Linux Serial (`serial_service_linux.dart`) | ✅ | Same pattern |
| Web Serial (`serial_service_web.dart`) | ✅ | Same pattern |
| Serial Stub (`serial_service_stub.dart`) | ✅ | Field only |
| Serial Native (`serial_service_native.dart`) | ✅ | Delegates to `_impl` |
| Demo Transport (`demo_transport.dart`) | ✅ | Field only |
| Debug Transport (`debug_transport.dart`) | ✅ | Getter/setter delegates to inner |

### DeviceProvider (`device_provider.dart`)

**Feature Detection:**
- `_deviceFeatures` (int bitmask), `hasOta` getter
- `_handleFeaturesData()` — parses 1-byte payload, logs, completes `_featuresCompleter`
- `_requestFeatures()` — fire-and-forget after config load, 2s timeout
- `_handlePacket()` dispatch includes `case kCmdFeaturesData`
- `_deviceFeatures` reset on disconnect and demo load

**OTA Upload (`uploadFirmware`):**
- **`uploadFirmware(List<int> firmware, {onProgress})`** → returns `Future<bool>`
- Flow: CRC32 compute → OTA_BEGIN (10s timeout) → chunk loop (4KB chunks, 10s timeout, 3× retry) → OTA_END (15s timeout) → success
- `abortOta()` — public method, sends OTA_ABORT, nulls completer
- `_handleOtaPacket()` — dispatches ACK to `_otaOperationCompleter`, progress to `_otaProgressCallback`
- `_computeCrc32()` — software CRC-32 (IEEE 802.3, poly 0xEDB88320)

### UI — UPDATE FIRMWARE Button (`models_tab.dart`)

- **`_startOtaUpdate()`** — top-level function in models_tab.dart:
  1. Opens `FilePicker.pickFiles()` (any file type)
  2. Reads file bytes via `File.readAsBytes()`
  3. Shows `_OtaProgressDialog`

- **`_OtaProgressDialog`** — StatefulWidget:
  - `LinearProgressIndicator` (determinate when progress known)
  - Speed display (KB/s)
  - Status text: "Uploading... X% (Y KB/s)" → "Verifying..." → "Update complete — rebooting..."
  - Cancel button (sends OTA_ABORT, pops dialog)
  - Error state (red message + close button)
  - Success state (green check + close button)

### Compilation
- ✅ `flutter build apk --debug` compiles and links successfully
- ✅ APK installed on device

---

## 🛑 Part 3: Design Settings (Not Started)

Pending implementation:
- `features` field in `DesignerState` (flutter-library)
- FEATURES section in inspector panel (`designer_inspector.dart`)
- OTA toggle disabled when connection type is serial

## 🛑 Part 4: Code Generation (Not Started)

Pending implementation:
- `JsonArduinoGenerator.generate()` reads `features` from JSON
- Emit `#define RADIOKIT_FEATURE_OTA` / `RADIOKIT_FEATURE_FS`
- Emit `#include` and initialization code based on features

## 🛑 Part 5: Post-OTA Reconnect (Not Started)

Pending implementation:
- `otaRebooting` state in `DeviceConnectionState`
- Auto-scan by MAC → name → all
- 30s timeout

## 🛑 Part 6: HTTP API (Deferred)

- `POST /api/ota/upload` — deferred to later phase

---

## Device Test Results

| Test | Result | Notes |
|------|--------|-------|
| Firmware flash (USB) | ✅ | BasicSwitch example, lolin_s3_mini |
| APK install | ✅ | app-debug.apk |
| BLE scan + connect | ✅ | ESP32 "Basic_Switch" connected |
| FS detection | ✅ | `hasFs: true` confirmed |
| OTA feature detection | ❓ | Not yet confirmed — `hasOta` not exposed through HTTP API; needs logcat verification |
| OTA upload | ⏳ | Not yet tested |
| OTA button visibility | ❓ | Not yet confirmed — requires UI interaction |

## Known Issues

1. **`hasOta` not in HTTP API response** — The remote access service doesn't expose `_deviceFeatures`; will need an update to include `hasOta` in the connection status response
2. **Post-OTA reconnect not implemented** — The `otaRebooting` state and auto-scan logic are still pending
3. **Division-by-zero in `_formatSpeed`** — `_OtaProgressDialog._formatSpeed()` uses `elapsed.inMilliseconds` without guarding against zero; should use `max(1, ms)`
4. **Background timeout on cancel** — After `abortOta()`, the chunk loop in `uploadFirmware()` continues creating completers; consider adding a cancellation flag
