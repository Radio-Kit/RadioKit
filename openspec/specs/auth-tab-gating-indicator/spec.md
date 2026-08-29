# auth-tab-gating-indicator Specification

## Purpose
TBD - created by archiving change fix-ble-features-tabs. Update Purpose after archive.
## Requirements
### Requirement: Auth Gate Indicator for Hidden Tabs
When `isUserMode` is true and the device has FS or OTA features, the config bottom sheet SHALL display a visual indicator communicating that device-level authentication is required for these tabs.

#### Scenario: User mode with FS feature
- **WHEN** the user opens the config bottom sheet on a device where `isUserMode == true`, `hasFs == true`, and `hasOta == false`
- **THEN** the FILESYSTEM tab is NOT shown, and a lock icon indicator is visible near the tab bar

#### Scenario: User mode with OTA feature
- **WHEN** the user opens the config bottom sheet on a device where `isUserMode == true`, `hasFs == false`, and `hasOta == true`
- **THEN** the FIRMWARE tab is NOT shown, and a lock icon indicator is visible near the tab bar

#### Scenario: User mode with both FS and OTA features
- **WHEN** the user opens the config bottom sheet on a device where `isUserMode == true`, `hasFs == true`, and `hasOta == true`
- **THEN** neither the FILESYSTEM nor FIRMWARE tab is shown, and a lock icon indicator is visible near the tab bar

#### Scenario: Device mode with features
- **WHEN** the user opens the config bottom sheet on a device where `isUserMode == false` and `hasFs == true` and `hasOta == true`
- **THEN** both the FILESYSTEM and FIRMWARE tabs are shown, and no lock icon indicator is displayed

#### Scenario: No features
- **WHEN** the user opens the config bottom sheet on a device where `hasFs == false` and `hasOta == false`
- **THEN** neither the FILESYSTEM nor FIRMWARE tab is shown, and no lock icon indicator is displayed regardless of auth mode

### Requirement: Lock Icon is Interactive
The lock icon indicator SHALL show a tooltip or popup when tapped/hovered explaining that device-level password access is needed for filesystem and firmware operations.

#### Scenario: User taps lock icon
- **WHEN** the user taps the lock icon indicator in the tab bar
- **THEN** a tooltip appears with text similar to "Connect with device password for full access"

#### Scenario: Tooltip dismissal
- **WHEN** the user taps elsewhere or waits 3 seconds
- **THEN** the tooltip is dismissed

