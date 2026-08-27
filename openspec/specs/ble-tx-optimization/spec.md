# ble-tx-optimization Specification

## Purpose
TBD - created by archiving change fix-ble-tx-bottleneck. Update Purpose after archive.

## Requirements

### Requirement: TX Throughput
The firmware must handle 10Hz command traffic without growing lag.

#### Scenario: Latency under load
- **WHEN** a 5-minute stress test at 10Hz is run
- **THEN** average latency is <50ms and no commands exceed 100ms

#### Scenario: No main loop starvation
- **WHEN** high-frequency command traffic is active
- **THEN** hazard light blink timing remains 300ms +/-1ms

#### Scenario: Serial monitor text
- **WHEN** command traffic is active
- **THEN** serial monitor displays text in real-time without drops

#### Scenario: No feedback loop
- **WHEN** commands are sent
- **THEN** no echo mechanism creates additional traffic

### Constraints
- BLE connection interval: 48ms (Android negotiated)
- MTU: 498 bytes
- TX ring buffer: 8 slots (existing)
- ESP32 dual-core: core 0 (protocol), core 1 (application)

### Requirement: Frame Budget
Total outgoing frames must not exceed BLE capacity (~21 frames/sec at 48ms interval).

#### Scenario: Budget within capacity
- **WHEN** all frame sources are counted
- **THEN** total frames/sec is ~19 (below 21 frame/sec BLE capacity)
