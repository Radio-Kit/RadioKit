## Context

The RadioKit Flutter app hosts an HTTP server (`shelf_io`) listening on port 7007 for test automation and remote control. On Android devices, incoming LAN connections fail when USB ADB port forwarding is not active. This is caused by:
1. Missing `INTERNET`, `ACCESS_WIFI_STATE`, and `CHANGE_WIFI_MULTICAST_STATE` permissions in `android/app/src/main/AndroidManifest.xml`.
2. Explicit setting `android:usesCleartextTraffic="false"` in `AndroidManifest.xml`, which blocks HTTP traffic at the OS level on Android 9+.
3. Wi-Fi chip power-saving mode dropping unsolicited TCP SYN packets when the Android device is idle.

## Goals / Non-Goals

**Goals:**
- Enable direct HTTP API access over LAN on port 7007 without requiring ADB port forwarding.
- Acquire native Android `WifiLock` and `MulticastLock` whenever the Remote Access server is started.
- Maintain cleartext HTTP compatibility on Android 9+ for local network REST API access.
- Retain backward compatibility with desktop (Linux/macOS/Windows) and existing test workflows.

**Non-Goals:**
- Implementing HTTPS/TLS on port 7007 (Remote Access API remains LAN-only without auth as documented).
- Modifying BLE or Cloud relay transport protocols.

## Decisions

### Decision 1: Add Network Permissions & `usesCleartextTraffic="true"` in Main Android Manifest

- **Choice**: Add `<uses-permission android:name="android.permission.INTERNET" />`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, and `WAKE_LOCK` to `android/app/src/main/AndroidManifest.xml`, and set `android:usesCleartextTraffic="true"`.
- **Rationale**: `debug/AndroidManifest.xml` previously contained `INTERNET`, leaving release builds unable to bind network sockets properly. `usesCleartextTraffic="true"` is mandatory on Android 9+ for HTTP server sockets on local IP addresses.
- **Alternatives Considered**: Using Network Security Config XML. Direct attribute setting in `AndroidManifest.xml` is cleaner and zero-overhead for local LAN server use cases.

### Decision 2: Native Flutter MethodChannel for Android `WifiLock` and `MulticastLock`

- **Choice**: Implement a native Kotlin MethodChannel (`com.rambros3d.radiokit/wifi_lock`) in `MainActivity.kt`.
- **Rationale**: Android's `WifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, ...)` and `createMulticastLock(...)` ensure the Android Wi-Fi radio stays active and processes incoming TCP packets even when the screen is dimmed.
- **Alternatives Considered**: Using third-party pub plugins. A lightweight 30-line MethodChannel in `MainActivity.kt` avoids introducing extra unmaintained external dependencies.

### Decision 3: Tie Wi-Fi Lock Lifecycle to `RemoteAccessProvider`

- **Choice**: Invoke `acquireWifiLock()` when `RemoteAccessProvider.start()` succeeds, and `releaseWifiLock()` when `stop()` is called.
- **Rationale**: Prevents battery drain by acquiring locks ONLY when the user or debug mode has enabled the Remote Access API.

## Risks / Trade-offs

- **[Increased Power Consumption on Android]** → Mitigated by acquiring `WifiLock` and `MulticastLock` strictly while `RemoteAccessProvider` server is active (`_isRunning == true`), and releasing them immediately when stopped.
- **[AP Isolation on User Routers]** → If a user's Wi-Fi router explicitly enables Wi-Fi Client Isolation, LAN devices still cannot reach the tablet. ADB port forwarding remains a documented backup fallback.

## Migration Plan

1. Update `AndroidManifest.xml` with permissions and `usesCleartextTraffic="true"`.
2. Add MethodChannel handler in `MainActivity.kt` for `acquireWifiLock` and `releaseWifiLock`.
3. Wire MethodChannel calls in `RemoteAccessProvider` in `lib/providers/remote_access_provider.dart`.
4. Rebuild and deploy Android APK to device. Test `curl http://<android-ip>:7007/api/status` over Wi-Fi without ADB forwarding active.
