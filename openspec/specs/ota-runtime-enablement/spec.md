# ota-runtime-enablement Specification

## Purpose
TBD - created by archiving change define-urls-ota. Update Purpose after archive.
## Requirements
### Requirement: Runtime OTA Enablement API
The RadioKit library SHALL provide a `RadioKit.enableOTA()` method to enable OTA firmware update processing at runtime on supported architectures.

#### Scenario: Sketch enables OTA
- **WHEN** sketch calls `RadioKit.enableOTA()` during initialization
- **THEN** `RadioKit.isOtaReady()` returns true and incoming OTA frames are accepted

### Requirement: Dynamic OTA Feature Reporting
The Settings protocol handler SHALL dynamically report the `RK_SETTINGS_FEATURE_OTA` (0x01) bit in response to `SETTINGS_CMD_GET_FEATURES` when `RadioKit.isOtaReady()` is true. The companion app SHALL reliably receive this response over BLE by implementing retry logic and diagnostic logging on the features request path.

#### Scenario: App queries features with OTA enabled
- **WHEN** companion app sends `SETTINGS_CMD_GET_FEATURES` (0x03) to a device with `enableOTA()` called
- **THEN** device responds with `FEATURES_DATA` where bit 0 is set to 1

#### Scenario: Features response lost over BLE
- **WHEN** the companion app's first GET_FEATURES request times out or fails on BLE transport
- **THEN** the app retries the request once after a delay of at least 300ms and logs the failure

#### Scenario: Features response received and logged
- **WHEN** the companion app receives a FEATURES_DATA response
- **THEN** the app logs the bitmask value and derived capability flags at success level

