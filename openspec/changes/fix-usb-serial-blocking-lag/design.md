## Context

On ESP32-S3 systems with native USB CDC (`HWCDC`), the Arduino core uses FreeRTOS semaphores with a 250ms default timeout inside `HWCDC::write`. If a USB host connects but does not read from `/dev/ttyACM0`, the endpoint FIFO saturates and blocks CPU execution on every `Serial.print` or frame write. Concurrently, `_sendToAllTransports` fans out every state change and print packet to `RadioKitSerialInstance` even when BLE is the only active client session, overflowing the serial TX ring buffer and causing partial writes.

## Goals / Non-Goals

**Goals:**
- Zero-blocking serial operations: firmware loop rate remains >1000 Hz regardless of USB CDC host read status.
- Safe transport routing: serial transport only receives broadcast frames when it is connected or primary.
- Atomic ring buffer draining: serial TX ring buffer preserves frame integrity across update cycles.
- Reliable Android app USB polling: prevent MethodChannel queue starvation during idle USB read states.

**Non-Goals:**
- Rewriting the entire USB CDC stack in the Arduino core.
- Changing the protocol frame structure or payload definitions.

## Decisions

1. **Set `setTxTimeoutMs(0)` on Serial**:
   In `RadioKit.startSerial(Stream& stream)` or when `HWCDC` is detected, configure non-blocking write timeout so `write()` returns immediately when the hardware buffer is full.

2. **Conditional Fan-out in `_sendToAllTransports`**:
   In `RadioKit.cpp`, modify `_sendToAllTransports`:
   ```cpp
   if (_serialActive && (_transport == &RadioKitSerialInstance || RadioKitSerialInstance.isConnected())) {
       RadioKitSerialInstance.sendPacket(buf, len);
   }
   ```
   This ensures background serial instances don't accumulate packets unless there is an active serial listener.

3. **Atomic Frame Draining in `RadioKitSerialTransport::update`**:
   Only write to `_stream` if `_stream->availableForWrite() >= frame.len`. If space is insufficient, leave the frame in the head of the queue until the next iteration.

4. **Android Read Polling Guard**:
   In `RawUsbSerialService`, avoid overlapping async `read` MethodChannel invocations by tracking in-flight read status and using non-blocking read timeouts (0–10ms).

## Risks / Trade-offs

- [Risk]: Dropped debug logs if the host is not reading serial console.
  → Mitigation: Desired behavior — control loop timing takes priority over buffered debug logs.
