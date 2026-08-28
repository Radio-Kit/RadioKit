# firmware-marketplace Specification

## Purpose
TBD - created by archiving change firmware-marketplace. Update Purpose after archive.
## Requirements
### Requirement: Persistent Repository Sources Management
The companion app SHALL manage a locally persisted list of GitHub repository firmware sources in `SharedPreferences`, pre-populated with default community repositories.

#### Scenario: App launches for the first time
- **WHEN** the user opens the Flasher Tab and no stored repositories exist
- **THEN** the marketplace initializes with default sources (`https://github.com/DragonRailway/RC_Engine` and `https://github.com/Radio-Kit/demo-fs-assets`)
- **AND** stores them in `SharedPreferences`.

#### Scenario: User adds and removes custom repository
- **WHEN** the user adds a new GitHub repository URL (e.g. `https://github.com/my-org/my-project`)
- **THEN** the repository is persisted to `SharedPreferences` and fetched immediately
- **AND** the user can remove custom repositories via the UI.

### Requirement: QR Code Scanning and Deep Link Ingestion
The companion app SHALL provide a QR code scanner modal to ingest repository URLs and deep links.

#### Scenario: User scans plain GitHub repository QR code
- **WHEN** the user scans a QR code containing `https://github.com/DragonRailway/RC_Engine`
- **THEN** the app validates the URL, adds it to the marketplace sources list, and opens the release view.

#### Scenario: User scans deep link QR code with optional asset filter
- **WHEN** the user scans a QR code containing `radiokit://firmware?url=https://github.com/DragonRailway/RC_Engine&asset=RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin`
- **THEN** the app parses the repository URL and pre-selects the specified binary asset.

#### Scenario: User pastes URL on desktop platform
- **WHEN** running on a desktop or platform without camera access
- **THEN** the add dialog provides a "Paste from Clipboard" button alongside the text input field.

### Requirement: Standardized Binary Filename Parsing
The companion app `FirmwareMarketplaceService` SHALL parse firmware binary filenames following the `<Project>-<Version>-<Chip>[-<BoardOrVariant>][-<Type>].bin` standard.

#### Scenario: Parser encounters standard factory binary
- **WHEN** a release asset is named `RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin`
- **THEN** the parser extracts `project: RC_Engine`, `version: v1.0.0`, `chip: esp32s3`, `board: MIKRO_V2`, `type: factory`.

#### Scenario: Parser encounters standard OTA binary
- **WHEN** a release asset is named `BasicSwitch-v2.1.0-esp32s3-ota.bin`
- **THEN** the parser extracts `project: BasicSwitch`, `version: v2.1.0`, `chip: esp32s3`, `board: null`, `type: ota`.

#### Scenario: Parser encounters non-standard binary name
- **WHEN** a release asset is named `firmware.bin` or `custom_build_v1.bin`
- **THEN** the parser marks chip/type as generic and retains the asset for display and selection.

### Requirement: Connected Chip Family Matching and Badging
The Flasher Tab marketplace view SHALL inspect the connected ESP32 chip family from `FlasherProvider` and highlight compatible binary assets.

#### Scenario: Connected board chip matches binary asset
- **WHEN** `FlasherProvider` is connected to an `ESP32-S3` board
- **THEN** release assets with `esp32s3` chip tokens display a green `[MATCHES YOUR BOARD]` badge and are selected by default.

#### Scenario: Connected board chip does not match binary asset
- **WHEN** `FlasherProvider` is connected to an `ESP32-S3` board and the release contains `esp32c3` assets
- **THEN** the `esp32c3` asset is dimmed with a `[CHIP MISMATCH]` warning badge, but remains selectable if overridden.

#### Scenario: Prioritizing factory binaries for USB flashing
- **WHEN** both `*-factory.bin` and `*-ota.bin` exist for the matching chip in Flasher Tab
- **THEN** the `*-factory.bin` asset is prioritized and badged for USB bootloader flashing.

### Requirement: One-Click Stream and Flash Integration
The companion app SHALL download selected marketplace binaries into memory and initiate flashing via `FlasherProvider`.

#### Scenario: User triggers flash on a marketplace asset
- **WHEN** the user clicks "DOWNLOAD & FLASH" on a selected binary asset in the Flasher Tab
- **THEN** the app streams the `.bin` bytes over HTTP with a progress indicator
- **AND** passes the bytes directly to `FlasherProvider.flashCustomFirmware()` to begin serial flashing.

