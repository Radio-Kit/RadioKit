# ble-features-diagnostic Specification

## Purpose
TBD - created by archiving change fix-ble-features-tabs. Update Purpose after archive.
## Requirements
### Requirement: Features Request Logs All Failure Modes
The companion app `_requestFeatures()` method SHALL log a descriptive message for each failure mode: write failure, timeout, and parse error. Log messages SHALL include the failure type and the device identifier.

#### Scenario: Write failure is logged
- **WHEN** `_requestFeatures()` fails to write the GET_FEATURES frame to the transport
- **THEN** the app logs a warning-level message containing "GET_FEATURES write failed" and the exception message

#### Scenario: Response timeout is logged
- **WHEN** `_requestFeatures()` does not receive a FEATURES_DATA response within the timeout window
- **THEN** the app logs a warning-level message containing "GET_FEATURES timeout"

#### Scenario: Parse error is logged
- **WHEN** `_requestFeatures()` receives a FEATURES_DATA response but `parseFeaturesData()` returns null
- **THEN** the app logs an error-level message containing "FEATURES_DATA parse failed"

### Requirement: Features Request Logs Successful Response
The companion app `_handleSettingsFeaturesData()` method SHALL log the received features bitmask value and the derived capability flags (hasFs, hasOta, hasBle, hasWifi, hasCloud, hasDevicePassword, hasUserPassword).

#### Scenario: Features bitmask received
- **WHEN** the firmware responds with a FEATURES_DATA frame
- **THEN** the app logs a success-level message containing the hex bitmask value and each capability flag name with its boolean value

### Requirement: Features Request Retries on Timeout
The companion app `_requestFeatures()` method SHALL retry the GET_FEATURES request once if the first attempt times out. The retry SHALL occur after a delay of at least 300ms to allow the BLE TX queue to drain.

#### Scenario: First attempt times out, retry succeeds
- **WHEN** the first GET_FEATURES request times out within 2 seconds
- **THEN** the app waits at least 300ms and sends a second GET_FEATURES request

#### Scenario: Both attempts time out
- **WHEN** both the first and second GET_FEATURES requests time out
- **THEN** `_deviceFeatures` remains at its default value (0) and the app logs a warning indicating both attempts failed

#### Scenario: First attempt succeeds
- **WHEN** the first GET_FEATURES request receives a response within 2 seconds
- **THEN** the app does NOT send a retry request

### Requirement: Features Request Uses Appropriate Timeout
The companion app `_requestFeatures()` method SHALL use a timeout of at least 3 seconds per attempt (increased from the current 2 seconds) to accommodate firmware processing delays during connection setup.

#### Scenario: Timeout value
- **WHEN** `_requestFeatures()` sends a GET_FEATURES request
- **THEN** it waits up to 3 seconds for a response before timing out

