# Fix BLE TX Bottleneck

## Problem

The firmware's BLE TX path has a bottleneck that causes growing lag during continuous control use (slider, buttons). After a few seconds of 10Hz command traffic, the delay grows from ~15ms to seconds, and even the hazard light blink timing degrades — indicating main loop starvation.

## Root Cause

The firmware generates **more outgoing BLE frames than the connection can handle**, causing the TX ring buffer to overflow and the TX task to monopolize the protocol core.

### Frame Budget Analysis

| Source | Frames/sec | Notes |
|--------|-----------|-------|
| Firmware ACK (per incoming VAR_UPDATE) | ~10 | One ACK per app command |
| Firmware VAR_UPDATE (output widgets) | ~6 | telemetry_Battery, telemetry_Speed, gear echo, indicator echo |
| Firmware SET_INPUT echo | ~3 | gear_switch, indicator state changes |
| App VAR_UPDATE | ~10 | Slider at 10Hz |
| Telemetry response | ~0.2 | Every 5 sec |
| **Total** | **~30 frames/sec** | |
| **BLE capacity (48ms interval)** | **~21 frames/sec** | One notify per connection event |

**30 > 21 → TX ring buffer (8 slots) overflows → frames dropped → main loop starved**

### Why It Grows Over Time

1. TX task runs at `configMAX_PRIORITIES - 2` on core 0
2. When ring buffer fills, `_drainTxQueue()` calls `notify()` per frame — each blocks ~48ms
3. With 8 frames queued, main loop is starved for up to 384ms per drain cycle
4. `HardwareInit::update()` (blink engines) runs less frequently → blink timing degrades
5. Diagnostic logs (`BLE: diag — drops=N`) add MORE print data when drops occur → feedback loop

## Proposed Solution

### P0: Remove firmware ACK for VAR_UPDATE (saves ~10 frames/sec)

The firmware sends an ACK (RK_CMD_ACK) for every incoming VAR_UPDATE from the app. This is unnecessary because:
- The protocol uses shadow comparison for reliability
- The app already tracks pending updates with retry logic
- The ACK adds 10 frames/sec of pure overhead

**Impact**: Reduces total from 30 to ~20 frames/sec — within BLE capacity.

### P1: Batch outgoing frames in TX task (eliminates per-frame BLE notify blocking)

Instead of calling `notify()` once per frame, concatenate multiple frames into a single BLE write (the MTU is 498 bytes — can fit ~40 small frames).

**Impact**: Eliminates 48ms blocking per frame. Main loop starvation eliminated.

### P2: Rate-limit _confDirty during normal operation

`UiLogger::log()` calls `serial_monitor.setHidden(false)` which triggers `markConfDirty()`, causing a CONF_DATA + VAR_DATA burst. Rate-limit this to once per second during normal operation.

### P3: Reduce TX task priority

Lower from `configMAX_PRIORITIES - 2` to avoid starving the main loop during drain cycles.

## Scope

- **rk-arduino library**: TX path changes (RadioKitBLE, RadioKit.cpp)
- **RC_brain firmware**: No changes needed (benefits automatically)
- **RadioKit app**: No changes needed

## Verification

1. 5-minute latency stress test at 10Hz — expect <50ms avg, 0 slow commands
2. Hazard light blink timing — must remain 300ms ±1ms under load
3. Serial monitor text — must display in real-time
4. E2E hardware test — all 7 phases pass
