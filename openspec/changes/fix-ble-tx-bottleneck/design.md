# Design: Fix BLE TX Bottleneck

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    CURRENT ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Core 0 (Protocol)           Core 1 (Application)               │
│  ┌─────────────────┐         ┌──────────────────┐              │
│  │ NimBLE Host     │         │ loop()           │              │
│  │   ↓             │         │   RadioKit.update│              │
│  │ _onWidgetWrite  │         │   VC::update     │              │
│  │   ↓             │         │   HW::update     │              │
│  │ _packetCallback │         │   (blink engines)│              │
│  └─────────────────┘         └──────────────────┘              │
│           │                                                         │
│  ┌────────▼─────────┐                                             │
│  │ ble_tx_task      │  ◀── configMAX_PRIORITIES - 2              │
│  │ (high priority)  │      monopolizes core 0 during drain       │
│  │   ↓              │                                             │
│  │ _drainTxQueue()  │                                             │
│  │   notify() × N   │  ◀── 48ms blocking per frame              │
│  └──────────────────┘                                             │
│           │                                                         │
│  ┌────────▼──────────┐                                            │
│  │ TX Ring Buffer(8) │  ◀── OVERFLOWS at >8 frames              │
│  └───────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

## Fix P0: Remove Firmware ACK for VAR_UPDATE

### What Changes

In `RadioKit.cpp`, the `_handleVarUpdate()` function currently does NOT send an ACK. The `_handleSetInput()` function DOES send an ACK. We need to verify this and ensure no ACK is sent for VAR_UPDATE.

**Current code** (`_handleVarUpdate`):
```cpp
void RadioKitClass::_handleVarUpdate(const uint8_t* payload, uint16_t len) {
    // ... deserializes input, updates shadow ...
    // No ACK sent — this is correct
}
```

**Current code** (`_handleSetInput`):
```cpp
void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    // ... deserializes input, updates shadow ...
    uint8_t seq = 0;
    uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &seq, 1);
    _sendPacket(pkt);  // ← SENDS ACK — REMOVE THIS
}
```

### Fix

Remove the ACK from `_handleSetInput()`:
```cpp
void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    // ... deserializes input, updates shadow ...
    // ACK removed — shadow comparison provides reliability
}
```

### Why This Is Safe

The app's `_handleSetInput` handler in `device_provider.dart`:
```dart
void _handleSetInput(List<int> payload) {
    // ... parses payload ...
    next = current.copyWithInput(widgetId, cooked);
    _widgetState = next;
    notifyListeners();  // Triggers UI rebuild, no echo
}
```

The app does NOT send a VAR_UPDATE in response to SET_INPUT. The `notifyListeners()` triggers `_syncValues()` which updates the canvas but with `onRuntimeValueChanged = null` (callback disabled). No feedback loop.

## Fix P1: Batch Outgoing Frames in TX Task

### What Changes

In `RadioKitBLE.cpp`, the `_drainTxQueue()` function currently sends one BLE `notify()` per frame. With MTU 498, we can concatenate multiple frames into a single write.

**Current code**:
```cpp
void RadioKitBLE::_drainTxQueue() {
    while (_pendingCount > 0 && _connected) {
        PendingFrame frame;
        // ... copy from ring buffer ...
        target->notify(frame.data + offset, chunk);  // One notify per frame
    }
}
```

**New code**:
```cpp
void RadioKitBLE::_drainTxQueue() {
    while (_pendingCount > 0 && _connected) {
        // Batch: concatenate frames up to MTU limit
        uint8_t batchBuf[RK_MAX_PACKET_SIZE * 4];  // Up to 4 frames
        uint16_t batchLen = 0;
        int batchCount = 0;
        
        while (_pendingCount > 0 && batchCount < 4 && _connected) {
            PendingFrame frame;
            // ... copy from ring buffer ...
            if (batchLen + frame.len <= _negotiatedMtu - 3) {
                memcpy(batchBuf + batchLen, frame.data, frame.len);
                batchLen += frame.len;
                batchCount++;
            } else {
                break;  // Frame won't fit, send current batch
            }
        }
        
        if (batchLen > 0) {
            target->notify(batchBuf, batchLen);  // One notify for batch
        }
    }
}
```

### Why This Works

- The firmware's `_onWidgetWrite` already handles concatenated packets (byte-by-byte parsing via `rk_rxFeedByte`)
- The app's BLE service already handles concatenated packets (same parser)
- MTU 498 allows ~40 small VAR_UPDATE frames per batch
- Reduces BLE notify calls from ~30/sec to ~3/sec

## Fix P2: Rate-limit _confDirty

### What Changes

In `Widget.h`, the `setHidden()` and `setVisible()` methods call `RadioKitClass::markConfDirty()`. During normal operation, `UiLogger::log()` calls `serial_monitor.setHidden(false)` which triggers this.

**Fix**: Add a rate limiter to `markConfDirty()`:
```cpp
void RadioKitClass::markConfDirty() {
    static uint32_t lastMark = 0;
    uint32_t now = millis();
    if (now - lastMark < 1000) return;  // Max once per second
    lastMark = now;
    if (s_instance) s_instance->_confDirty = true;
}
```

## Fix P3: Reduce TX Task Priority

### What Changes

In `RadioKitBLE.cpp`, the TX task is created with `configMAX_PRIORITIES - 2`:
```cpp
xTaskCreatePinnedToCore(
    ble_tx_task,
    "ble_tx",
    4096,
    this,
    configMAX_PRIORITIES - 2,  // ← Too high
    &_txTaskHandle,
    0
);
```

**Fix**: Lower to `configMAX_PRIORITIES - 4`:
```cpp
    configMAX_PRIORITIES - 4,  // Below NimBLE host, allows main loop to run
```

This ensures the main loop (priority 1) can run even when the TX task is draining the ring buffer.

## Testing Strategy

1. **Unit test**: Verify `_handleSetInput` no longer sends ACK
2. **Integration test**: 5-minute latency stress test at 10Hz via API
3. **Hardware test**: Hazard light blink timing under load
4. **Visual test**: Serial monitor text displays in real-time
5. **E2E test**: All 7 phases pass
