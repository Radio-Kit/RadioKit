# Tasks: Fix BLE TX Bottleneck

## P0: Remove Firmware ACK for VAR_UPDATE

- [x] **1.1** Verify `_handleVarUpdate()` does NOT send ACK (read code)
- [x] **1.2** Remove ACK from `_handleSetInput()` in `RadioKit/rk-arduino/src/RadioKit.cpp`
- [x] **1.3** Verify app's `_handleSetInput` handler doesn't echo back (read code)

## P1: Batch Outgoing Frames in TX Task

- [x] **2.1** Modify `_drainTxQueue()` in `RadioKit/rk-arduino/src/connection/RadioKitBLE.cpp` to batch frames
- [x] **2.2** Add batch buffer (stack-allocated, up to 4 frames per batch)
- [x] **2.3** Test: verify firmware still parses concatenated incoming packets correctly

## P2: Rate-limit _confDirty

- [x] **3.1** Add rate limiter to `markConfDirty()` in `RadioKit/rk-arduino/src/RadioKit.cpp`
- [x] **3.2** Verify `CONF_DATA` still sends on page switch and initial connection

## P3: Reduce TX Task Priority

- [x] **4.1** Change TX task priority from `configMAX_PRIORITIES - 2` to `configMAX_PRIORITIES - 4` in `RadioKit/rk-arduino/src/connection/RadioKitBLE.cpp`

## Verification

- [x] **5.1** Build firmware and app
- [x] **5.2** Flash firmware to Mikro board
- [x] **5.3** Install app on tablet
- [x] **5.4** Run 5-minute latency stress test at 10Hz — expect <50ms avg, 0 slow
- [x] **5.5** Verify hazard light blink timing remains 300ms ±1ms under load
- [x] **5.6** Verify serial monitor text displays in real-time
- [x] **5.7** Run E2E hardware test — all 7 phases pass
