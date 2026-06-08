# BLE Filesystem Optimization — Progress

## Current Status

### ✅ Complete: Notify chunk size fix (Root cause #1 — Data corruption)
- **Bug**: `sendPacket()` used `_negotiatedMtu` as the notify chunk size. Since ATT notifications have 3 bytes of overhead (opcode + handle), NimBLE silently truncated the last 3 bytes of every chunk.
- **Fix**: Changed to `_negotiatedMtu - 3`. Minimum MTU floor raised from 20 to 23.

### ✅ Complete: Notify queue retry logic (Root cause #2 — 8K read timeout)
- **Bug**: With ~509-byte notify chunks (MTU 512 - 3), an 8K read requires 17 chunks. NimBLE controller TX queue (~10 slots) overflows.
- **Fix**: Retry up to 200× with linear backoff (10→250ms), 30s hard timeout, disconnection guard.

### ✅ Complete: Follow mode overlay (app-level wrapper)
- Moved follow mode overlay/glow/STOP button from `home_screen.dart` to `_FollowModeWrapper` in `app.dart`.

### ✅ Complete: Speed indicator in AppBar
- Compact pill/chip in the AppBar actions row with `CircularProgressIndicator` + live speed text.

### ✅ Complete: `/api/session/route` endpoint
- New `GET /api/session/route` returns `{"route": "/dev-tools/esp32-fs"}` for automated test navigation tracking.

### ✅ Complete: ESP32 hang fix (Root cause #3 — NimBLE TX queue stall)
- **Bug**: `delay(_connIntervalMs * 3)` blocked the host task from processing TX completion events.
- **Fix**: Changed to `delay(5)` between notifications, with retry backoff for actual backpressure.

### ✅ Complete: Data corruption fix (Root cause #4 — Shared tx buffer overwrite)
- **Bug**: `sendPacket` sent from `rk_fsTxBuf()`, which was overwritten by `handleRead` during `delay()` yields.
- **Fix**: Dedicated `_sendBuf[16388]` — frame is copied to safe buffer before sending.

### ✅ Complete: Follow Mode interference fix (Reference-counted fsBusy)
- Changed `_fsBusy` from boolean to reference-counted integer for proper nesting of multi-chunk FS operations.

### ✅ Complete: Improved read speed
- **Before**: ~2 KB/s. **After**: ~28-39 KB/s (14-20× faster via `delay(1)` → `delay(5)` pacing fix).

### ✅ Complete: Data corruption at 500KB — ROOT CAUSE FIXED (Dedicated BLE characteristics)
- **Root cause**: BLE notification interleaving — widget protocol frames leaked into FS data stream on the same BLE characteristic.
- **Fix**: Three dedicated BLE characteristics: 0xFFE1 (widget), 0xFFE2 (FS), 0xFFE3 (OTA). Each protocol has its own notification pipe, preventing interleaving.
- **Verified**: 3 consecutive 500KB write+read integrity tests pass.

### ✅ Complete: UUID matching fix (Android BLE discovery)
- **Bug**: Android BLE stack returns short 16-bit UUIDs (e.g., "ffe2") instead of full 128-bit UUIDs.
- **Fix**: Bidirectional `contains()` matching: `cuuid.contains(expected) || expected.contains(cuuid)`.

### ✅ Complete: Connection params endpoint
- `GET /api/connection/params` returns live BLE connection params (connIntervalMs, MTU, RSSI).
- **Measured**: 48ms conn interval (not ~12ms as previously assumed), 498 MTU.

### ✅ Complete: Pipelined reads
- `readFile()` sends chunk N+1's request while chunk N's response is in flight. ~10-15% speed improvement.

### ✅ Complete: Deferred FS frame processing (Root cause #5 — NimBLE TX queue stall from LittleFS GC)

#### Bug
Multi-chunk 500KB writes caused the ESP32 to become unresponsive mid-transfer. Serial log showed:
```
BLE: sendPacket abort — notify failed after 10 retries at offset 0/10
```

The 10-byte ACK frame — a single notification — failed after 10 retries (10ms→250ms linear backoff). This happens because the NimBLE controller's TX queue is completely stalled: the host task was blocked by LittleFS GC during `handleWrite()` and couldn't process TX completion events.

#### Root cause
`handleWrite()` (LittleFS file operations: open, write, close) ran directly in the NimBLE host task context via the call chain:
```
_onFsWrite() → rk_fsRxFeedByte() → _fsPacketCallback() → RKFs::dispatch() → handleWrite()
```

LittleFS `write()` and `close()` can trigger garbage collection that takes 50-200ms. During this time, the NimBLE host task is blocked and cannot process TX completion events from the BLE controller. The controller's 10-slot TX queue fills up with unsent notifications, and by the time the host task is free, the queue is completely stalled — even a single-byte ACK notification fails.

#### Fix
Deferred FS frame processing in `RadioKitBLE`:

1. **`_onFsWrite()`** (runs in NimBLE host task): Instead of calling `_fsPacketCallback` inline, buffers the complete FS frame in `_pendingFsPayload[]` and sets `volatile bool _hasPendingFs = true`. Returns immediately — no LittleFS operations run in the host task context.

2. **`update()`** (runs in main Arduino loop task): Calls `_processPendingFs()` which copies the payload to a safe working buffer `_fsWorkBuf[]`, clears the flag, and dispatches the callback. Since this runs in the main loop, `delay()` calls inside `sendPacket()` (for notify pacing) correctly yield CPU to the NimBLE host task, which can drain TX completions.

3. **Thread safety**: The payload is copied to `_fsWorkBuf` _before_ clearing `_hasPendingFs`, so the host task can write a new frame to `_pendingFsPayload` without corrupting in-flight data. A for loop (max 3 iterations) handles the case where additional frames arrive during processing.

4. **Disconnect cleanup**: `_onDisconnect()` clears `_hasPendingFs`.

#### Memory
Added ~32KB of RAM (2 × 16384-byte buffers). Acceptable on ESP32-S3 (512KB SRAM).

#### Test results

| Test | Result |
|------|--------|
| 50KB write + read (earlier, without deferred FS fix) | FAIL ❌ (file listed but 404 on read) |
| 500KB write + read (without debug logging, before fix) | FAIL ❌ (0/3 passes, notify aborts) |
| 500KB write + read (Run 1, after deferred FS fix) | PASS ✅ (28.66s write, hash_match=True) |
| 500KB write + read (Run 2, after deferred FS fix) | PASS ✅ (27.81s write, hash_match=True) |

#### Files changed
| File | Change |
|------|--------|
| `arduino-library/src/connection/RadioKitBLE.h` | Added `_pendingFsPayload[16384]`, `_fsWorkBuf[16384]`, `_pendingFsSubCmd`, `_pendingFsLen`, `volatile _hasPendingFs`, `_processPendingFs()` |
| `arduino-library/src/connection/RadioKitBLE.cpp` | `_onFsWrite()` → buffers frames; `update()` → calls `_processPendingFs()`; `_processPendingFs()` → for-loop with safe copy; `_onDisconnect()` → clears `_hasPendingFs` |

### ✅ Complete: OTA firmware update feature
- Feature complete (dedicated OTA BLE characteristic 0xFFE3, protocol handlers on both sides)
- **Note**: OTA callbacks still run inline in the NimBLE host task. When OTA is activated, a similar deferred processing pattern should be applied since OTA chunk writes also trigger flash operations.
