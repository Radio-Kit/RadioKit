# flash-erase-policy Specification

## Purpose
Enforce mandatory flash erase policy during firmware upload to clear stale ESP32 NVS settings and document the rationale.

## Requirements

### Requirement: Mandatory Flash Erase on Firmware Upload
The documentation and agent guidelines SHALL explicitly specify that all firmware upload procedures (via CLI, PlatformIO, OTA, or web/app flasher) include the flash erase option (`-erase`, `--erase-flash`, or `eraseAll: true`) unless the user explicitly requests preserving existing device settings.

#### Scenario: Agent or developer builds and uploads firmware
- **WHEN** an agent or developer uploads code to an ESP32 microcontroller
- **THEN** the upload command or API call includes the flash erase flag (`-erase` / `eraseAll: true`) to ensure stale NVS configuration (old BLE device name, stale WiFi credentials) is cleared before first boot

#### Scenario: User requests preserving settings across upload
- **WHEN** the user explicitly specifies that previous device settings must be preserved
- **THEN** the upload command is run without the flash erase flag

### Requirement: Document NVS Flash Persistence Rationale
The firmware, OTA, remote, and example skills SHALL document the rationale for flash erasing: ESP32 NVS sector stores configuration parameters across standard flashes, which causes the microcontroller to advertise under previous BLE names or retain legacy transport credentials unless explicitly erased.

#### Scenario: Agent reviews skill documentation before flashing
- **WHEN** an agent reads `SKILLS/radiokit-firmware/SKILL.md`, `radiokit-ota`, `radiokit-remote`, or `.agents/skills/radiokit-example`
- **THEN** the skill provides a clear warning and visual/text explanation of why skipping flash erase leads to stale device name and config issues
