## Why

The firmware's `BLE::sendPacket()` blocks the main `loop()` for 100-300ms per frame drain cycle. With multiple queued frames (print, VAR_UPDATE, telemetry), the loop is frozen while BLE notifications are sent one-by-one with `delay(1)` yields. This starves `VehicleController::update()` and command processing, causing multi-second perceived lag in the app UI. Additionally, the USB serial keepalive writes `\x00` bytes at 4/s even when BLE is the primary transport, wasting serial bandwidth and creating phantom print frames. On the app side, every BLE notification triggers two `notifyListeners()` calls, causing Flutter rebuild storms.

## What Changes

- **Non-blocking BLE send**: Move the BLE `sendPacket()` TX loop to a FreeRTOS task with a ring buffer queue. The main `loop()` enqueues frames and returns immediately. A dedicated BLE TX task drains the queue, blocking only itself.
- **Disable USB keepalive when BLE is primary**: The `\x00` endpoint keepalive in `RadioKitSerialTransport::update()` is only needed when USB Serial is the sole transport. When BLE is active, skip the keepalive to eliminate 4 spurious null bytes/second.
- **Debounce notifyListeners in app**: Batch widget state updates per BLE notification batch instead of calling `notifyListeners()` on every individual VAR_UPDATE and print frame. Use a microtask scheduler to coalesce rebuilds.

## Capabilities

### New Capabilities
- `ble-nonblocking-send`: Firmware BLE TX is non-blocking — main loop enqueues frames to a ring buffer, a dedicated FreeRTOS task drains and sends them. Includes backpressure (drop oldest on overflow) and diagnostic counters.

### Modified Capabilities
- `ble-send-pacing`: Add non-blocking variant of sendPacket that enqueues instead of blocking. Existing rate limiting (2 lines/flush) remains but the send itself becomes async.
- `ble-contention-diagnostics`: Extend drop counter to also track ring buffer enqueue failures and task queue depth.

## Impact

- **Firmware (RadioKit/rk-arduino)**: `RadioKitBLE.h/cpp` — new FreeRTOS task, ring buffer, async send path. `RadioKitSerial.cpp` — conditional keepalive. `RadioKit.cpp` — `_sendPacket` routes through async queue.
- **App (RadioKit/radiokit-app)**: `device_provider.dart` — debounce `notifyListeners()` in `_handleVarUpdate` and `_handlePrintData`. Minor change to `ConsoleProvider` to batch log entries.
- **RAM**: +~2KB for FreeRTOS task stack + ring buffer (on ESP32-S3 with 320KB this is negligible).
- **No breaking changes** to the RadioKit protocol or widget API.
