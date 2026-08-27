# ble-send-pacing Specification

## Purpose

Provide low-latency, non-blocking packet transmission pacing over BLE for real-time control while preserving bounded reliability for bulk and settings transfers, and minimize debug logging overhead.

## Requirements

### Requirement: Differentiated BLE Transmission Pacing
The `RadioKitBLE::sendPacket` method SHALL classify outgoing packets by protocol start byte and apply low-latency transmission pacing. Real-time packets (`0x55` widget/var updates and `0xDD` print stream) SHALL NOT execute long blocking delays when GATT notification fails due to stack congestion.

#### Scenario: Real-time packet under stack congestion
- **WHEN** a real-time widget packet (`0x55`) or print stream packet (`0xDD`) is sent and `NimBLECharacteristic::notify` returns false
- **THEN** the BLE transport yields execution without entering exponential multi-millisecond backoff delays and drops or defers the packet quickly (<1ms)

#### Scenario: Bulk or critical packet transmission
- **WHEN** a critical frame (`0xAA` FS, `0xBB` OTA, `0xCC` Settings) is sent and `NimBLECharacteristic::notify` returns false
- **THEN** the BLE transport retries with minimal bounded pacing (at most 1ms per retry, capped at 5 retries) without causing unbounded main loop stalls

### Requirement: Low Core Debug Logging Overhead
Platform configuration builds SHALL default `CORE_DEBUG_LEVEL` to <= 2 (Error or Warning) to prevent NimBLE debug chatter from saturating the serial bus during high-frequency GATT transactions.

#### Scenario: Continuous control input handling
- **WHEN** high-frequency control packets are received by the BLE GATT server
- **THEN** no verbose GATT write debug logs are emitted to the serial CDC stream, allowing structured application logs to remain clear

### Requirement: Rate-limited print flush on BLE path
The `_flushPrintBuffer()` method SHALL send at most 2 complete print lines per invocation when the primary transport is BLE. Lines that exceed the per-iteration limit SHALL remain in the circular buffer and be flushed in subsequent `update()` iterations. The rate limit SHALL NOT apply when the primary transport is Serial or WiFi, which flush at full speed.

#### Scenario: Boot message flood on BLE
- **WHEN** the firmware boots and emits 10+ print lines while BLE is the primary transport
- **THEN** only 2 lines are sent per `update()` iteration, with remaining lines flushed progressively over subsequent iterations, preventing BLE pipe saturation

#### Scenario: Normal operation with sparse print output
- **WHEN** the firmware emits 0-2 print lines per `update()` iteration
- **THEN** all lines are flushed immediately with no delay

#### Scenario: Serial transport active
- **WHEN** the primary transport is Serial (not BLE)
- **THEN** `_flushPrintBuffer()` sends all complete lines without rate limiting
