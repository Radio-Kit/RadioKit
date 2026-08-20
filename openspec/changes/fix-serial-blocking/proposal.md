# Fix Serial Transport Blocking

## Problem

The USB serial transport blocks the main loop during `sendPacket()` because `_stream->write(buf, len)` is synchronous. This causes:

1. **Growing lag** during continuous control use (slider, buttons)
2. **Blink timing degradation** — hazard lights blink slower when USB is connected
3. **Main loop starvation** — each outgoing packet blocks for 5-10ms

When USB is unplugged, the delay vanishes immediately — confirming serial is the bottleneck.

## Root Cause

```
RC_brain/main.cpp
  RadioKit.startSerial(Serial);  ← Serial is PRIMARY transport
  RadioKit.startBLE();           ← BLE is SECONDARY

RadioKitSerialTransport::sendPacket()
  _stream->write(buf, len);      ← SYNCHRONOUS BLOCKING (~5-10ms per packet)
```

### Blocking Timeline (per loop iteration)

| Event | Packets | Blocking per packet | Total blocked |
|-------|---------|-------------------|---------------|
| ACK for incoming VAR_UPDATE | ~10/sec | ~5ms | ~50ms |
| VAR_UPDATE for output widgets | ~6/sec | ~5ms | ~30ms |
| Print buffer flush | ~2/sec | ~5ms | ~10ms |
| **Total** | **~18/sec** | | **~90ms/sec** |

**Main loop runs at ~100Hz → 90ms blocking = 9% of time blocked**

With rapid commands (10Hz slider), the blocking compounds and grows.

## Solution

Add a TX ring buffer to the serial transport, matching the BLE transport's non-blocking pattern.

### Design

```
Before:
  sendPacket() → _stream->write(buf, len)  ← BLOCKS main loop

After:
  sendPacket() → enqueue into ring buffer   ← NON-BLOCKING (memcpy only)
  update()     → drain ring buffer          ← Writes what fits, returns immediately
```

### Ring Buffer Sizing

- 8 slots × 512 bytes = 4KB total
- ESP32-S3 has 512KB SRAM — negligible impact
- Can absorb bursts of up to 8 packets before drops

### Drain Strategy

In `update()`, before reading incoming bytes:
1. Check ring buffer `pendingCount > 0`
2. Check `_stream->availableForWrite()` (non-blocking)
3. Write as many bytes as the USB CDC FIFO can accept
4. Return immediately — don't block waiting for space

This ensures the main loop always returns within <1ms, regardless of serial output volume.

## Scope

- **rk-arduino library**: `RadioKitSerial.h` and `RadioKitSerial.cpp`
- **RC_brain firmware**: No changes needed
- **RadioKit app**: No changes needed

## Verification

1. 5-minute latency stress test at 10Hz — expect <50ms avg, 0 growing lag
2. Hazard light blink timing — must remain 300ms ±1ms with USB connected
3. Serial debug output — still appears on USB serial monitor
4. BLE + Serial dual transport — both work simultaneously
5. E2E hardware test — all 7 phases pass
