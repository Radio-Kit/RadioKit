## Why

BLE widget commands experience progressive lag because two architectural issues compound: (1) `_flushPrintBuffer()` can send multiple 0xEE print frames in a single `update()` iteration, blocking the BLE pipe for 100-150ms during which incoming command ACKs are delayed, and (2) `RadioKitBLE::sendPacket()` has a single-slot pending buffer that silently drops frames when a second re-entrant call arrives during a send — the app never receives the ACK and must wait for a 500ms timeout before retrying.

## What Changes

- **Print flush rate limiting**: `_flushPrintBuffer()` will send at most 2 complete lines per call on the BLE path. Remaining lines stay in the circular buffer and are flushed in subsequent `update()` iterations. Serial/WiFi paths are unaffected.
- **Pending buffer ring**: Replace the single-slot `_pendingBuf` / `_pendingLen` with an 8-slot ring buffer. Each slot holds one complete frame (~768 bytes max). Re-entrant calls enqueue to the next free slot instead of overwriting. After the current send completes, all pending frames are delivered in order.
- **Drop counter diagnostic**: Add a `static uint16_t s_pendingDrops` counter that increments when the ring buffer is full and a frame cannot be enqueued. Logged via Serial every 10 seconds for contention monitoring.

## Capabilities

### New Capabilities

- `ble-send-pacing`: BLE notification pacing — rate-limited print flush (max 2 lines/iteration on BLE) to prevent boot message floods from starving command ACKs.
- `ble-pending-ring-buffer`: Re-entrant frame queue — 8-slot ring buffer replacing the single-slot pending buffer, preventing silent frame drops during concurrent send operations.
- `ble-contention-diagnostics`: TX contention monitoring — drop counter logged every 10 seconds for diagnosing future BLE bandwidth issues.

### Modified Capabilities

_(none — the existing BLE transport spec behavior is unchanged; these are implementation-level reliability improvements)_

## Impact

- **Firmware** (`rk-arduino/src`): `RadioKitBLE.h` (ring buffer structs), `RadioKitBLE.cpp` (sendPacket ring logic, drop counter), `RadioKit.cpp` (print flush rate limit)
- **RAM**: +6KB (8 × 768B ring buffer slots) — negligible on ESP32-S3 with 320KB RAM
- **Behavior**: Print stream delivery is smoother (no burst floods), command ACKs are never silently dropped, contention is visible via serial diagnostics
- **No protocol changes**: Wire format unchanged — this is a transport-layer reliability fix
