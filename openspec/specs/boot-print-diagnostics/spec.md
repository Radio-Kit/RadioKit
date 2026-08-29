# boot-print-diagnostics Specification

## Purpose
TBD - created by archiving change boot-print-flush-codegen-order. Update Purpose after archive.
## Requirements
### Requirement: Boot-Time Print Diagnostics
RadioKit.print() messages emitted before any transport connects SHALL be visible on the raw Serial output for debugging purposes.

#### Scenario: Boot messages visible on serial
- **WHEN** the firmware calls RadioKit.print() during setup() before any client connects
- **THEN** the messages appear on the hardware Serial output via raw Serial.write()
- **AND** the messages remain available for the normal flush path after connection

#### Scenario: Connected mode unchanged
- **WHEN** a client connects and RadioKit.print() is called
- **THEN** messages flow through the normal transport path (BLE/Serial/WiFi)
- **AND** the boot flush does not fire again (one-shot per boot)

