# ble-var-update-no-ack Specification

## Purpose
TBD - created by archiving change ble-ack-and-subscription-optimization. Update Purpose after archive.
## Requirements
### Requirement: Variable Update ACK Suppression
The `RadioKitClass::_handleVarUpdate` method SHALL NOT transmit automatic `RK_CMD_ACK` packets in response to incoming `RK_CMD_VAR_UPDATE` commands. Client applications (including `DeviceProvider`) SHALL transmit `VAR_UPDATE` commands as write-without-response packets directly, without maintaining ACK wait retry loops or falling back to `GET_VARS` queries upon missing ACKs.

#### Scenario: Continuous input streaming
- **WHEN** the client streams continuous variable update packets (`RK_CMD_VAR_UPDATE`) for sliders or control inputs
- **THEN** the firmware updates widget inputs and shadow buffers immediately without emitting reverse ACK notifications over BLE or other transports

#### Scenario: Client-side variable update dispatch
- **WHEN** the user interacts with any input control widget in the companion app
- **THEN** `DeviceProvider` constructs and transmits the `VAR_UPDATE` packet directly over the active transport without registering an ACK-wait timeout or triggering retry escalation

