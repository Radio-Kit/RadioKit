## ADDED Requirements

### Requirement: Firmware Reports Compile-Time Transport Features
The firmware `RadioKitClass::_handleSettingsGetFeatures()` handler SHALL report transport feature bits (`RK_SETTINGS_FEATURE_BLE`, `RK_SETTINGS_FEATURE_WIFI`, `RK_SETTINGS_FEATURE_CLOUD`) according to whether the transport is compiled in via build defines (`RK_ENABLE_BLE`, `RK_ENABLE_WIFI`, `RK_ENABLE_CLOUD`), regardless of whether the transport is currently connected or active.

#### Scenario: Device without WiFi compiled reports features
- **WHEN** the host requests the features bitmask from a device compiled with `RK_ENABLE_BLE` but without `RK_ENABLE_WIFI`
- **THEN** the returned bitmask SHALL include `RK_SETTINGS_FEATURE_BLE` and SHALL NOT include `RK_SETTINGS_FEATURE_WIFI` or `RK_SETTINGS_FEATURE_CLOUD`.

#### Scenario: Device with WiFi compiled reports features
- **WHEN** the host requests the features bitmask from a device compiled with `RK_ENABLE_WIFI`
- **THEN** the returned bitmask SHALL include `RK_SETTINGS_FEATURE_WIFI`.

### Requirement: Firmware Rejects NVS Writes For Uncompiled Transports
The firmware `RadioKitClass::_handleSettingsNvsRawWrite()` handler SHALL reject write requests for transport configuration keys if the corresponding transport is not compiled in.

#### Scenario: Writing WiFi enable key on non-WiFi build
- **WHEN** the host attempts to write key `rk_wifi_on` on a build where `RK_ENABLE_WIFI` is not defined
- **THEN** the firmware returns an error response and does not write to NVS.

#### Scenario: Writing BLE enable key on non-BLE build
- **WHEN** the host attempts to write key `rk_ble_on` on a build where `RK_ENABLE_BLE` is not defined
- **THEN** the firmware returns an error response and does not write to NVS.

### Requirement: Companion App Hides Uncompiled Transports in Settings Tab
The companion app `SettingsTab` SHALL conditionally render transport management sections based on the device's feature capability flags (`hasBle`, `hasWifi`, `hasCloud`).

#### Scenario: Connecting to device without WiFi
- **WHEN** the user opens the Device Config bottom sheet on a device with `hasWifi == false`
- **THEN** the WiFi section (and Cloud sub-section) SHALL NOT be rendered in the Settings Tab.

#### Scenario: Connecting to device with WiFi
- **WHEN** the user opens the Device Config bottom sheet on a device with `hasWifi == true`
- **THEN** the WiFi card SHALL be rendered in the Settings Tab, and the Cloud section SHALL only be rendered if `hasCloud == true`.

### Requirement: Companion App Skips Unnecessary NVS Key Queries
When loading transport settings in `SettingsTab`, the companion app SHALL NOT request NVS keys for uncompiled transports.

#### Scenario: Opening settings tab on non-WiFi device
- **WHEN** the Settings Tab loads transport NVS keys on a device where `hasWifi == false`
- **THEN** queries for `rk_wifi_on`, `rk_sta_ssid`, `rk_sta_pwd`, `rk_cloud_url`, and `rk_cloud_account` are skipped.
