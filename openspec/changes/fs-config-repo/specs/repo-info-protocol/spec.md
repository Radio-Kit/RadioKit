# repo-info-protocol Specification

## Purpose

Firmware, protocol, and codegen SHALL support a device-declared config repository: `RK_Config` fields, NVS persistence, a `GET_REPO_INFO` settings command, designer JSON `config.repo`, and `RADIOKIT.h` emission.

## ADDED Requirements

### Requirement: Firmware config fields for the config repo

The `RK_Config` struct SHALL expose `repo_url` and `repo_subdir` string fields, with size caps defined in `RadioKitConfig.h`. The device SHALL honor the compile-time value unless overridden by NVS.

#### Scenario: Sketch declares a config repo
- **WHEN** a sketch sets `RadioKit.config.repo_url = "https://github.com/rambros3d/RadioKit"` and `RadioKit.config.repo_subdir = "configs"` before `begin()`
- **THEN** the values are committed to NVS on first boot and reported by the repo-info settings command

#### Scenario: Sketch declares no config repo
- **WHEN** a sketch leaves `repo_url` empty
- **THEN** the repo-info settings command reports an empty URL and empty subdir

### Requirement: NVS persistence of repo config

The firmware SHALL persist repo URL and subdir in NVS under keys `rk_repo_url` and `rk_repo_subdir`, seeded on first boot from `RK_Config`, and loaded on subsequent boots so runtime-overridden values survive.

#### Scenario: First boot seeding
- **WHEN** `begin()` runs with repo fields set and no prior NVS repo values
- **THEN** NVS is seeded with the config values and committed

#### Scenario: NVS override on later boot
- **WHEN** `begin()` runs after `rk_repo_url` was changed in NVS at runtime
- **THEN** the NVS value takes precedence over the compile-time config for the repo-info command

### Requirement: GET_REPO_INFO settings command

The 0xDD settings protocol SHALL include `GET_REPO_INFO` (0x0F, App -> MCU) and `REPO_INFO_DATA` (0x8F, MCU -> App). The response payload SHALL be `[URL_LEN(1)][URL...][SUBDIR_LEN(1)][SUBDIR...]`, mirroring the cloud-info framing, and SHALL be buildable/parseable from both the firmware and the Flutter app.

#### Scenario: App requests repo info
- **WHEN** the app sends `GET_REPO_INFO` to a device with repo fields set
- **THEN** the device responds with `REPO_INFO_DATA` carrying the URL and subdir lengths and bytes

#### Scenario: Round-trip frame layout
- **WHEN** `SettingsProtocolService.buildGetRepoInfo()` builds a frame and `parseRepoInfoData()` parses the response
- **THEN** the parsed URL and subdir match the values the firmware encoded, for both empty and non-empty cases

### Requirement: Designer JSON and codegen emission

The designer JSON schema SHALL carry an optional `config.repo` object (`{ "url": "", "subdir": "" }`) in both load and save paths, and the Arduino generator SHALL emit `config.repo_url = "..."` and `config.repo_subdir = "..."` lines in generated `RADIOKIT.h` only when the values are non-empty.

#### Scenario: Repo authored in designer and exported
- **WHEN** a design has `config.repo = { "url": "https://github.com/owner/repo", "subdir": "configs" }` and the user generates Arduino code
- **THEN** the generated header contains `config.repo_url = "https://github.com/owner/repo";` and `config.repo_subdir = "configs";`

#### Scenario: Repo omitted in designer and exported
- **WHEN** a design has no `config.repo` (or empty values) and the user generates Arduino code
- **THEN** the generated header omits both repo lines