# Tasks: Fix Serial Transport Blocking

## Implementation

- [x] **1.1** Add TX ring buffer struct and members to `RadioKitSerial.h`
- [x] **1.2** Initialize ring buffer in constructor in `RadioKitSerial.cpp`
- [x] **1.3** Replace blocking `_stream->write()` in `sendPacket()` with non-blocking ring buffer enqueue
- [x] **1.4** Add ring buffer drain logic in `update()` — write what `availableForWrite()` allows, return immediately
- [x] **1.5** Add drop diagnostic logging every 10 seconds

## Verification

- [x] **2.1** Build firmware — verify no compile errors
- [x] **2.2** Flash firmware to Mikro board
- [x] **2.3** Install app on tablet
- [x] **2.4** Run 5-minute latency stress test at 10Hz — expect <50ms avg, 0 growing lag
- [x] **2.5** Verify hazard light blink timing remains 300ms ±1ms with USB connected
- [x] **2.6** Run E2E hardware test — all 7 phases pass
- [x] **2.7** Verify serial debug output still appears on USB serial monitor
