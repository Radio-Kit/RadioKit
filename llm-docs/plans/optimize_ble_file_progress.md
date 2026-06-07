# BLE Filesystem Optimization — Progress

## Current Status

### ✅ Complete: Notify chunk size fix (Root cause #1 — Data corruption)
- **Bug**: `sendPacket()` used `_negotiatedMtu` as the notify chunk size. Since ATT notifications have 3 bytes of overhead (opcode + handle), NimBLE silently truncated the last 3 bytes of every chunk.
- **Fix**: Changed to `_negotiatedMtu - 3`. Minimum MTU floor raised from 20 to 23.
- **Verified**: Pattern 512, Random 1K, Zeros 2K, and random 4K all pass data integrity checks.

### ✅ Complete: Notify queue retry logic (Root cause #2 — 8K read timeout)
- **Bug**: With ~509-byte notify chunks (MTU 512 - 3), an 8K read requires 17 chunks. NimBLE controller TX queue (~10 slots) overflows, `notify()` returns false, old code skipped failed chunk after only 5 retries.
- **Fix**: Retry up to 200× with linear backoff (10→250ms), 30s hard timeout, disconnection guard, dynamic pacing (`_connIntervalMs * 3`).

### ✅ Complete: Follow mode overlay (app-level wrapper)
- **Change**: Moved follow mode overlay/glow/STOP button/AbsorbPointer from `home_screen.dart` to `_FollowModeWrapper` in `app.dart`.
- **Fix**: Uses `GoRouter` passed as constructor param (avoids `GoRouter.of(context)` which fails from `MaterialApp.router` builder context).
- **Fix**: Skip re-navigation if already on target route (prevents redundant FS screen creation).
- **Verified**: Follow mode navigates correctly, glow halo visible on all screens, AbsorbPointer correctly excludes `/control`.

### ✅ Complete: Speed indicator in AppBar
- **Change**: Moved transfer speed from status bar in `filesystem_explorer_screen.dart` to a compact pill/chip in the AppBar actions row.
- **Feature**: Shows `CircularProgressIndicator` + live speed text (e.g. "12 KB/s") during active transfers.
- **Fix**: Tracks `_currentTransferBytes` directly instead of fragile status-message parsing.

### ✅ Complete: Control screen home button position
- **Change**: Moved home button from right actions to leftmost leading position on `/control` screen.

### ✅ Complete: `/api/session/route` endpoint
- **Feature**: New `GET /api/session/route` returns `{"route": "/dev-tools/esp32-fs"}` exposing the current GoRouter location.
- **Implementation**: `RemoteAccessProvider._currentRoute` field, updated by `_FollowModeWrapper._syncLocation()`, passed as getter to `RemoteAccessService`.
- **Verified**: Returns correct route (e.g. `/system`, `/dev-tools/esp32-fs`).

### ✅ Complete: BLE performance characterization

#### BLE transport metrics
- **Connection**: ESP32-S3, NimBLE, MTU 512, PHY 2M, DLE 251, conn interval ~12ms
- **Theoretical peak**: ~30 KB/s (MTU 509 payload × 6 notifications per 12ms interval)
- **Achieved write**: ~18 KB/s (100KB in 5.4s) — 60% of theoretical peak
- **Achieved read**: ~2 KB/s (100KB in 49.6s) — read is 9× slower than write
- **Cold-start penalty**: First FS operation after connect takes ~7s; subsequent ops are 2×–10× faster

#### Read speed bottleneck analysis
- **Read is 9× slower than write**: Write sends data via BLE Write-No-Response (fire-and-forget). Read requires BLE WRITE request (to send the READ command) + multiple BLE notifications (to receive READ_DATA). The notify path goes through NimBLE's TX queue which has strict pacing (`delay(connInterval * 5)` between chunks).
- **Per-chunk overhead**: Each 4KB chunk: write = 1 BLE write (~8ms), read = 1 BLE write + 9 BLE notifications (~500ms total round-trip).
- **Mitigation**: Increase `_defaultChunkSize` from 4KB to 8KB or 16KB to reduce the number of read chunks by 2×–4×.

#### Sequential FS test results

| File | Write time | Write speed | Read (follow OFF) | Read (follow ON) | Integrity |
|------|-----------|-------------|-------------------|------------------|-----------|
| 10KB | 7.22s | 1.4 KB/s* | 5.08s @ 2.0 KB/s | 5.04s @ 2.0 KB/s | PASS ✅ |
| 50KB | 2.88s | 17.4 KB/s | 25.19s @ 2.0 KB/s | — | PASS ✅ |
| 100KB | 5.43s | 18.4 KB/s | 51.41s @ 1.9 KB/s | 49.68s @ 2.0 KB/s | PASS ✅ |
| 1MB | 57.9s | 17.7 KB/s | — | — | — |

*10KB write cold-start penalty (first FS op after connection)

#### Fix verification
- **1MB write timeout**: Fixed by pending-send buffer in `RadioKitBLE::sendPacket()` — 1MB write now completes in 57.9s ✅
- **Read 404 with follow mode**: Fixed by `isFsBusy` defer in `FilesystemExplorerScreen._initialRefresh()` — reads pass integrity with follow mode ON ✅
- **Route tracking**: `/api/session/route` correctly shows `/system` → `/dev-tools/esp32-fs` ✅

### ✅ Complete: ESP32 hang fix (Root cause #3 — NimBLE TX queue stall)
- **Bug**: `delay(_connIntervalMs * 3)` blocked the NimBLE host task from processing TX completion events from the BLE controller. With >8 notifications per chunk, the controller's 10-slot TX queue stalled and never drained.
- **Fix**: Changed pacing to `delay(1)` — a minimal yield that allows the host task to process "Number of Completed Packets" events between notifications. The retry backoff (`delay(10..250ms)`) handles actual TX queue backpressure.
- **Result**: ESP32 no longer hangs on large read responses.

### ✅ Complete: Data corruption fix (Root cause #4 — Shared tx buffer overwrite)
- **Bug**: `sendPacket` sent from `rk_fsTxBuf()` (shared tx buffer). During `delay(1)` yields, incoming BLE writes triggered `handleRead`, which overwrote `rk_fsTxBuf()` with new frame data, corrupting the in-flight send.
- **Fix**: Added dedicated `_sendBuf[16388]` to `RadioKitBLE`. `sendPacket` copies the frame to `_sendBuf` at the start of each send, then sends from the safe copy. `_pendingBuf` remains for re-entrant queuing.
- **Fix**: Changed `memcpy` → `memmove` in `rk_fsBuildFrame` for safety (source/destination may overlap).
- **Verified**: 10KB and 50KB reads pass integrity checks.

### ✅ Complete: Follow Mode interference fix (Reference-counted fsBusy)
- **Bug**: `_ProviderAdapter.sendFs()` released `_fsBusy` between chunks, allowing the Follow Mode FS screen to interleave its own listDir/getInfo operations during multi-chunk HTTP API reads.
- **Fix**: Changed `_fsBusy` from boolean to reference-counted integer. HTTP handlers (`_handleFsRead`/`_handleFsWrite`) hold an outer lock for the entire multi-chunk operation. `_ProviderAdapter.sendFs` holds per-chunk locks that don't prematurely release the outer lock.
- **Verified**: 10KB and 50KB read/write pass with Follow Mode ON ✅

### ✅ Complete: Timeout reductions
- Reduced `_shortTimeout` from 5s to 3s, `_readChunkTimeout` from 30s to 15s, `_writeTimeout` from 60s to 30s, format timeout from 30s to 10s.

### ✅ Complete: Improved read speed (via pacing fix)
- **Before**: Read was ~2 KB/s (with old pacing `delay(connInterval * 5)` = 60ms between notifications).
- **After**: Read is ~28-39 KB/s (with `delay(1)` yield between notifications). The retry backoff handles actual TX queue pressure efficiently.
- **Improvement**: ~14-20× faster reads.

#### Updated test results (with all fixes)

| File | Write time | Write speed | Read time | Read speed | Follow mode | Integrity |
|------|-----------|-------------|-----------|------------|-------------|-----------|
| 10KB | 0.62s | 16.1 KB/s | 0.36s | 27.7 KB/s | ON | PASS ✅ |
| 50KB | 3.27s | 15.3 KB/s | 1.28s | 39.1 KB/s | ON | PASS ✅ |

**Notable**: Read speeds now EXCEED write speeds (39 KB/s read vs 15 KB/s write for 50KB). This is because the `delay(1)` pacing lets the NimBLE stack transmit at its natural rate, while the retry backoff only kicks in when the TX queue is actually full.

### ⏳ Pending: Full integrity test suite
- 1MB read test (requires ESP32 reset and follow mode fixes verified on larger files)
- Pattern/alt/random data patterns across all sizes

### ⏳ Pending: Create PR with all changes - Note: Dont create PR, only create a commit.

## Key Files Changed

| File | Change | Status |
|------|--------|--------|
| `arduino-library/src/connection/RadioKitBLE.cpp` | Chunk size: MTU-3, retry: 200 attempts, 30s timeout, `delay(1)` pacing | ✅ |
| `arduino-library/src/connection/RadioKitBLE.h` | `volatile _connected`, `_sendBuf[16388]` + `_pendingBuf[16388]` | ✅ |
| `arduino-library/src/connection/RadioKitFS.cpp` | `memcpy` → `memmove` in `rk_fsBuildFrame` | ✅ |
| `flutter-app/lib/services/device_fs_service.dart` | 4KB chunks, shorter timeouts, `_fsBusy` ping guard | ✅ |
| `flutter-app/lib/providers/device_provider.dart` | Refcounted `_fsBusy`, `_lastRxAt` tracking | ✅ |
| `flutter-app/lib/services/remote_access_service.dart` | `_handleFsRead`/`_handleFsWrite` lock wrapping | ✅ |
| `flutter-app/lib/app.dart` | `_FollowModeWrapper` with GoRouter param, route sync to provider | ✅ |
| `flutter-app/lib/providers/remote_access_provider.dart` | `_currentRoute` field with getter and `updateCurrentRoute()` | ✅ |
| `flutter-app/lib/screens/devtools/filesystem/filesystem_explorer_screen.dart` | Speed chip in AppBar, `_currentTransferBytes` tracking, `isFsBusy` defer | ✅ |
| `flutter-app/lib/screens/home/home_screen.dart` | Removed follow overlay/listener/dead code | ✅ |
| `flutter-app/test/session_route_test.dart` | 11 tests for `/api/session/route` + `_followRoute` | ✅ |
