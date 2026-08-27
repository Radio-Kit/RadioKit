# ble-nonblocking-send

## Purpose
Firmware BLE TX is non-blocking — main loop enqueues frames to a ring buffer, a dedicated FreeRTOS task drains and sends them.

## Requirements

- [ ] BLE TX operates on a dedicated FreeRTOS task (`ble_tx_task`) running on the protocol core
- [ ] Ring buffer holds up to 8 pending frames (PendingFrame struct, 768 bytes each)
- [ ] Main loop `sendPacket()` enqueues frames via `portENTER_CRITICAL` and returns immediately (timeout=0)
- [ ] BLE TX task blocks on a notification semaphore when queue is empty (zero CPU when idle)
- [ ] BLE TX task drains one frame per iteration, sending via `target->notify()` with existing chunking/retry logic
- [ ] On ring buffer overflow, oldest frame is dropped and `s_txQueueDrops` incremented
- [ ] Diagnostic log prints queue depth and drop count every 10 seconds
- [ ] Ring buffer is reset on BLE disconnect (`_onDisconnect`)
- [ ] Task priority is below NimBLE host task to avoid priority inversion
- [ ] RAM overhead is ≤ 8KB (task stack + ring buffer)
