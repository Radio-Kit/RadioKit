# repo-info-protocol Specification

## Purpose

Firmware, protocol, Designer UI, and codegen SHALL support configurable remote links: `RK_Config.fs_url` and `RK_Config.ota_url`, NVS persistence (`rk_fs_url`, `rk_ota_url`), a `GET_LINKS_INFO` settings command, designer JSON `config.links`, and `RADIOKIT.h` emission.

## ADDED Requirements

### Requirement: Firmware config fields for remote links

The `RK_Config` struct SHALL expose `fs_url` (filesystem repo/subfolder URL) and `ota_url` (OTA firmware URL placeholder) string fields, with size caps defined in `RadioKitConfig.h`. The device SHALL honor the compile-time values unless overridden by NVS.

#### Scenario: Sketch declares remote links
- **WHEN** a sketch sets `RadioKit.config.fs_url = "https://github.com/rambros3d/RadioKit/tree/main/configs"` and `RadioKit.config.ota_url = ""` before `begin()`
- **THEN** the values are committed to NVS on first boot and reported by the links-info settings command

#### Scenario: Sketch declares no remote links
- **WHEN** a sketch leaves `fs_url` and `ota_url` empty
- **THEN** the links-info settings command reports empty strings for both links

### Requirement: NVS persistence of remote links

The firmware SHALL persist `fs_url` and `ota_url` in NVS under keys `rk_fs_url` and `rk_ota_url`, seeded on first boot from `RK_Config`, and loaded on subsequent boots into RAM buffers.

#### Scenario: First boot seeding
- **WHEN** `begin()` runs with link fields set and no prior NVS link values
- **THEN** NVS is seeded with the config values and committed

#### Scenario: NVS override on later boot
- **WHEN** `begin()` runs after `rk_fs_url` was changed in NVS at runtime
- **THEN** the NVS value takes precedence over the compile-time config

### Requirement: GET_LINKS_INFO settings command

The 0xDD settings protocol SHALL include `GET_LINKS_INFO` (0x0F, App -> MCU) and `LINKS_INFO_DATA` (0x8F, MCU -> App). The response payload SHALL be `[FS_URL_LEN(1)][FS_URL...][OTA_URL_LEN(1)][OTA_URL...]`, mirroring the cloud-info framing.

#### Scenario: App requests link info
- **WHEN** the app sends `GET_LINKS_INFO` to a connected device
- **THEN** the device responds with `LINKS_INFO_DATA` carrying the filesystem and OTA URL lengths and strings

### Requirement: Designer JSON and codegen emission

The designer JSON schema SHALL support an optional `config.links` object (`{ "fs": "...", "ota": "..." }`) in both load and save paths, and the Arduino generator SHALL emit `config.fs_url = "..."` and `config.ota_url = "..."` lines in generated `RADIOKIT.h` only when the values are non-empty.

#### Scenario: Links authored in designer and exported
- **WHEN** a design has `config.links = { "fs": "https://github.com/owner/repo/tree/main/configs", "ota": "" }` and the user generates Arduino code
- **THEN** the generated header contains `RadioKit.config.fs_url = "https://github.com/owner/repo/tree/main/configs";` and omits `ota_url`

#### Scenario: Links omitted in designer and exported
- **WHEN** a design has no `config.links` (or empty values) and the user generates Arduino code
- **THEN** the generated header omits both link lines