## Context

`RadioKitBLE::sendPacket()` uses a single-slot pending buffer (`_pendingBuf` / `_pendingLen`) to handle re-entrancy — when an incoming BLE write triggers an ACK during a send, the ACK is queued for delivery after the current send completes. If a second frame arrives while one is already pending, it silently overwrites the first. Additionally, `_flushPrintBuffer()` in `RadioKit.cpp` can send multiple 0xEE print frames in a single `update()` iteration, each going through `BLE::sendPacket()` with `delay()`/`yield()` between chunks — during which re-entrant writes are processed and their ACKs can be dropped.

## Goals / Non-Goals

**Goals:**
- Prevent silent frame drops when multiple re-entrant calls occur during a BLE send
- Rate-limit print flush on the BLE path to prevent boot message floods from blocking the pipe
- Add a diagnostic counter for future contention monitoring

**Non-Goals:**
- Changing the BLE protocol wire format
- Modifying the Serial/WiFi/Cloud transport send paths (they don't have the re-entrancy issue)
- Adding flow control or credit-based pacing (future work)

## Decisions

### D1: Print flush rate limit — BLE only, 2 lines per iteration

`_flushPrintBuffer()` gains a `linesSent` counter. On the BLE path, it sends at most 2 complete lines per call. Remaining data stays in the circular buffer and is flushed in subsequent `update()` iterations. The limit applies only when the primary transport is BLE — Serial and WiFi paths flush at full speed.

**Why 2 lines**: Empirically, 2 print frames (~500 bytes total) fit within a single connection interval without starving command ACKs. More than 2 starts to block the pipe.

### D2: 8-slot ring buffer for pending frames

Replace the single-slot `_pendingBuf[16388]` + `_pendingLen` with:
```cpp
struct PendingFrame {
    uint8_t data[RK_MAX_PACKET_SIZE];  // 768 bytes
    uint16_t len;
};
static const uint8_t kPendingRingSize = 8;
PendingFrame _pendingRing[kPendingRingSize];
uint8_t _pendingHead;  // next write slot
uint8_t _pendingTail;  // next read slot
uint8_t _pendingCount; // frames queued
```

**Why 8 slots**: Covers worst case — print flush (2 frames) + 3 concurrent command ACKs + telemetry VAR_UPDATE + settings response + margin. At 768 bytes × 8 = 6KB, negligible on ESP32-S3 (320KB RAM).

**Delivery**: After `sendPacket()` completes, drain all pending frames in FIFO order via a loop (not recursion) to avoid stack overflow.

### D3: Drop counter diagnostic

```cpp
static uint16_t s_pendingDrops = 0;  // incremented when ring is full
static uint32_t s_lastDiagLog = 0;   // millis() of last diagnostic print
```

Logged every 10 seconds: `BLE: diag — drops=%u pending=%u`. Zero runtime cost when no drops occur. Provides visibility into future contention without instrumenting the code.

## Risks / Trade-offs

- [6KB RAM increase] → Negligible on ESP32-S3 (320KB RAM, currently at ~52%). Would be a concern on ESP32-C3 (400KB SRAM shared).
- [Print delivery延迟] → Lines stay in the buffer longer (up to N/2 iterations). Acceptable — the print stream is informational, not time-critical.
- [Ring buffer overflow still possible] → With 8 slots, overflow requires 8+ concurrent re-entrant calls during a single send. Practically impossible with normal widget traffic. The drop counter will surface if it ever happens.
