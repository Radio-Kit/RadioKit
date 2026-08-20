# parallel-ble-subscriptions Specification

## Purpose

Accelerate BLE connection establishment by concurrently subscribing to notifications across all discovered characteristics.
## Requirements
### Requirement: Concurrent BLE characteristic subscriptions
When connecting to a RadioKit BLE device, the app SHALL subscribe to notifications across all discovered characteristics sequentially using `await` in order to comply with Android single-operation GATT descriptor constraints, and SHALL request `BleConnectionPriority.highPerformance` to minimize link latency.

#### Scenario: Device with all standard characteristics discovered
- **WHEN** a BLE connection is established and characteristics (widget, fs, ota, settings, print) are discovered
- **THEN** notification subscriptions for all discovered characteristics are executed sequentially in an `await` loop, preventing GATT 17 (GATT_BUSY) descriptor errors, and `UniversalBle.requestConnectionPriority(deviceId, BleConnectionPriority.high)` is called to establish low-latency connection parameters

