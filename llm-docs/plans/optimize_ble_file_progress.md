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

### ⏳ Pending: Improve read throughput
- Increase `_defaultChunkSize` from 4KB to 8KB in `device_fs_service.dart` to halve the number of read chunks
- Or implement read-ahead buffering on the Arduino side

### ⏳ Pending: Full integrity test suite
- 1MB read integrity test (blocked by fragment reuse issue)
- Pattern/alt/random data patterns across all sizes

### ⏳ Pending: Create PR with all changes - Note: Dont create PR, only create a commit.

## Key Files Changed

| File | Change | Status |
|------|--------|--------|
| `arduino-library/src/connection/RadioKitBLE.cpp` | Chunk size: MTU-3, retry: 200 attempts, 30s timeout, dynamic pacing | ✅ |
| `arduino-library/src/connection/RadioKitBLE.h` | `volatile _connected` flag | ✅ |
| `flutter-app/lib/services/device_fs_service.dart` | `_fsBusy` + ping guard | ✅ |
| `flutter-app/lib/providers/device_provider.dart` | `_fsBusy` + `_lastRxAt` tracking | ✅ |
| `flutter-app/lib/app.dart` | `_FollowModeWrapper` with GoRouter param, route sync to provider | ✅ |
| `flutter-app/lib/providers/remote_access_provider.dart` | `_currentRoute` field with getter and `updateCurrentRoute()` | ✅ |
| `flutter-app/lib/services/remote_access_service.dart` | `_currentRouteGetter` + `GET /api/session/route` handler | ✅ |
| `flutter-app/lib/screens/control_screen.dart` | Home button to left leading position | ✅ |
| `flutter-app/lib/screens/devtools/filesystem/filesystem_explorer_screen.dart` | Speed chip in AppBar, `_currentTransferBytes` tracking | ✅ |
| `flutter-app/lib/screens/home/home_screen.dart` | Removed follow overlay/listener/dead code | ✅ |
| `flutter-app/lib/screens/devtools/filesystem/filesystem_explorer_screen.dart` | `isFsBusy` defer in `_initialRefresh()` | ✅ |
| `flutter-app/lib/providers/device_provider.dart` | `bool get isFsBusy` getter | ✅ |
| `flutter-app/lib/services/remote_access_service.dart` | `@visibleForTesting testOnlyFollowRoute`, fixed `/api/widgets` path match | ✅ |
| `flutter-app/test/session_route_test.dart` | 11 tests for `/api/session/route` + `_followRoute` | ✅ |
| `arduino-library/src/connection/RadioKitBLE.h` | `_pendingBuf[16388]` + `_pendingLen` for re-entrant send queue | ✅ |
| `arduino-library/src/connection/RadioKitBLE.cpp` | Queue pending sends instead of dropping; drain after send | ✅ |
