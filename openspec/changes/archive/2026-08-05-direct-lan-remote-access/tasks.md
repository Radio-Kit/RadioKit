## 1. Android Manifest Permissions & Security Policy

- [x] 1.1 Add `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, and `WAKE_LOCK` permissions to `android/app/src/main/AndroidManifest.xml`.
- [x] 1.2 Change `android:usesCleartextTraffic="false"` to `android:usesCleartextTraffic="true"` in `android/app/src/main/AndroidManifest.xml`.

## 2. Native Android Wi-Fi & Multicast Lock MethodChannel

- [x] 2.1 Implement MethodChannel (`com.rambros3d.radiokit/wifi_lock`) in `MainActivity.kt` with `acquireWifiLock` and `releaseWifiLock` methods.
- [x] 2.2 Acquire `WifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, ...)` and `createMulticastLock(...)` in `MainActivity.kt`.

## 3. Flutter RemoteAccessProvider Integration

- [x] 3.1 Call `acquireWifiLock` MethodChannel method when `RemoteAccessProvider.start()` initializes the HTTP server on Android platform.
- [x] 3.2 Call `releaseWifiLock` MethodChannel method when `RemoteAccessProvider.stop()` shuts down the HTTP server.

## 4. Verification

- [x] 4.1 Run Flutter tests to verify `RemoteAccessProvider` lifecycle handles MethodChannel calls cleanly across desktop and Android.
- [x] 4.2 Validate direct HTTP access (`GET http://<android-ip>:7007/api/status`) over LAN without ADB forwarding.
