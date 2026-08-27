## ADDED Requirements

### Requirement: Direct LAN accessibility over HTTP

The Remote Access API server SHALL be accessible to any device on the local network (LAN) over HTTP on port 7007 without requiring USB ADB port forwarding.

#### Scenario: LAN client accesses status endpoint directly

- **WHEN** a client on the local network sends `GET http://<android-ip>:7007/api/status`
- **THEN** server responds with `200 OK` and server status JSON containing version, uptime, port 7007, and localIp

#### Scenario: Android manifest allows cleartext HTTP

- **WHEN** Android app is compiled in release mode and starts Remote Access server
- **THEN** Android OS Network Security Policy allows incoming unencrypted HTTP traffic on port 7007

### Requirement: Native Android Wi-Fi and Multicast Lock

The system SHALL acquire high-performance Wi-Fi lock and Multicast lock on Android while the Remote Access server is active.

#### Scenario: Server start acquires Wi-Fi lock

- **WHEN** Remote Access server is started on Android
- **THEN** native MethodChannel acquires `WifiManager.WifiLock` (HIGH_PERF) and `WifiManager.MulticastLock` to prevent Wi-Fi chip power-saving sleep

#### Scenario: Server stop releases Wi-Fi lock

- **WHEN** Remote Access server is stopped on Android
- **THEN** native MethodChannel releases `WifiLock` and `MulticastLock`
