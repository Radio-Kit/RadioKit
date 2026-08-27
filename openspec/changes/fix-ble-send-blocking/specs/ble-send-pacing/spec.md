# ble-send-pacing (modified)

## Purpose
Add non-blocking variant of sendPacket that enqueues instead of blocking. Existing rate limiting (2 lines/flush) remains but the send itself becomes async.

## Modified Requirements

- [ ] `_flushPrintBuffer()` rate limit of 2 lines per iteration remains unchanged
- [ ] `_sendPacket()` routes through the async ring buffer instead of calling `BLE::sendPacket()` synchronously
- [ ] Non-realtime frames (FS, OTA, settings) use the same async path
- [ ] Existing `isRealtime` timeout/retry logic moves to the BLE TX task
