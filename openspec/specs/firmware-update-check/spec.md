# firmware-update-check Specification

## Purpose
TBD - created by archiving change firmware-ota-check. Update Purpose after archive.
## Requirements
### Requirement: Firmware Reports Version in Device Info Frame
The firmware `RadioKitClass::_handleSettingsDeviceInfo()` handler SHALL append the firmware version string (`RadioKit.config.version`) to the `SETTINGS_RESP_DEVICE_INFO_DATA` (0x88) payload.

#### Scenario: Host queries device info
- **WHEN** the companion app sends `SETTINGS_CMD_GET_DEVICE_INFO` (0x08)
- **THEN** the firmware returns a payload containing `[PROTO_VER][NAME_LEN][NAME][DESC_LEN][DESC][UID_LEN][UID][ICON_LEN][ICON][VER_LEN][VERSION]`
- **AND** the companion app parses and stores the `firmwareVersion` string in `DeviceProvider`.

### Requirement: Companion App Fetches Latest Release from GitHub
The companion app `FirmwareReleaseService` SHALL parse GitHub repository URLs from `otaUrl` and fetch release metadata from the GitHub Releases API.

#### Scenario: Valid GitHub OTA URL configured
- **WHEN** `FirmwareReleaseService.fetchLatestRelease()` is called with a GitHub repo URL (e.g. `https://github.com/Radio-Kit/demo-fs-assets`)
- **THEN** the service queries `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- **AND** returns release tag, title, published timestamp, body changelog, and attached assets list.

#### Scenario: No OTA URL or invalid URL
- **WHEN** `dp.otaUrl` is empty or not a valid GitHub repository URL
- **THEN** `FirmwareReleaseService.fetchLatestRelease()` returns null and the UI displays no remote update source.

### Requirement: Companion App Matches Binary Assets
The companion app SHALL automatically identify and match `.bin` firmware assets in the release against the connected device's name or board identifier.

#### Scenario: Release has board-specific binary matching device name
- **WHEN** the connected device name is `MIKRO_V2` and the release assets contain `MIKRO_V2.bin` and `TRACKLINK_V3.bin`
- **THEN** `MIKRO_V2.bin` is automatically selected as the active target asset.

#### Scenario: Multiple binary assets with manual override
- **WHEN** multiple `.bin` assets are available in the release
- **THEN** the Firmware Tab displays an asset selection dropdown allowing the user to select any binary asset.

### Requirement: Firmware Tab Renders Update Status and Allows Manual Flashing
The companion app `FirmwareTabContent` SHALL display current version vs latest remote version, render changelog notes, and download the binary asset into memory when the user triggers an update.

#### Scenario: Newer version available on tab open
- **WHEN** the user opens the Firmware Tab and `latestVersion > currentVersion`
- **THEN** the tab displays an update available card with new version tag, publish date, asset size, and expandable changelog
- **AND** provides a "DOWNLOAD & FLASH" button.

#### Scenario: User confirms download and flash
- **WHEN** the user clicks "DOWNLOAD & FLASH"
- **THEN** the app downloads the `.bin` asset bytes over HTTP with progress
- **AND** hands off the downloaded bytes directly to `dp.uploadFirmware()` with the user's selected erase mode.

