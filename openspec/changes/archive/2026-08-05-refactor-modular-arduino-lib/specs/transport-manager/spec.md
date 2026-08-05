## ADDED Requirements

### Requirement: Centralized Multi-Transport Management
The library SHALL provide a `TransportManager` to manage active communication backends (Serial, BLE, WiFi, Cloud) and broadcast state updates across connected transports.

#### Scenario: Pushing widget update to all active connections
- **WHEN** `RadioKit.pushUpdate(widgetId)` is called
- **THEN** `TransportManager` transmits the update packet on all connected and active transport channels.
