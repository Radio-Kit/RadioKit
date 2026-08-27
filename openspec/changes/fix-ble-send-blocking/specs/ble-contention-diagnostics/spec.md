# ble-contention-diagnostics (modified)

## Purpose
Extend drop counter to also track ring buffer enqueue failures and task queue depth.

## Modified Requirements

- [ ] `s_pendingDrops` counter (existing) tracks frames dropped due to ring buffer full
- [ ] `s_txQueueDepth` tracks current ring buffer fill level (max seen)
- [ ] Diagnostic log every 10s prints: drops, current queue depth, max queue depth seen
- [ ] Drop counter and queue depth reset on BLE disconnect
- [ ] USB keepalive `\x00` writes are skipped when BLE is the primary transport
