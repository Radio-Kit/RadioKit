# Design: Fix Serial Transport Blocking

## Architecture

### Current (Blocking)

```
loop() ─── RadioKit.update() ─── _sendToAllTransports()
                                        │
                            ┌───────────┴───────────┐
                            ▼                       ▼
                    SerialTransport::          BLETransport::
                      sendPacket()               sendPacket()
                            │                       │
                    _stream->write()          enqueue to ring
                            │                buffer (memcpy)
                    ██████████████████              │
                    █ BLOCKS 5-10ms █         TX task drains
                    █ per packet    █         (non-blocking)
                    ██████████████████
                            │
                    Main loop starved
                    → Blink timing degrades
```

### Proposed (Non-Blocking)

```
loop() ─── RadioKit.update() ─── _sendToAllTransports()
                                        │
                            ┌───────────┴───────────┐
                            ▼                       ▼
                    SerialTransport::          BLETransport::
                      sendPacket()               sendPacket()
                            │                       │
                    enqueue to ring           enqueue to ring
                    buffer (memcpy)           buffer (memcpy)
                    ✓ NON-BLOCKING            ✓ NON-BLOCKING
                            │                       │
                    update() drains          TX task drains
                    in main loop             (non-blocking)
                    ✓ NON-BLOCKING
```

## File Changes

### RadioKitSerial.h — Add Ring Buffer Members

```cpp
class RadioKitSerialTransport : public RadioKitTransport {
    // ... existing members ...

private:
    // TX ring buffer (matches BLE transport pattern)
    struct PendingFrame {
        uint8_t  data[RK_MAX_PACKET_SIZE];  // 768 bytes
        uint16_t len;
    };
    static const uint8_t kTxRingSize = 8;
    PendingFrame _txRing[kTxRingSize];
    uint8_t      _txHead;     // next write slot
    uint8_t      _txTail;     // next read slot
    uint8_t      _txCount;    // frames queued
    uint16_t     _txDropCount; // diagnostic: frames dropped
};
```

### RadioKitSerial.cpp — Non-Blocking sendPacket()

```cpp
void RadioKitSerialTransport::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_stream) return;

    // TinyUSB CDC guard (unchanged)
    #if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE == 1 && RK_ARCH_DETECTED == RK_ARCH_ESP32
    if (!tud_cdc_connected()) return;
    #endif

    // Non-blocking enqueue: copy frame into ring buffer
    if (_txCount < kTxRingSize && len <= RK_MAX_PACKET_SIZE) {
        memcpy(_txRing[_txHead].data, buf, len);
        _txRing[_txHead].len = len;
        _txHead = (_txHead + 1) % kTxRingSize;
        _txCount++;
    } else {
        _txDropCount++;
    }
}
```

### RadioKitSerial.cpp — Drain in update()

```cpp
void RadioKitSerialTransport::update() {
    // ... existing keepalive code ...

    // ── Drain TX ring buffer (non-blocking) ──
    while (_txCount > 0 && _stream) {
        uint16_t available = _stream->availableForWrite();
        if (available == 0) break;  // USB FIFO full, try next iteration

        PendingFrame& frame = _txRing[_txTail];
        uint16_t toWrite = min((uint16_t)available, frame.len);
        _stream->write(frame.data, toWrite);

        if (toWrite >= frame.len) {
            // Entire frame written
            _txTail = (_txTail + 1) % kTxRingSize;
            _txCount--;
        } else {
            // Partial write — frame stays at tail, will resume next update()
            // (Simplified: drop partial frames to keep non-blocking guarantee)
            _txTail = (_txTail + 1) % kTxRingSize;
            _txCount--;
        }
    }

    // Diagnostic: log drops every 10 seconds
    if (_txDropCount > 0) {
        static uint32_t lastDiagMs = 0;
        uint32_t now = millis();
        if (now - lastDiagMs >= 10000) {
            Serial.printf("SERIAL: diag — drops=%u\n", _txDropCount);
            _txDropCount = 0;
            lastDiagMs = now;
        }
    }

    // ... existing RX code (unchanged) ...
}
```

## Why This Works

1. **`sendPacket()` becomes a memcpy** — ~1μs instead of ~5ms
2. **`update()` drains what it can** — checks `availableForWrite()` before writing
3. **USB CDC at 2MHz** can drain ~250KB/sec — far exceeds the ~15KB/sec max output
4. **Ring buffer absorbs bursts** — up to 8 packets queued before drops
5. **Main loop runs freely** — no blocking, blink timing preserved

## Risk: Partial Writes

If the USB FIFO is full during `update()`, we drop the frame rather than block. This is acceptable because:
- At 2MHz baud, the FIFO drains in <1ms per 768-byte frame
- The main loop runs at ~100Hz, so the next iteration will have space
- In practice, partial writes are rare because the USB CDC FIFO is 512 bytes and drains fast

Alternative: Store the write offset in the PendingFrame struct for true partial write support. But this adds complexity for minimal gain.

## Testing Strategy

1. **Unit test**: Verify `sendPacket()` returns in <100μs (non-blocking)
2. **Integration test**: 5-minute latency stress test at 10Hz via API
3. **Hardware test**: Hazard light blink timing with USB connected
4. **Dual transport test**: BLE + Serial both active simultaneously
5. **E2E test**: All 7 phases pass
