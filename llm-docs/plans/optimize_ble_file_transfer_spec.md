# Optimize BLE File Transfer Speed — Specification

> **Status:** Draft  
> **Created:** 2026-06-07  
> **Stakeholders:** RadioKit team  
> **Hardware:** ESP32-S3 (LOLIN S3 Mini) + Android device over ADB  

---

## 1. Goals

### Primary
- Achieve **maximum throughput** for BLE-based bulk filesystem operations (read/write) between the RadioKit Flutter app and an ESP32-S3 running the Filesystem_LED example.

### Secondary
- Maintain **low latency** for small FS operations (directory listing, info, ping, small config file read/write).
- Make BLE-level write fragmentation **transparent** to higher layers (DeviceFsService, FS protocol service).

### Non-goals
- Serial transport optimization (only BLE is in scope).
- Widget protocol optimization (only 0xAA bulk-FS frames are in scope).

---

## 2. Current State

### 2.1 ESP32 (Arduino / NimBLE-Arduino)

**Key files:**
- `arduino-library/src/connection/RadioKitBLE.cpp` — BLE transport impl
- `arduino-library/src/connection/RadioKitBLE.h` — BLE transport header
- `arduino-library/src/connection/RadioKitFS.h` — FS frame constants
- `arduino-library/examples/Filesystem_LED/Filesystem_LED.cpp` — test sketch

**Current deficiencies:**

| Issue | Detail | Impact |
|-------|--------|--------|
| **No 2M PHY** | Defaults to 1M PHY (1 Mbps). ESP32-S3 supports 2M PHY (2 Mbps). | ~50% speed loss |
| **No DLE** | Data Length Extension not configured. Default BLE payload is 27 bytes. DLE enables 251-byte payloads. | 9× more overhead per packet |
| **Default connection params** | NimBLE defaults to conservative intervals (~30–50ms). Can be tightened to 7.5–15ms. | Higher latency per round-trip |
| **No explicit MTU negotiation** | The ESP32 doesn't request or advertise a larger MTU. Default MTU is 23 bytes (20 usable). MTU 512 would give ~509 usable bytes. | Small payloads per frame |
| **Missing `WRITE` property** | Characteristic only has `WRITE_NR \| NOTIFY \| INDICATE`. Missing `NIMBLE_PROPERTY::WRITE`. The user's analysis indicates this can cause unreliable behavior on iOS and some Android devices for `withoutResponse` writes. | Potential reliability issues |
| **Hardcoded 20-byte pacing delay** | `sendPacket()` has `delay(20)` or `delay(50)` between notify chunks. This was tuned for MTU 20. | Unnecessary delay at higher MTU |

### 2.2 Flutter App

**Key files:**
- `flutter-app/lib/services/ble_service_impl.dart` — BLE service (write/read)
- `flutter-app/lib/services/device_fs_service.dart` — FS chunking service
- `flutter-app/lib/services/fs_protocol_service.dart` — 0xAA frame building
- `flutter-app/lib/providers/device_provider.dart` — transport orchestrator

**Current deficiencies:**

| Issue | Detail | Impact |
|-------|--------|--------|
| **No BLE-level write fragmentation** | `writePacket()` in `BleService` sends the entire data blob as one `UniversalBle.write()` call. For FS frames up to 16 KB, this exceeds MTU and may be silently rejected or dropped by the BLE stack. | Data loss / silent failures |
| **No ACK-based write pacing** | The Flutter side fires writes as fast as Dart allows. The ESP32 has a limited NimBLE notification/indication queue that can overflow. | Packet drops |
| **Doesn't query MTU after connect** | Requests MTU 256 on connect but never reads back the negotiated value. The actual MTU may differ. | Suboptimal chunk sizes |
| **`withoutResponse: true` only** | All writes use `withoutResponse: true`. While correct for throughput, without `WRITE` property on the ESP32 side, platforms may silently discard. | Unreliable transfers |

### 2.3 Existing Tests

- `flutter-app/test/device_fs_service_test.dart` — Unit tests for FS service (uses `_FakeFsTransport`)
- `flutter-app/test/demo_fs_test.dart` — Tests for the demo FS transport
- `flutter-app/test/fs_protocol_service_test.dart` — Tests for FS frame parsing

No **throughput benchmarks** exist yet.

---

## 3. Proposed Changes

### 3.1 ESP32 Firmware Changes (`RadioKitBLE.cpp` / `RadioKitBLE.h`)

#### 3.1.1 Add `WRITE` property to characteristic

```cpp
_characteristic = pService->createCharacteristic(
    RK_BLE_CHARACTERISTIC_UUID,
    NIMBLE_PROPERTY::WRITE_NR |
    NIMBLE_PROPERTY::WRITE |      // ← ADD THIS
    NIMBLE_PROPERTY::NOTIFY |
    NIMBLE_PROPERTY::INDICATE
);
```

**Rationale:** Required for reliable cross-platform behavior with `withoutResponse` (Write-No-Response) writes.

#### 3.1.2 Enable 2M PHY

After `NimBLEDevice::init()`, add:

```cpp
NimBLEDevice::setOwnAddrType(BLE_OWN_ADDR_RANDOM);
// 2M PHY is auto-negotiated, but we must ensure it's preferred.
// NimBLE-Arduino handles PHY negotiation automatically when both
// sides support it. On ESP32-S3, this is the default PHY if available.
```

**Note:** NimBLE-Arduino auto-negotiates PHY. We may need to explicitly set PHY preferences via `NimBLEDevice::setPreferredPHY(2)` or by configuring the advertising parameters.

#### 3.1.3 Enable Data Length Extension (DLE)

```cpp
// Request 251-byte data length (max for BLE 4.2+)
esp_ble_gap_set_data_len(connHandle, 251);  // or NimBLE API equivalent
```

NimBLE-Arduino exposes `NimBLEDevice::setDataLength(251)`. This should be called after a connection is established (in the `onConnect` callback).

#### 3.1.4 Optimize connection parameters

```cpp
// In onConnect callback or after connection established:
NimBLEDevice::setConnectionParams(
    6,    // min interval (7.5ms — 6 × 1.25ms)
    12,   // max interval (15ms)
    0,    // slave latency
    400   // supervision timeout (4s)
);
```

#### 3.1.5 Request larger MTU

NimBLE-Arduino typically negotiates MTU when the client requests it. The Flutter side already requests MTU 256. We should ensure the ESP32 accepts it and optionally request 512.

#### 3.1.6 Adjust send pacing based on MTU

Replace the hardcoded `delay(20)` / `delay(50)` with a pacing value proportional to the negotiated MTU:

```cpp
uint16_t mtu = _server->getPeerMTU(peers[0]) - 3;
uint16_t pacingDelay = (mtu > 100) ? 5 : 20; // Less delay at higher MTU
```

### 3.2 Flutter BLE Service Changes (`ble_service_impl.dart`)

#### 3.2.1 Query negotiated MTU

After connecting and discovering services, read back the actual MTU:

```dart
// Store negotiated MTU
int _mtu = 23; // default
try {
  _mtu = await UniversalBle.requestMtu(deviceId, 512);
  _log('Negotiated MTU: $_mtu');
} catch (e) {
  _log('MTU request failed, using default: $e');
}
```

#### 3.2.2 Implement transparent write chunking in `writePacket()`

```dart
@override
Future<void> writePacket(Uint8List data) async {
  if (_isMockConnected) {
    _handleMockWrite(data);
    return;
  }

  final deviceId = _connectedDeviceId;
  if (deviceId == null) throw StateError('Not connected');

  final chunkSize = (_mtu - 3).clamp(20, _mtu - 3); // MTU minus ATT header

  if (data.length <= chunkSize) {
    // Single write
    await UniversalBle.write(
      deviceId, kRadioKitServiceUuid, kRadioKitCharUuid,
      data,
      withoutResponse: true,
    );
    return;
  }

  // Chunked write
  for (int i = 0; i < data.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, data.length);
    final chunk = data.sublist(i, end);

    await UniversalBle.write(
      deviceId, kRadioKitServiceUuid, kRadioKitCharUuid,
      chunk,
      withoutResponse: true,
    );

    // No pacing delay initially — will be added if queue overflow observed
  }
}
```

#### 3.2.3 Expose MTU info for debugging/logging

Add a getter `int? get negotiatedMtu => _mtu;` to `BleService` for diagnostics.

### 3.3 Benchmark Script (`flutter-app/bin/ble_fs_benchmark.sh`)

A shell script that drives the Remote Access API (port 7007) to:

1. **Throughput test (upload):**
   - Use `/api/fs/write` to upload 100 KB, 500 KB, and 1 MB files
   - Time each operation using `time` or `date` diff
   - Report KB/s

2. **Throughput test (download):**
   - Use `/api/fs/read` to download the same files
   - Time and report KB/s

3. **Small ops latency test:**
   - Batch: `LIST /` → `INFO` → `MKDIR /test` → `STAT /test` → `DELETE /test`
   - Measure total time for the batch
   - Repeat 5 times, report min/avg/max

4. **Output:**
   - Tabulated results in a markdown-compatible format
   - Compare before/after when run pre- and post-optimization

### 3.4 Test Updates (`device_fs_service_test.dart`)

No major changes needed — the existing unit tests use `_FakeFsTransport` and are transport-agnostic. The BLE chunking should be tested separately:

- Add a small unit test for the chunking logic in `BleService`:
  - Verify that a 1000-byte payload with MTU 256 is split into 4 chunks of 253 bytes
  - Verify that a 200-byte payload with MTU 256 is sent as a single write

---

## 4. Implementation Plan

### Phase 1: Benchmark Baseline

1. Write the benchmark shell script (`ble_fs_benchmark.sh`)
2. Flash current (unoptimized) Filesystem_LED firmware to ESP32-S3
3. Build & install current Flutter app on Android via ADB
4. Run the benchmark 3 times, record baseline throughput/latency numbers

### Phase 2: ESP32 Optimizations

1. Add `WRITE` property to characteristic definition
2. Add DLE and 2M PHY configuration in `RadioKitBLE.cpp`
3. Optimize connection parameters (interval, latency, timeout)
4. Request/accept larger MTU
5. Adjust send pacing based on actual MTU
6. Flash and test each change incrementally

### Phase 3: Flutter Optimizations

1. Query and store negotiated MTU after BLE connection
2. Implement chunked writes in `writePacket()` using MTU-3 chunk size
3. Add MTU getter for diagnostics
4. Re-run benchmark to measure improvement

### Phase 4: Validation

1. Run full benchmark suite 3 times
2. Calculate speedup per operation
3. Run existing unit tests to confirm no regressions
4. Test edge cases:
   - File upload interrupted mid-transfer
   - Very large upload (full 1 MB LittleFS)
   - Rapid small-file operations

---

## 5. Success Criteria

| Metric | Current (approx) | Target |
|--------|-------------------|--------|
| Write throughput (1 MB file) | TBD | ≥ 10× improvement |
| Read throughput (1 MB file) | TBD | ≥ 5× improvement |
| Small ops batch (5 items) | TBD | ≤ 30% increase acceptable |
| Data integrity | All bytes match | 100% match post-transfer |
| Unit test pass rate | 100% | 100% |

*Baseline numbers will be filled in after Phase 1 benchmark.*

---

## 6. Open Questions / Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| NimBLE stack rejects aggressive connection params | Connection fails | Fall back to conservative params (6× 1.25ms = 7.5ms is ESP32-safe) |
| Chunked writes without pacing overflow NimBLE queue | Data loss | Add optional pacing if monitoring shows drops |
| `WRITE` + `WRITE_NR` on same char causes confusion | Cross-platform behavior differences | Test on target Android device; document platform behavior |
| 2M PHY may not be available on all ESP32-S3 boards | PHY falls back to 1M | Auto-negotiation handles this — no code change needed |
| DLE requires BLE 4.2+ hardware | DLE not enabled | NimBLE fails gracefully, falls back to 27-byte payload |

---

## 7. Files Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `arduino-library/src/connection/RadioKitBLE.cpp` | Modify | Add PHY, DLE, connection params, MTU, WRITE prop, pacing |
| `arduino-library/src/connection/RadioKitBLE.h` | Modify (maybe) | Update `RK_BLE_MTU` define if needed |
| `flutter-app/lib/services/ble_service_impl.dart` | Modify | MTU query + chunked writes in `writePacket()` |
| `flutter-app/bin/ble_fs_benchmark.sh` | Create | Benchmark script using Remote Access API |
| `llm-docs/plans/optimize_ble_file_transfer_spec.md` | Create | This spec file |
