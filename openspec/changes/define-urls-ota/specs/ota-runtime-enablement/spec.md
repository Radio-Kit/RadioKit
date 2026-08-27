## ADDED Requirements

### Requirement: Runtime OTA Enablement API
The RadioKit library SHALL provide a `RadioKit.enableOTA()` method to enable OTA firmware update processing at runtime on supported architectures.

#### Scenario: Sketch enables OTA
- **WHEN** sketch calls `RadioKit.enableOTA()` during initialization
- **THEN** `RadioKit.isOtaReady()` returns true and incoming OTA frames are accepted

### Requirement: Dynamic OTA Feature Reporting
The Settings protocol handler SHALL dynamically report the `RK_SETTINGS_FEATURE_OTA` (0x01) bit in response to `SETTINGS_CMD_GET_FEATURES` when `RadioKit.isOtaReady()` is true.

#### Scenario: App queries features with OTA enabled
- **WHEN** companion app sends `SETTINGS_CMD_GET_FEATURES` (0x03) to a device with `enableOTA()` called
- **THEN** device responds with `FEATURES_DATA` where bit 0 is set to 1
