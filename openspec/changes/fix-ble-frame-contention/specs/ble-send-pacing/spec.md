# ble-send-pacing Specification

## ADDED Requirements

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
