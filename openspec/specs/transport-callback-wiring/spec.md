# transport-callback-wiring Specification

## Purpose
TBD - created by archiving change fix-settransport-missing-callbacks. Update Purpose after archive.

## Requirements

### Requirement: All callbacks wired on every setTransport call
`DeviceProvider.setTransport()` SHALL set all five protocol callbacks (`onPacketReceived`, `onFsPacketReceived`, `onOtaPacketReceived`, `onSettingsPacketReceived`, `onConnectionLost`) on every invocation, including the early-return path when the transport instance is unchanged.

#### Scenario: First connection sets all callbacks
- **WHEN** `DeviceProvider` is constructed with a transport and `setTransport()` is called
- **THEN** all five callbacks are assigned to the transport instance

#### Scenario: Same transport re-applied sets all callbacks
- **WHEN** `setTransport()` is called with the same transport instance (early-return path)
- **THEN** `onSettingsPacketReceived` is set to the device provider's settings handler
- **AND** `onFsPacketReceived` is set to the device provider's FS handler
- **AND** `onOtaPacketReceived` is set to the device provider's OTA handler

#### Scenario: Features response routed after setTransport
- **WHEN** the device sends a `SETTINGS_FEATURES_DATA` response after `setTransport()` completes
- **THEN** the response is delivered to `DeviceProvider._handleSettingsFeaturesData`
