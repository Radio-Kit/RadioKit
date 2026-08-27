## Why

The RadioKit Remote Access API is designed to allow automated testing and remote agent control over HTTP on port 7007. On Android devices, accessing `http://<android-ip>:7007/api` directly over LAN currently fails or requires USB ADB port forwarding (`adb forward tcp:7007 tcp:7007`). This happens because the release Android manifest lacks cleartext HTTP enablement and Wi-Fi network permissions, while Android OS Doze mode and Wi-Fi chip power-saving drop unsolicited incoming LAN TCP packets when the device is idle or screen is dimmed.

Enabling direct LAN access ensures agents and test scripts can connect autonomously to any Android tablet/phone hosting RadioKit without USB cabling or ADB bridges.

## What Changes

- **Android Manifest Fixes**:
  - Add `<uses-permission android:name="android.permission.INTERNET" />`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, and `WAKE_LOCK` to `android/app/src/main/AndroidManifest.xml`.
  - Set `android:usesCleartextTraffic="true"` in `AndroidManifest.xml` so HTTP traffic on port 7007 is allowed by Android 9+ Network Security Policy.
- **Android Wi-Fi & High-Performance Lock**:
  - Implement a native Kotlin MethodChannel in `MainActivity.kt` (`com.rambros3d.radiokit/wifi_lock`) to acquire `WifiManager.WifiLock` (HIGH_PERF) and `WifiManager.MulticastLock` whenever the Remote Access server is running.
- **Dart Remote Access Integration**:
  - Connect `RemoteAccessProvider` start/stop lifecycle to acquire and release the Android native Wi-Fi/multicast locks.
  - Dynamically track active Wi-Fi IP address changes and ensure `anyIPv4` (`0.0.0.0`) binding is maintained.

## Capabilities

### New Capabilities

*(None)*

### Modified Capabilities

- `api-server`: Update server requirements to support direct LAN binding, Android cleartext HTTP, and native Wi-Fi locks for un-tethered remote access.

## Impact

- **Android App**: `android/app/src/main/AndroidManifest.xml` and `MainActivity.kt`.
- **Flutter App**: `radiokit-app/lib/providers/remote_access_provider.dart` and `radiokit-app/lib/services/remote_access_service.dart`.
- **Dependencies**: No external third-party pub dependencies added; uses built-in Android `WifiManager` native APIs via Flutter MethodChannel.
