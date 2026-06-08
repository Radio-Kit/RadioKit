# OTA + Model Settings — Pending Implementation Plan

> Generated: 2026-06-08
> Refer to `ota-and-settings-spec.md` for full spec, `ota-and-settings-progress.md` for current state.

---

## Priority Order

| Priority | Task | Depends On | Est. Effort |
|----------|------|------------|-------------|
| P0 | Fix known bugs (CRC, division-by-zero, cancel race) | — | 1 hr |
| P0 | Expose `hasOta` in HTTP API | — | 30 min |
| P1 | DesignerSettings: `features` in `DesignerState` | — | 2 hr |
| P1 | DesignerSettings: FEATURES section in inspector panel | DesignerState | 2 hr |
| P2 | Code generation: features in `JsonArduinoGenerator` | DesignerState | 2 hr |
| P2 | Post-OTA auto-reconnect | — | 3 hr |
| P3 | HTTP API: `POST /api/ota/upload` | uploadFirmware (done) | 2 hr |
| P3 | Flutter testing: verify OTA end-to-end with real device | All above | 2 hr |

---

## P0: Bug Fixes

### Fix 1: CRC-32 operator precedence (device_provider.dart)

**Location**: `flutter-app/lib/providers/device_provider.dart` → `_computeCrc32()`

**Issue**: `if (crc & 1 != 0)` parses as `crc & (1 != 0)` due to Dart operator precedence (`&` binds tighter than `!=`). This causes a runtime type error.

**Fix**: Change to `if ((crc & 1) != 0)`.

**Status**: ✅ Already fixed in current codebase.

### Fix 2: Division-by-zero in `_formatSpeed` (models_tab.dart)

**Location**: `flutter-app/lib/screens/home/models_tab.dart` → `_OtaProgressDialogState._formatSpeed()`

**Issue**: On the first progress callback, `_started` equals `DateTime.now()` (set in `_startOta()`), so `elapsed.inMilliseconds` could be 0. `received / 0 * 1000 / 1024` crashes.

**Fix**:
```dart
final ms = max(1, elapsed.inMilliseconds);
```

**Files to change**: `flutter-app/lib/screens/home/models_tab.dart`

**Test**: Call `_formatSpeed(0, 100000)` immediately after `_started = DateTime.now()`. Should return "0% (0.0 KB/s)" instead of crashing.

### Fix 3: Background timeout on OTA cancel (device_provider.dart)

**Location**: `flutter-app/lib/providers/device_provider.dart` → `uploadFirmware()`

**Issue**: After `abortOta()` nulls `_otaOperationCompleter`, the chunk loop creates a fresh completer on the next iteration and hangs waiting for a response that will never come. The dialog closes immediately on cancel, so the user doesn't see it, but a background timeout runs for ~30s.

**Fix**: Add `bool _otaCancelled = false` flag to `DeviceProvider`. Set it to `true` in `abortOta()`. Check it at the top of each chunk loop iteration and break with a `CancellationException`:

```dart
// In uploadFirmware(), add at top of chunk loop:
if (_otaCancelled) {
  _otaCancelled = false;
  throw Exception('OTA cancelled by user');
}
```

**Files to change**: `flutter-app/lib/providers/device_provider.dart`
- Add `bool _otaCancelled = false;` field
- Set `_otaCancelled = true` in `abortOta()`
- Reset `_otaCancelled = false` at start of `uploadFirmware()`
- Check + throw in chunk loop

**Test**: Start OTA → tap cancel → verify no background timeout in debug logs.

---

## P0: Expose `hasOta` in HTTP API

**Location**: `flutter-app/lib/services/remote_access_service.dart`

**Issue**: The `/api/connection` response includes `hasFs` but not `hasOta`. The `_handleConnection()` handler builds the device object manually and doesn't include `_deviceProvider.hasOta`.

**Fix**: Add `hasOta` field to the device object in `_handleConnection()`:

```dart
'hasOta': _deviceProvider.hasOta,
```

**Files to change**:
- `flutter-app/lib/services/remote_access_service.dart` — add `hasOta` to device JSON in `_handleConnection()`

**Test**:
```bash
# Connect to ESP32 with OTA firmware, then:
curl -s http://127.0.0.1:7007/api/connection | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('device',{}).get('hasOta'))"
# Expected: true
```

---

## P1: Designer Settings — `features` in DesignerState

### Overview

Add a `features` map to `DesignerState` (in `flutter-library/lib/src/models/designer_state.dart`) that mirrors the top-level `features` key in the JSON config schema. This controls what code is emitted by the Arduino code generator.

### Schema

```json
{
  "features": {
    "ota": false,
    "filesystem": false
  }
}
```

### Implementation Steps

#### Step 1: Add fields and getters

**File**: `flutter-library/lib/src/models/designer_state.dart`

```dart
Map<String, dynamic> _features = {'ota': false, 'filesystem': false};

bool get featureOta => (_features['ota'] as bool?) ?? false;
bool get featureFilesystem => (_features['filesystem'] as bool?) ?? false;
```

#### Step 2: Add setters

```dart
void setFeatureOta(bool v) {
  _features['ota'] = v;
  _mutationCount++;
  notifyListeners();
}

void setFeatureFilesystem(bool v) {
  _features['filesystem'] = v;
  _mutationCount++;
  notifyListeners();
}
```

**Undo semantics**: Feature toggles are NOT undoable (same pattern as `_connectionType`, `_modelName`). The undo stack only snapshots `_elements`. Call `_mutationCount++` for unsaved-changes detection.

#### Step 3: Include in serialization

**In `toJson()`**:
```dart
'features': Map<String, dynamic>.from(_features),
```

**In `loadFromJson()`**:
```dart
if (json['features'] is Map) {
  _features = Map<String, dynamic>.from(json['features'] as Map);
}
```

### Files to change
- `flutter-library/lib/src/models/designer_state.dart`

### Test
- Create a new design, toggle OTA on, save → reload → verify OTA stays on
- Toggle both toggles, verify JSON output includes `"features": {"ota": true, "filesystem": false}`

---

## P1: Designer Settings — FEATURES Section in Inspector Panel

### Overview

Add a new FEATURES section to the inspector panel that appears when **no widget is selected** (the "Model Settings" view). Contains OTA and Filesystem toggles.

### Layout

```
┌───────────────────── FEATURES ──────────────────────┐
│                                                       │
│   [Enable OTA] .................. toggle (✔)          │
│   Only available for BLE transport                     │
│                                                       │
│   [Enable Filesystem] ........... toggle               │
│   Include LittleFS support                              │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### Implementation Steps

#### Step 1: Read the inspector file

**File**: `flutter-app/lib/screens/designer/widgets/designer_inspector.dart`

Find where the "no widget selected" view is built (likely in `DesignerInspector.build()` or a helper method).

#### Step 2: Add FEATURES section

Using `InspectorFieldBuilders.buildSection(tokens, 'FEATURES', [...]`:

```dart
InspectorFieldBuilders.buildSection(tokens, 'FEATURES', [
  // Enable OTA
  InspectorFieldBuilders.buildBoolToggle(
    tokens, 'Enable OTA', state.featureOta, (v) {
      state.setFeatureOta(v);
    },
  ),
  // Subtitle (non-interactive)
  Padding(
    padding: const EdgeInsets.only(left: 20, bottom: 8),
    child: Text(
      'Only available for BLE transport',
      style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.5), fontSize: 10),
    ),
  ),
  // Enable Filesystem
  InspectorFieldBuilders.buildBoolToggle(
    tokens, 'Enable Filesystem', state.featureFilesystem, (v) {
      state.setFeatureFilesystem(v);
    },
  ),
  Padding(
    padding: const EdgeInsets.only(left: 20, bottom: 8),
    child: Text(
      'Include LittleFS support for file management',
      style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.5), fontSize: 10),
    ),
  ),
]);
```

#### Step 3: OTA toggle gating

The OTA toggle should be disabled when `state.connectionType != 'ble'`. The `buildBoolToggle` may need an `enabled` parameter. If not available, wrap in a custom widget:

```dart
// For OTA toggle only:
if (state.connectionType == 'ble') {
  InspectorFieldBuilders.buildBoolToggle(...);
} else {
  // Grayed-out version with disabled=true
  IgnoredPointer(
    child: Opacity(
      opacity: 0.4,
      child: InspectorFieldBuilders.buildBoolToggle(...),
    ),
  );
}
```

### Placement

Below the CANVAS section, before any widget-specific sections. The existing model settings likely render in a column/stack order — insert the FEATURES section between CANVAS and the first widget section.

### Files to change
- `flutter-app/lib/screens/designer/widgets/designer_inspector.dart`

### Test
- Open designer with no widget selected
- Verify FEATURES section appears below CANVAS
- Toggle OTA on → verify `state.featureOta` returns true
- Verify OTA toggle is grayed out when connection type is serial

---

## P2: Code Generation — Features in JsonArduinoGenerator

### Overview

`JsonArduinoGenerator.generate()` reads the `features` top-level key from the JSON config and emits `#define` flags + `#include` + initialization code accordingly.

### Implementation Steps

#### Step 1: Read the generator file

**File**: `flutter-app/lib/screens/designer/codegen/json_arduino_generator.dart`

#### Step 2: Parse features

```dart
final features = json['features'] as Map<String, dynamic>? ?? {};
final enableOta = (features['ota'] as bool?) ?? false;
final enableFs = (features['filesystem'] as bool?) ?? false;
```

#### Step 3: Emit code

At the top of the generated `.h` file:

```cpp
// ── Features ────────────────────────────────────────────
#if defined(ESP32) && ${enableOta ? '1' : '0'}
#define RADIOKIT_FEATURE_OTA
#include "connection/RadioKitOTA.h"
#endif

#if __has_include(<LittleFS.h>) && ${enableFs ? '1' : '0'}
#define RADIOKIT_FEATURE_FS
#include <LittleFS.h>
#endif
```

In the initialization section:

```cpp
void setup() {
  RadioKit.begin();
  RadioKit.startBLE("DeviceName");
  
${enableOta ? '  rk_otaSetCallback(RadioKitClass::_onOtaPacket);\n' : ''}
${enableFs ? '  _transport->setFsCallback(RadioKitClass::_onFsPacket);\n  RKFs::begin();\n' : ''}
  
  // ... widget setup ...
}
```

#### Step 4: Handle OTA callback registration

When OTA is enabled and BLE transport is used:
```cpp
  _transport->setOtaCallback(RadioKitClass::_onOtaPacket);
```

### Files to change
- `flutter-app/lib/screens/designer/codegen/json_arduino_generator.dart`

### Test
- Generate code with OTA+FS enabled → verify `#define RADIOKIT_FEATURE_OTA` emitted
- Generate code with both disabled → verify no feature defines
- Compile generated code with PlatformIO

---

## P2: Post-OTA Auto-Reconnect

### Overview

After OTA completes, the ESP32 reboots. The Flutter app should detect the disconnect, scan for the device (by MAC → name → all), and auto-connect.

### Implementation Steps

#### Step 1: Add `otaRebooting` state

**File**: `flutter-app/lib/providers/device_provider.dart`

Add to `DeviceConnectionState` enum:
```dart
enum DeviceConnectionState {
  disconnected,
  connecting,
  fetchingConfig,
  connected,
  otaRebooting,
  error,
}
```

#### Step 2: Handle OTA completion in `uploadFirmware`

After successful OTA_END (before returning true), set the state:

```dart
_connectionState = DeviceConnectionState.otaRebooting;
notifyListeners();
// Wait for BLE disconnect
final disconnected = await _waitForDisconnect(Duration(seconds: 10));
if (disconnected) {
  await _reconnectAfterOta();
}
```

#### Step 3: `_waitForDisconnect()`

Listen for BLE disconnect or poll `_transport.isConnected`:

```dart
Future<bool> _waitForDisconnect(Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!_transport.isConnected) return true;
    await Future.delayed(const Duration(milliseconds: 500));
  }
  return false;
}
```

#### Step 4: `_reconnectAfterOta()`

Scan strategy (in order of preference):
1. MAC address scan (if platform exposes it)
2. Name-prefix scan (`RK_*`)
3. Any RadioKit device advertising FFE0 service

```dart
Future<void> _reconnectAfterOta() async {
  final originalId = _connectedDevice?.id;
  final originalName = _configName;
  
  // Start scanning
  final bleProvider = /* inject or access */;
  await bleProvider.startScan();
  
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    // Check by original MAC
    if (originalId != null) {
      final match = bleProvider.devices.where((d) => d.id == originalId).firstOrNull;
      if (match != null) {
        await _transport.connect(match.id);
        return;
      }
    }
    // Fallback: name prefix
    if (originalName != null) {
      final match = bleProvider.devices.where((d) => d.name.contains(originalName ?? '')).firstOrNull;
      if (match != null) {
        await _transport.connect(match.id);
        return;
      }
    }
    await Future.delayed(const Duration(seconds: 1));
  }
  
  // Timeout
  _connectionState = DeviceConnectionState.disconnected;
  _errorMessage = 'OTA reboot timeout — device not found';
  notifyListeners();
}
```

#### Step 5: Cancel button for "Rebooting..." state

In the `_OtaProgressDialog`, after success, show:
```dart
Text('Rebooting...')
ElevatedButton(
  onPressed: () {
    // Exit otaRebooting state, return to models screen
    _deviceProvider.disconnect();
    Navigator.of(context).pop();
  },
  child: Text('CANCEL'),
)
```

#### Step 6: Update `_handleConnectionLost` for OTA state

When disconnect happens during `otaRebooting` state, don't clear everything — the reconnect flow is handling it.

```dart
void _handleConnectionLost(String reason) {
  if (_connectionState == DeviceConnectionState.otaRebooting) {
    // Don't clear state — reconnect is in progress
    return;
  }
  // ... existing disconnect logic ...
}
```

#### Step 7: UI handling

In `control_screen.dart`, add a case for `otaRebooting`:
```dart
case DeviceConnectionState.otaRebooting:
  return _buildLoadingState('Device rebooting — reconnecting...');
```

### Files to change
- `flutter-app/lib/providers/device_provider.dart`
- `flutter-app/lib/screens/control_screen.dart`
- `flutter-app/lib/screens/home/models_tab.dart`
- `flutter-app/lib/screens/scan_screen.dart`
- `flutter-app/lib/screens/home/pair_tab.dart`

### Test
- Flash firmware via OTA → verify app detects disconnect → scans → reconnects
- Cancel reconnect → verify app returns to models screen
- Timeout → verify error message

---

## P3: HTTP API — `POST /api/ota/upload`

### Overview

Accept a firmware binary via HTTP POST and relay it to the device via the existing `uploadFirmware()` method in `DeviceProvider`.

### Implementation Steps

#### Step 1: Add route

**File**: `flutter-app/lib/services/remote_access_service.dart`

```dart
router.post('/api/ota/upload', _handleOtaUpload);
```

#### Step 2: Add handler

```dart
Future<Response> _handleOtaUpload(Request request) async {
  if (!_deviceProvider.isConnected) {
    return _error('not_connected', 'Not connected to a device', status: 503);
  }
  
  final body = await _parseBody(request);
  final dataB64 = body['data'] as String?;
  if (dataB64 == null) {
    return _error('invalid_params', 'data (base64 encoded firmware) is required');
  }
  
  try {
    final firmware = base64Decode(dataB64);
    
    // Progress tracking via SSE or polling
    _otaProgress = (0, firmware.length);
    
    await _deviceProvider.uploadFirmware(
      firmware,
      onProgress: (received, total) {
        _otaProgress = (received, total);
      },
    );
    
    return _json({
      'ok': true,
      'size': firmware.length,
    });
  } catch (e) {
    return _error('ota_failed', e.toString(), status: 500);
  }
}
```

#### Step 3: Follow-mode route

Add to `_followRoute()`:
```dart
if (path.startsWith('/api/ota/')) return '/control';
```

### Files to change
- `flutter-app/lib/services/remote_access_service.dart`

### Test
```bash
# Encode firmware as base64
FIRMWARE_B64=$(base64 -w0 firmware.bin)

# Upload
curl -s -X POST http://127.0.0.1:7007/api/ota/upload \
  -H 'Content-Type: application/json' \
  -d "{\"data\": \"$FIRMWARE_B64\"}"
```

---

## P3: End-to-End Testing

### Prerequisites
- Firmware flashed with OTA support (BasicSwitch example)
- APK installed with OTA support
- Device connected via BLE

### Test Scenarios

#### Scenario 1: Feature Detection
1. Connect to ESP32 via BLE
2. Check HTTP API: `curl -s http://127.0.0.1:7007/api/connection | jq .device.hasOta`
3. **Expected**: `true`

#### Scenario 2: OTA Button Visibility
1. Connect to ESP32 via BLE
2. Open models tab in app
3. **Expected**: UPDATE FIRMWARE button visible below FILESYSTEM button

#### Scenario 3: OTA Upload Success
1. Build a test firmware: `pio run` in BasicSwitch example
2. Tap UPDATE FIRMWARE → select firmware.bin
3. **Expected**: Progress bar shows upload progress (percentage + KB/s)
4. **Expected**: "Verifying..." → "Update complete — device rebooting..."
5. **Expected**: App reconnects after reboot

#### Scenario 4: OTA Cancel
1. Start OTA upload
2. Tap CANCEL immediately
3. **Expected**: Dialog closes, device continues normal operation
4. **Expected**: No background timeout in logs

#### Scenario 5: OTA Error Recovery
1. Flash corrupt firmware binary (truncated)
2. **Expected**: CRC32 mismatch → error dialog → device reboots into old firmware

### Known Issues to Track
- Post-OTA reconnect may fail if ESP32 uses random BLE address
- Large firmware (>1MB) may hit BLE MTU/throughput limits
- Cancel race may leave orphaned completers (see Fix 3)

---

## Summary of Files to Change by Task

| Task | Files | Total |
|------|-------|-------|
| **Bug fixes** | models_tab.dart, device_provider.dart | 2 |
| **HTTP API hasOta** | remote_access_service.dart | 1 |
| **DesignerState features** | designer_state.dart (flutter-library) | 1 |
| **Inspector FEATURES** | designer_inspector.dart | 1 |
| **Code generation** | json_arduino_generator.dart | 1 |
| **Post-OTA reconnect** | device_provider.dart, control_screen.dart, models_tab.dart, scan_screen.dart, pair_tab.dart | 5 |
| **HTTP OTA upload** | remote_access_service.dart | 1 |

**Total pending files**: ~12 files across 3 packages (flutter-app, flutter-library)
