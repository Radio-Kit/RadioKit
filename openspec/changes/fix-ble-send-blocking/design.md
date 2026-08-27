## Context

The RadioKit firmware runs a cooperative `loop()` that calls `RadioKit.update()` first, which does shadow comparison, print buffer flush, and batch-fires all pending VAR_UPDATE frames via `_sendPacket()`. Each `_sendPacket()` call enters `BLE::sendPacket()` which loops calling `target->notify(chunk)` with `delay(1)` between chunks. With MTU ~500 bytes, a 768-byte frame needs ~2 notify calls × ~30ms each = ~60ms blocked. With 3-5 queued frames (print + VAR_UPDATE + telemetry), the loop is frozen for 200-500ms per iteration.

The firmware also runs `RadioKitSerialTransport::update()` which writes a `\x00` keepalive byte every 250ms to prevent USB CDC endpoint stalls. This is only needed when USB Serial is the primary transport, but it runs unconditionally.

On the app side, `_handleVarUpdate()` calls `notifyListeners()` directly, and `_log()` also calls `notifyListeners()` via `ConsoleProvider`. Each BLE notification triggers two Flutter rebuilds.

## Goals / Non-Goals

**Goals:**
- Main `loop()` never blocks on BLE TX — enqueue and return immediately
- BLE TX task drains queue at BLE connection interval speed (~30ms/frame)
- Backpressure: drop oldest frame when ring buffer full, count drops
- Disable USB keepalive when BLE is the active transport
- Coalesce Flutter rebuilds to max 1 per event-loop microtask

**Non-Goals:**
- Changing the RadioKit protocol or widget API
- Modifying BLE connection parameters or MTU negotiation
- Changing the app's widget rendering pipeline
- Addressing WiFi/Cloud transport blocking (separate concern)

## Decisions

### D1: FreeRTOS task for BLE TX

**Choice**: Dedicated `ble_tx_task` on core 0 (protocol core) with a ring buffer queue.

**Alternatives considered**:
- *ISR-driven send*: Too complex for BLE notify, which needs NimBLE host task cooperation
- *yield()-based cooperative*: Still blocks the calling loop iteration
- *Separate Arduino `loop()` via `loopTask`*: Not available on ESP32 Arduino framework

**Rationale**: FreeRTOS xQueue is the standard ESP32 pattern for inter-task communication. The BLE TX task blocks on `xQueueReceive()` (zero CPU when idle) and drains frames one-by-one. The main loop calls `xQueueSend()` (non-blocking with `xQueueSendFromISR` or timeout=0) and returns immediately.

**Queue depth**: 8 slots × 768 bytes = 6KB RAM. On ESP32-S3 with 320KB RAM, this is ~2%.

### D2: Ring buffer in BLE TX task (not xQueue)

**Choice**: Use a custom ring buffer with `PendingFrame[8]` (same struct as current) instead of `xQueue`. The main loop writes to `_txHead`, the BLE task reads from `_txTail`. Atomic head/tail updates via `portENTER_CRITICAL` / `portEXIT_CRITICAL`.

**Rationale**: `xQueue` copies data per enqueue/dequeue (8 × 768 = 6KB copy per operation). A ring buffer with pointer swap avoids the copy. The existing `PendingFrame` struct is reused.

### D3: Conditional USB keepalive

**Choice**: Guard the keepalive write with `if (!_bleActive)` where `_bleActive` is set by `startBLE()`.

**Rationale**: The keepalive prevents USB CDC endpoint stalls on Android. When BLE is primary, the USB serial is only used for debug output (not protocol), so stalls don't matter. The flag is cheap (1 byte) and checked every 250ms.

### D4: Coalesce notifyListeners via microtask

**Choice**: In `_handleVarUpdate()`, set a dirty flag and schedule a microtask that calls `notifyListeners()` once. Multiple VAR_UPDATEs in the same event-loop tick only trigger one rebuild.

**Alternatives considered**:
- *Timer-based debounce (16ms)*: Adds latency, complex
- *StreamTransformer*: Overkill for this use case

**Rationale**: Dart's `scheduleMicrotask()` runs after the current synchronous callback returns. If 5 VAR_UPDATEs arrive in one BLE notification batch, they all set the dirty flag, and one microtask fires `notifyListeners()` after all are processed.

## Risks / Trade-offs

- **[Risk] BLE TX task priority conflict** → Set task priority to `configMAX_PRIORITIES - 2` (below NimBLE host task at `configMAX_PRIORITIES - 1`). NimBLE host must run first to process the notify.
- **[Risk] Ring buffer overflow under extreme load** → Drop oldest frame, increment `s_txQueueDrops`. Diagnostic log every 10s. This is acceptable because VAR_UPDATEs are superseded by newer values.
- **[Risk] Thread safety of widget state** → The main loop writes widget state, the BLE TX task only reads serialized frames (copied into ring buffer slots). No shared mutable state between tasks.
- **[Trade-off] 6KB extra RAM** → Acceptable on ESP32-S3 (320KB). Previous fix already saved 10KB by replacing 16KB single buffer.
- **[Trade-off] Print flush still rate-limited to 2 lines/iteration** → This remains correct. The async send just means the 2 lines are enqueued instantly instead of blocking during transmission.
