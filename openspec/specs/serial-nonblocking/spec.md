# serial-nonblocking Specification

## Purpose
TBD - created by archiving change fix-serial-blocking. Update Purpose after archive.

## Requirements

### Requirement: No Main Loop Blocking
The serial transport must not block the main loop during packet transmission.

#### Scenario: sendPacket latency
- **WHEN** `sendPacket()` is called
- **THEN** it returns in <100us (memcpy only, no I/O)

#### Scenario: No growing lag
- **WHEN** a 5-minute stress test at 10Hz is run
- **THEN** latency remains stable (<50ms avg)

#### Scenario: Blink timing preserved
- **WHEN** hazard lights are blinking and USB is connected
- **THEN** blink timing remains 300ms +/-1ms

#### Scenario: Dual transport
- **WHEN** BLE and Serial are both active
- **THEN** they work simultaneously without interference

#### Scenario: Debug output
- **WHEN** the serial monitor is connected
- **THEN** STATUS lines and events are displayed

### Constraints
- ESP32-S3 native USB CDC at 2MHz baud
- USB CDC FIFO: 512 bytes
- Ring buffer: 8 slots x 768 bytes = 6KB max
- Must not break existing serial protocol (0x55, 0xAA, 0xBB, 0xDD, 0xEE framing)
