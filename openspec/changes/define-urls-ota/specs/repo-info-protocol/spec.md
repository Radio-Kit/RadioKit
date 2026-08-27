## MODIFIED Requirements

### Requirement: Firmware config fields for remote links
The `RK_Config` struct SHALL expose `fs_url` and `ota_url` string pointers defaulting to `RK_FS_URL` and `RK_OTA_URL` preprocessor macros. The device SHALL read the link values directly from `RK_Config` without NVS involvement.

#### Scenario: Sketch defines remote links via macros or config struct
- **WHEN** a sketch defines `#define RK_FS_URL "https://github.com/Radio-Kit/demo-fs-assets"` or sets `RadioKit.config.fs_url`
- **THEN** the links-info settings command reports that URL directly from the struct

#### Scenario: Sketch declares no remote links
- **WHEN** a sketch leaves `fs_url` and `ota_url` as empty strings
- **THEN** the links-info settings command reports length 0 (empty string) for both links

### Requirement: GET_LINKS_INFO settings command
The 0xDD settings protocol SHALL include `GET_LINKS_INFO` (0x0F, App -> MCU) and `LINKS_INFO_DATA` (0x8F, MCU -> App). The response payload SHALL be `[FS_URL_LEN(1)][FS_URL...][OTA_URL_LEN(1)][OTA_URL...]`, streamed directly from `RadioKit.config.fs_url` and `RadioKit.config.ota_url`.

#### Scenario: App requests link info
- **WHEN** the app sends `GET_LINKS_INFO` to a connected device
- **THEN** the device responds with `LINKS_INFO_DATA` carrying the filesystem and OTA URL lengths and strings from `RadioKit.config`

### Requirement: Designer JSON and codegen emission
The designer JSON schema SHALL support an optional `config.links` object (`{ "fs": "...", "ota": "..." }`), and the Arduino generator SHALL emit `#define RK_FS_URL "..."` / `#define RK_OTA_URL "..."` directives and assign them to `RadioKit.config.fs_url` / `RadioKit.config.ota_url` in generated `RADIOKIT.h` only when the values are non-empty.

#### Scenario: Links authored in designer and exported
- **WHEN** a design has `config.links = { "fs": "https://github.com/owner/repo/tree/main/configs", "ota": "" }` and the user generates Arduino code
- **THEN** the generated header contains `#define RK_FS_URL "https://github.com/owner/repo/tree/main/configs"` and `RadioKit.config.fs_url = RK_FS_URL;`

## REMOVED Requirements

### Requirement: NVS persistence of remote links
**Reason**: Remote links are compile-time project properties. Storing them in NVS created flash overhead and stale settings across flash cycles.
**Migration**: Define `RK_FS_URL` / `RK_OTA_URL` in `RADIOKIT.h` or pass `-D RK_FS_URL=...` in `platformio.ini`.
