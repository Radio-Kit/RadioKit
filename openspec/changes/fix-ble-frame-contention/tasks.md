# Tasks: Fix BLE Frame Contention

## Section 1: Print Flush Rate Limit

- [x] 1.1 Add `linesSent` counter and `MAX_LINES_PER_FLUSH = 2` constant to `_flushPrintBuffer()` in `RadioKit/rk-arduino/src/RadioKit.cpp`
- [x] 1.2 Apply rate limit only when primary transport is BLE (`_transport == &RadioKitBLEInstance`)
- [x] 1.3 Verify Serial/WiFi paths are unaffected (no rate limit when transport is not BLE)

## Section 2: Ring Buffer for Pending Frames

- [x] 2.1 Define `PendingFrame` struct and ring buffer arrays in `RadioKit/rk-arduino/src/connection/RadioKitBLE.h` (8 slots × 768 bytes)
- [x] 2.2 Replace `_pendingBuf`/`_pendingLen` with ring buffer head/tail/count in `RadioKitBLE.cpp` constructor
- [x] 2.3 Rewrite re-entrancy guard in `sendPacket()` to enqueue to next free ring slot
- [x] 2.4 Replace recursive pending delivery with iterative drain loop (FIFO order, no recursion)
- [x] 2.5 Reset ring buffer state in `_onDisconnect()`

## Section 3: Drop Counter Diagnostic

- [x] 3.1 Add `static uint16_t s_pendingDrops` and `static uint32_t s_lastDiagLog` to `RadioKitBLE.cpp`
- [x] 3.2 Increment `s_pendingDrops` when ring buffer is full and frame is dropped
- [x] 3.3 Log diagnostic line every 10 seconds: `BLE: diag — drops=%u pending=%u`
- [x] 3.4 Reset drop counter on disconnect (clean slate for new connections)

## Section 4: Verification

- [x] 4.1 Build RadioKit firmware for ESP32-S3 and confirm clean compilation
- [x] 4.2 Run existing RadioKit unit tests if available
- [x] 4.3 Flash to MIKRO board and verify no regressions in E2E test suite
