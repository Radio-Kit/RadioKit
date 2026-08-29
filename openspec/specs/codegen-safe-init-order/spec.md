# codegen-safe-init-order Specification

## Purpose
TBD - created by archiving change boot-print-flush-codegen-order. Update Purpose after archive.
## Requirements
### Requirement: Codegen Safe Init Order
The generated initRadioKit() function SHALL mount the filesystem before starting BLE to prevent flash DMA corruption on ESP32-S3.

#### Scenario: Filesystem mounts before BLE
- **WHEN** the codegen generates initRadioKit() with both enableFS and enableBLE enabled
- **THEN** the generated code calls RadioKit.enableFS() before RadioKit.startBLE()
- **AND** the init sequence is: begin() → startSerial() → enableFS() → startBLE()

#### Scenario: FS-only firmware
- **WHEN** the codegen generates initRadioKit() with enableFS but no BLE
- **THEN** the generated code calls RadioKit.enableFS() after startSerial()
- **AND** no startBLE() call is generated

#### Scenario: BLE-only firmware
- **WHEN** the codegen generates initRadioKit() with enableBLE but no FS
- **THEN** the generated code calls RadioKit.startBLE() after startSerial()
- **AND** no enableFS() call is generated

