# ble-contention-diagnostics Specification

## ADDED Requirements

### Requirement: TX contention drop counter
The BLE transport SHALL maintain a `static uint16_t` drop counter that increments each time a frame is dropped because the pending ring buffer is full. The counter SHALL be logged via `Serial.printf()` every 10 seconds in the format `BLE: diag — drops=%u pending=%u`, where `drops` is the cumulative drop count and `pending` is the current ring buffer occupancy.

#### Scenario: No contention
- **WHEN** the BLE transport operates normally with no ring buffer overflows
- **THEN** the drop counter remains at 0 and diagnostic output shows `drops=0`

#### Scenario: Contention detected
- **WHEN** the ring buffer is full and a frame is dropped
- **THEN** the drop counter increments by 1 and the next diagnostic log reflects the increased count

#### Scenario: Diagnostic log interval
- **WHEN** 10 seconds have elapsed since the last diagnostic log
- **THEN** the diagnostic line is printed once via Serial, regardless of whether drops occurred
