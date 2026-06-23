# Transport Toggles in Designer UI

## Summary

Replace the single BLE/Serial connection type dropdown in the designer inspector with a multi-transport section. Users can independently enable/disable BLE, WiFi, and Cloud transports. WiFi and Cloud transports expose configuration fields (SSID/PASS, Account/Relay URL) that are baked into the generated `RADIOKIT.h` sketch.

---

## 1. Current State

The designer inspector's CONNECTION section currently contains:
- A `ble` / `serial` dropdown (`connectionType`)
- A password field
- OTA toggle (BLE-only)
- Filesystem toggle

The JSON config stores `transport: "BLE"` as a single string.

The Arduino codegen emits `RadioKit.startBLE()` or `RadioKit.startSerial()` based on this single value.

---

## 2. Design Decisions

| Decision | Answer |
|----------|--------|
| Can BLE + WiFi + Cloud coexist? | Yes, all three can be enabled simultaneously |
| Where do SSID/PASS/Account/Relay live? | Hardcoded into `RADIOKIT.h` config, written to NVS on first boot if NVS is empty |
| Is Serial still a designer option? | No. Serial is always enabled. Users remove `#define ENABLE_RK_SERIAL` manually if desired |
| Is OTA transport-dependent? | No, OTA is transport agnostic |
| Backward compat for old JSON? | No migration. Old `transport: "BLE"` schema is broken. Users re-create designs |
| JSON format? | Nested transports object |
| #define placement? | Top of header file, before `#include <RadioKitLib.h>` |
| WiFi start without SSID? | Always emit `startWiFi()` if enabled. Device goes AP mode if no SSID set |

---

## 3. Inspector UI Changes

### 3.1 Section Layout (top to bottom)

```
CONNECTION
  Name *
  Description
  Password
  [OTA toggle]
  [Filesystem toggle]

TRANSPORTS              <-- NEW SECTION
  BLE                   <-- toggle (default: ON)
  WiFi                  <-- toggle (default: OFF)
    STA SSID            <-- text field (shown when WiFi ON)
    STA PASS            <-- password field (shown when WiFi ON)
  Cloud                 <-- toggle (shown only when WiFi ON, default: OFF)
    Account             <-- text field / dropdown (shown when Cloud ON)
    Relay URL           <-- text field (shown when Cloud ON)

MODEL
  Name *
  Description
  Type

CONTROL UI
  ...
```

### 3.2 BLE Toggle

- Simple toggle, always visible in TRANSPORTS section
- Default: enabled (`true`)
- Toggling off removes `#define ENABLE_RK_BLE` from codegen and suppresses `RadioKit.startBLE()` call
- OTA toggle remains visible and functional regardless of BLE state (OTA is transport agnostic)

### 3.3 WiFi Toggle

- Toggle, always visible in TRANSPORTS section
- Default: disabled (`false`)
- When enabled, reveals STA settings fields below it
- Toggling off also hides Cloud section and disables Cloud toggle

### 3.4 STA Settings (shown when WiFi enabled)

- **STA SSID**: Text field, max 32 chars, placeholder "Network name (SSID)"
- **STA PASS**: Password field with visibility toggle, max 64 chars, placeholder "WiFi password (leave empty to keep current)"

### 3.5 Cloud Toggle

- Shown only when WiFi is enabled
- Default: disabled (`false`)
- When enabled, reveals Account and Relay URL fields

### 3.6 Cloud Settings (shown when Cloud enabled)

- **Account**: Text field for Ed25519 public key hex (64 chars), placeholder "Ed25519 public key hex"
- **Relay URL**: Text field, placeholder "relay.radiokit.app:443"

---

## 4. JSON Config Schema

### 4.1 New Format (replaces `transport: "BLE"`)

```json
{
  "version": 1,
  "config": {
    "name": "My Project",
    "description": "...",
    "type": "Locomotive",
    "theme": "dragon",
    "password": "",
    "transports": {
      "ble": {
        "enabled": true
      },
      "wifi": {
        "enabled": false,
        "ssid": "",
        "pass": ""
      },
      "cloud": {
        "enabled": false,
        "account": "",
        "relay": ""
      }
    }
  },
  "canvas": { ... },
  "features": { "ota": false, "filesystem": false },
  "widgets": [ ... ]
}
```

### 4.2 Schema Rules

- `transports` is a required object at `config.transports`
- Each transport sub-object has an `enabled` boolean (default `false`)
- `wifi` has optional `ssid` and `pass` string fields
- `cloud` has optional `account` and `relay` string fields
- The old `transport: "BLE"` / `"SERIAL"` string field is removed
- Backward compatibility: not supported. Old configs will not load correctly

---

## 5. DesignerState Changes

### 5.1 New State Fields

```dart
// Replace _connectionType with individual transport booleans + configs
bool _bleEnabled = true;
bool _wifiEnabled = false;
bool _cloudEnabled = false;

// WiFi config
String _wifiSsid = '';
String _wifiPass = '';

// Cloud config
String _cloudAccount = '';
String _cloudRelay = '';
```

### 5.2 New Getters

```dart
bool get bleEnabled => _bleEnabled;
bool get wifiEnabled => _wifiEnabled;
bool get cloudEnabled => _cloudEnabled;
String get wifiSsid => _wifiSsid;
String get wifiPass => _wifiPass;
String get cloudAccount => _cloudAccount;
String get cloudRelay => _cloudRelay;
```

### 5.3 New Setters

```dart
void setBleEnabled(bool v)          // mutates _mutationCount, notifyListeners
void setWifiEnabled(bool v)         // if !v, also sets _cloudEnabled = false
void setCloudEnabled(bool v)
void setWifiSsid(String v)
void setWifiPass(String v)
void setCloudAccount(String v)
void setCloudRelay(String v)
```

### 5.4 Removed Fields

- `_connectionType` (was `'ble'` or `'serial'`)
- `connectionType` getter
- `setConnectionType()` setter

### 5.5 Serialization

**`toJson()`** — replace:
```dart
'transport': _connectionType.toUpperCase(),
```
with:
```dart
'transports': {
  'ble': {'enabled': _bleEnabled},
  'wifi': {
    'enabled': _wifiEnabled,
    'ssid': _wifiSsid,
    'pass': _wifiPass,
  },
  'cloud': {
    'enabled': _cloudEnabled,
    'account': _cloudAccount,
    'relay': _cloudRelay,
  },
},
```

**`loadFromJson()`** — replace transport parsing with:
```dart
final transports = decoded['config']?['transports'] as Map<String, dynamic>?;
if (transports != null) {
  _bleEnabled = (transports['ble']?['enabled'] as bool?) ?? true;
  _wifiEnabled = (transports['wifi']?['enabled'] as bool?) ?? false;
  _cloudEnabled = (transports['cloud']?['enabled'] as bool?) ?? false;
  _wifiSsid = (transports['wifi']?['ssid'] as String?) ?? '';
  _wifiPass = (transports['wifi']?['pass'] as String?) ?? '';
  _cloudAccount = (transports['cloud']?['account'] as String?) ?? '';
  _cloudRelay = (transports['cloud']?['relay'] as String?) ?? '';
} else {
  // Fallback: old format ignored, use defaults
  _bleEnabled = true;
  _wifiEnabled = false;
  _cloudEnabled = false;
}
```

---

## 6. Codegen Changes (`json_arduino_generator.dart`)

### 6.1 `#define` Directives (top of header, before `#include <RadioKitLib.h>`)

```cpp
// Transports
#define ENABLE_RK_SERIAL
#define ENABLE_RK_BLE
#define ENABLE_RK_WIFI
// #define ENABLE_RK_CLOUD    // (commented out if disabled)
```

Emit logic:
- Serial is always on: emit `#define ENABLE_RK_SERIAL` unconditionally
- If `ble.enabled == true`: emit `#define ENABLE_RK_BLE`
- If `wifi.enabled == true`: emit `#define ENABLE_RK_WIFI`
- If `cloud.enabled == true`: emit `#define ENABLE_RK_CLOUD`
- If disabled: emit the line commented out (e.g., `// #define ENABLE_RK_CLOUD`)

### 6.2 Config Lines (inside `initRadioKit()`)

For WiFi:
```cpp
RadioKit.config.sta_ssid = "MyNetwork";
RadioKit.config.sta_password = "MyPassword";
```

For Cloud:
```cpp
RadioKit.config.cloud_url = "relay.radiokit.app:443";
RadioKit.config.cloud_account = "abcdef1234567890...";
```

Only emit these lines if the respective transport is enabled AND the value is non-empty.

Note: The actual `RK_Config` struct field names are `sta_ssid`, `sta_password`, `cloud_url`, `cloud_account` (not `wifi_ssid`/`wifi_pass`).

### 6.3 Start Calls (inside `initRadioKit()`)

```cpp
RadioKit.begin();

#ifdef ENABLE_RK_SERIAL
  RadioKit.startSerial(Serial);
#endif

#ifdef ENABLE_RK_BLE
  RadioKit.startBLE(RadioKit.config.name);
#endif

#ifdef ENABLE_RK_WIFI
  RadioKit.startWiFi();
#endif

#ifdef ENABLE_RK_CLOUD
  RadioKit.startCloud();
#endif
```

Serial is always on — emit `startSerial(Serial)` under `#ifdef ENABLE_RK_SERIAL`. The user can manually comment out the `#define` to disable serial.

### 6.4 Conditionals

All WiFi fields (ssid, pass) only appear if WiFi is enabled.
All Cloud fields (account, relay) only appear if Cloud is enabled.
BLE start call only appears if BLE is enabled.
Serial start call is always emitted (under `#ifdef ENABLE_RK_SERIAL`).

### 6.5 Cloud + WiFi Validation

The UI prevents Cloud from being enabled without WiFi (Cloud toggle is hidden when WiFi is off). However, if someone hand-edits the JSON to set `cloud.enabled: true` with `wifi.enabled: false`, the codegen should still emit both `#define`s. The Arduino library handles this gracefully — `startCloud()` checks `if (!_wifiActive)` and prints an error, returning early.

### 6.6 `#define` Scope Clarification

The `ENABLE_RK_BLE`, `ENABLE_RK_WIFI`, `ENABLE_RK_CLOUD`, `ENABLE_RK_SERIAL` defines exist ONLY in the generated `RADIOKIT.h` header. They gate the generated `initRadioKit()` code (compile-time preprocessor). The Arduino library itself uses runtime NVS checks (`rk_ble_on`, `rk_wifi_on`, `rk_cloud_on`) for enable/disable — these are independent mechanisms. The `#define` pattern is a codegen-only convention, not a library requirement.

---

## 7. HeaderFileParser Changes (`header_file_parser.dart`)

### 7.1 HeaderAppConfig

Remove `transport` field. Add `transports` map:

```dart
class HeaderAppConfig {
  final String name;
  final String description;
  final String type;
  final String theme;
  final String password;
  final Map<String, dynamic> transports;  // NEW

  factory HeaderAppConfig.fromJson(Map<String, dynamic> json) => HeaderAppConfig(
    // ...
    transports: json['transports'] as Map<String, dynamic>? ?? {
      'ble': {'enabled': true},
      'wifi': {'enabled': false, 'ssid': '', 'pass': ''},
      'cloud': {'enabled': false, 'account': '', 'relay': ''},
    },
  );

  Map<String, dynamic> toJson() => {
    // ...
    'transports': transports,
  };
}
```

### 7.2 `config.transport` Field in `RK_Config`

The Arduino `RK_Config` struct still has `uint8_t transport = RK_TRANSPORT_BLE;`. The codegen should stop emitting this field. The library's `begin()` reads NVS transport keys at runtime, so this struct field becomes vestigial. It can be removed from the library in a future PR — no action needed in this spec.

---

## 8. Inspector UI Implementation (`designer_inspector.dart`)

### 8.1 Remove Old CONNECTION Type Dropdown

Replace the `buildCenterPinnedSelector` for `connectionType` with a new TRANSPORTS section below the existing CONNECTION fields.

### 8.2 New TRANSPORTS Section

```dart
InspectorFieldBuilders.buildSection(tokens, 'TRANSPORTS', [
  // BLE toggle
  InspectorFieldBuilders.buildBoolToggle(
    tokens, 'BLE', widget.state.bleEnabled,
    (v) => widget.state.setBleEnabled(v),
  ),

  // WiFi toggle
  InspectorFieldBuilders.buildBoolToggle(
    tokens, 'WiFi', widget.state.wifiEnabled,
    (v) => widget.state.setWifiEnabled(v),
  ),

  // WiFi STA settings (shown when WiFi enabled)
  if (widget.state.wifiEnabled) ...[
    InspectorFieldBuilders.buildTextField(
      tokens, 'STA SSID', widget.state.wifiSsid,
      (v) => widget.state.setWifiSsid(v),
    ),
    InspectorFieldBuilders.buildTextField(
      tokens, 'STA PASS', widget.state.wifiPass,
      (v) => widget.state.setWifiPass(v),
    ),
  ],

  // Cloud toggle (shown only when WiFi enabled)
  if (widget.state.wifiEnabled)
    InspectorFieldBuilders.buildBoolToggle(
      tokens, 'Cloud', widget.state.cloudEnabled,
      (v) => widget.state.setCloudEnabled(v),
    ),

  // Cloud settings (shown when Cloud enabled)
  if (widget.state.cloudEnabled) ...[
    InspectorFieldBuilders.buildTextField(
      tokens, 'Account', widget.state.cloudAccount,
      (v) => widget.state.setCloudAccount(v),
    ),
    InspectorFieldBuilders.buildTextField(
      tokens, 'Relay URL', widget.state.cloudRelay,
      (v) => widget.state.setCloudRelay(v),
    ),
  ],
]),
```

### 8.3 Layout in `_buildGeneralProperties`

The TRANSPORTS section is inserted between the CONNECTION section (name, desc, password, OTA, FS) and the MODEL section:

```dart
Widget _buildGeneralProperties(RKTokens tokens) {
  return Column(
    children: [
      // CONNECTION section (name, desc, password, OTA, FS)
      InspectorFieldBuilders.buildSection(tokens, 'CONNECTION', [
        // password field stays here
        // OTA toggle stays here (transport agnostic)
        // Filesystem toggle stays here
      ]),

      // TRANSPORTS section (NEW)
      _buildTransportsSection(tokens),

      // MODEL section
      InspectorFieldBuilders.buildSection(tokens, 'MODEL', [
        // ...
      ]),

      // CONTROL UI section
      _buildControlUISection(tokens),

      // TELEMETRY section
      _buildTelemetrySection(tokens),
    ],
  );
}
```

---

### 9.1 `_writeConfigInit` Rewrite

The `_writeConfigInit` method in `json_arduino_generator.dart` currently writes:
```dart
buf.writeln('${indent}RadioKit.config.transport = "${_escapeC(transport)}";');
```

This must be removed. The method should:
1. Remove the `config.transport` line entirely
2. Add conditional WiFi/Cloud config lines based on transport toggles from the JSON
3. Keep existing lines (name, description, type, theme, password, baudrate)

The `baudrate` field (`RadioKit.config.baudrate = 1000000;`) should remain unchanged.

### 9.2 Files to Modify

| File | Change |
|------|--------|
| `flutter-widgets/lib/src/models/designer_state.dart` | Replace `_connectionType` with `_bleEnabled`, `_wifiEnabled`, `_cloudEnabled`, `_wifiSsid`, `_wifiPass`, `_cloudAccount`, `_cloudRelay`. Update `toJson()`, `loadFromJson()`. |
| `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` | Remove BLE/Serial dropdown from CONNECTION. Add TRANSPORTS section with toggles and conditional fields. |
| `radiokit-app/lib/screens/designer/codegen/json_arduino_generator.dart` | Emit `#define` directives at top. Emit conditional config lines (`sta_ssid`, `sta_password`, `cloud_url`, `cloud_account`) and start calls (`startSerial`, `startBLE`, `startWiFi`, `startCloud`) under `#ifdef` guards. Rewrite `_writeConfigInit` to remove `config.transport` and add transport config fields. |
| `radiokit-app/lib/screens/designer/codegen/header_file_parser.dart` | Replace `transport` field with `transports` map in `HeaderAppConfig`. |
| `radiokit-app/lib/screens/designer/designer_screen.dart` | Update `_buildFullHeader()` and code viewer to reflect new schema. |
| `radiokit-app/assets/starter-templates/*.json` | Migrate all 3 starter templates from `transport: "BLE"` to nested `transports` object. |

---

## 10. Testing

- Unit test `DesignerState.toJson()` / `loadFromJson()` round-trips for the new transports schema
- Unit test `JsonArduinoGenerator.generate()` produces correct `#define` blocks and conditional start calls
- Unit test `HeaderAppConfig.fromJson()` / `toJson()` round-trips
- Visual verification: TRANSPORTS section renders correctly with cascading visibility (WiFi off hides STA + Cloud, Cloud off hides Account/Relay)
- Verify existing starter template JSON files are updated to new schema

---

## 11. Starter Template Updates

All starter template JSON files in `radiokit-app/assets/starter-templates/` must be updated from:
```json
"config": { "transport": "BLE", ... }
```
to:
```json
"config": { "transports": { "ble": {"enabled": true}, "wifi": {"enabled": false}, "cloud": {"enabled": false} }, ... }
```

Example — `RC_Controller.json` migration:

Before:
```json
"config": {
  "name": "RC-Controller",
  "description": "Dual-axis RC vehicle controller",
  "type": "RC",
  "transport": "BLE",
  "theme": "default",
  "password": ""
}
```

After:
```json
"config": {
  "name": "RC-Controller",
  "description": "Dual-axis RC vehicle controller",
  "type": "RC",
  "theme": "default",
  "password": "",
  "transports": {
    "ble": { "enabled": true },
    "wifi": { "enabled": false, "ssid": "", "pass": "" },
    "cloud": { "enabled": false, "account": "", "relay": "" }
  }
}
```
