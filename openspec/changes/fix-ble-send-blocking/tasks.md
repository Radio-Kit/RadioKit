## 1. BLE TX Task + Ring Buffer (Firmware)

- [ ] 1.1 Add FreeRTOS task handle, ring buffer arrays, and semaphore to `RadioKitBLE.h`
- [ ] 1.2 Implement `ble_tx_task()` static function in `RadioKitBLE.cpp` — blocks on semaphore, drains ring buffer, calls `sendPacket()` for each frame
- [ ] 1.3 Modify `RadioKitBLE::sendPacket()` — if `_sending`, enqueue to ring buffer and signal semaphore (non-blocking path). If not sending, start the task.
- [ ] 1.4 Reset ring buffer and task state in `_onDisconnect()`
- [ ] 1.5 Add diagnostic logging: queue depth, drops every 10s

## 2. USB Keepalive Guard (Firmware)

- [ ] 2.1 Add `_bleActive` flag to `RadioKitSerialTransport`, set by `setBleActive(bool)`
- [ ] 2.2 Guard the keepalive `\x00` write in `update()` with `if (!_bleActive)`
- [ ] 2.3 Call `setBleActive(true)` from `RadioKitBLE::begin()` after BLE starts

## 3. App Debounce (Dart)

- [ ] 3.1 Add `_varUpdateDirty` flag and `_scheduleNotifyListeners()` helper in `device_provider.dart`
- [ ] 3.2 Replace direct `notifyListeners()` in `_handleVarUpdate()` with `_scheduleNotifyListeners()`
- [ ] 3.3 Replace direct `notifyListeners()` in `_handlePrintData()` path with `_scheduleNotifyListeners()`
- [ ] 3.4 Ensure `_scheduleNotifyListeners()` uses `scheduleMicrotask()` to coalesce multiple calls per tick

## 4. Build + Verify

- [ ] 4.1 Build MIKRO_V2 and TRACKLINK_V3 — verify RAM ≤ 55%, no errors
- [ ] 4.2 Run host VC tests — all pass
- [ ] 4.3 Flash to MIKRO board, run E2E verification
- [ ] 4.4 Run latency stress test — verify < 100ms sustained under 10Hz command load
