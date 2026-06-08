# NVS Config Persistence — Specification

## Overview

Store three device configuration values (name, description, connection password) in ESP32 NVS (Non-Volatile Storage) so they survive OTA firmware updates. USB flashing preserves NVS as well (no auto-erase).

## Motivation

Currently, `RK_Config.name`, `RK_Config.description`, and `RK_Config.password` are set at compile time in the Arduino sketch. After OTA update, the new firmware boots with whatever defaults are in the binary — user customizations are lost.

Storing these three values in NVS means:
- **OTA update → values persist** (NVS partition is separate from app0/app1 OTA partitions)
- **USB flash → NVS is untouched** (unless user explicitly erases the entire flash or the NVS partition)
- **App can change values at runtime** via a new protocol command, which writes to NVS

## Design Decisions (from user interview)

| Question | Decision |
|----------|----------|
| NVS fallback strategy | Compile-time defaults written to NVS on first boot (when NVS empty). After that, NVS is the source of truth. |
| USB flash behavior | NVS persists. User must explicitly erase NVS to reset. No auto-erase. |
| Password storage | Plaintext in NVS. |
| Writing values from app | New protocol command `CMD_SET_CONF` (0x19). |
| NVS namespace & keys | Namespace `radiokit_cfg`, keys: `rk_name`, `rk_desc`, `rk_pwd`. |
| First boot detection | Check if `rk_name` key exists in NVS. If absent, write compile-time defaults. |
| Set-conf response | ACK (0x05) + automatic re-broadcast of updated `CONF_DATA` (0x02). |
| Password in CONF_DATA | **Removed.** Password no longer included in CONF_DATA payload. |
| NVS partition size | Keep existing `0x5000` (20 KB). |
| OTA overwrite strategy | **Never overwrite NVS.** Compile-time defaults only populate on first init (NVS empty). |
| Authentication mechanism | Higher-level app auth via `CMD_PWD_AUTH`. |
| CONF_DATA protocol version | **Bump to 0x04.** No backward compatibility needed — old firmware won't be used. |
| NVS buffer type | `char[]` fixed-size buffers in `RadioKitClass` (no heap/String). |
| BLE name on CMD_SET_CONF | **Re-advertise immediately.** Use device ID for reconnection (won't change). |
| Phone password storage | On first connection: "Remember password" switch (default ON). Uses `flutter_secure_storage`. If OFF, in-memory only. |
| Flutter UI scope | Editable text fields + Save button for name/desc/password. Fields placed above the Chip info section in the device info sheet. |

## NVS Layout

```
Namespace: "radiokit_cfg"
┌────────────┬─────────────┬──────────┬────────────────────────────┐
│ Key        │ Type        │ Max size │ Default                    │
├────────────┼─────────────┼──────────┼────────────────────────────┤
│ rk_name    │ string      │ 32 B     │ RadioKit.config.name      │
│ rk_desc    │ string      │ 128 B    │ RadioKit.config.desc      │
│ rk_pwd     │ string      │ 32 B     │ RadioKit.config.password  │
└────────────┴─────────────┴──────────┴────────────────────────────┘
```

Total NVS usage: ~200 bytes. Existing 20 KB NVS partition is more than sufficient.

## Protocol Changes

### 1. CONF_DATA (0x02) — Payload change

**Protocol version bumped from 0x03 to 0x04.**

The password field is removed from `_buildConfPayload()` output.

Old payload (v0x03):
```
[ver(1)] [orient(1)] [count(1)] [nameLen(1)] [name...] [descLen(1)] [desc...] [pwdLen(1)] [pwd...] [themeLen(1)] [theme...] [widgets...]
```

New payload (v0x04):
```
[ver(1)] [orient(1)] [count(1)] [nameLen(1)] [name...] [descLen(1)] [desc...] [themeLen(1)] [theme...] [widgets...]
```

The app checks `CONF_DATA[0]` — if 0x04, parse as v4 format (no password). If 0x03, parse as v3 format (has password).

### 2. CMD_SET_CONF (0x19) — App → Device

New command for the app to write config values to the device's NVS.

**Request payload:**
```
[fieldMask(2 LE)] [nameLen(1)] [name...] [descLen(1)] [desc...] [pwdLen(1)] [pwd...]
```

- `fieldMask`: bitmask indicating which fields are present.
  - Bit 0: name present
  - Bit 1: description present
  - Bit 2: password present
- Each string preceded by a 1-byte length. Max lengths: name=32, desc=128, pwd=32.

**Response:** After writing to NVS, the device:
1. Sends ACK (0x05) — echo back fieldMask as single byte status (bit 7 = error).
2. Sends updated CONF_DATA (0x02) automatically.
3. If name changed: updates the BLE advertisement name (re-starts advertising with new `RK_` prefix). Device ID persists, so the app can reconnect using the same ID.

### 3. CMD_PWD_AUTH (0x1A) — App → Device

New command for the app to authenticate with the password after BLE connection.

**Request payload:**
```
[pwdLen(1)] [pwd...]
```

**Response:**
```
[status(1)]  — 0x00 = success, 0x01 = mismatch, 0x02 = already authed
```

**Auth gating:**
- If device has no password (NVS empty string), authentication is automatic — all commands work.
- If a non-empty password is set, the device enforces auth:
  - **Allowed without auth:** `CMD_PWD_AUTH`, `CMD_GET_CONF`, `CMD_GET_FEATURES`
  - **All other commands:** Rejected with auth-error ACK
- The `_authenticated` flag is cleared on disconnect/reconnect.
- Password comparison: `strncmp()` against NVS plaintext value.

## Arduino-Side Implementation

### New file: `RadioKitNVS.h` / `RadioKitNVS.cpp`

Static class wrapping `nvs_flash` ESP-IDF API directly (not Arduino Preferences — lighter and more predictable).

```cpp
class RKNvs {
public:
    static bool init();                          // Open "radiokit_cfg", create if missing
    static bool isInitialized();
    static bool readString(const char* key, char* out, size_t maxLen);   // Read string into buffer
    static bool writeString(const char* key, const char* val);           // Write string
    static bool commit();
    static bool eraseKey(const char* key);
    static bool eraseAll();
    static void close();
};
```

On non-ESP32 platforms, all methods are no-ops returning false/empty. The library compiles without NVS.

### Changes to `RadioKit.h`

Declare new members:
```cpp
private:
    char _nvsName[RADIOKIT_MAX_NAME + 1];      // NVS-backed name buffer
    char _nvsDesc[RADIOKIT_MAX_DESC + 1];      // NVS-backed description buffer
    char _nvsPwd[RADIOKIT_MAX_PWD + 1];        // NVS-backed password buffer
    bool _nvsInitialized;                       // NVS ready flag
    bool _authenticated;                        // Auth gate flag

    // New handler declarations
    void _handleSetConf(const uint8_t* payload, uint16_t len);
    void _handlePwdAuth(const uint8_t* payload, uint16_t len);
```

### Changes to `RadioKit.cpp`

**In `::begin()`:**
1. Call `RKNvs::init()`.
2. Check if `rk_name` exists in NVS:
   - If **not found** (first boot): write `config.name`, `config.description`, `config.password` to NVS, commit.
   - If **found**: copy NVS values into `_nvsName`, `_nvsDesc`, `_nvsPwd` buffers. These override the compile-time values.
3. Set `_nvsInitialized = true`.
4. Set `_authenticated = false` (reset on boot).

**In `_buildConfPayload()`:**
- Read name from `_nvsName` (if NVS initialized) or `config.name` (if NVS not available / first boot before init).
- Same for description.
- Password is NOT included in the payload (v0x04 format).
- Emit protocol version `0x04`.

**New `_handleSetConf()`:**
1. Parse field mask (2 bytes LE).
2. For each bit set in the mask, read the length-prefixed string, write to NVS + copy to `_nvsName` / `_nvsDesc` / `_nvsPwd`.
3. If name changed, rebuild BLE advertisement name (stop advertising, update name, re-start advertising).
4. Send ACK with field mask echoed.
5. Call `_handleGetConf()` to re-broadcast CONF_DATA.

**New `_handlePwdAuth()`:**
1. Read password from payload.
2. Compare against `_nvsPwd` using `strncmp`.
3. If match: set `_authenticated = true`, respond with status `0x00`.
4. If mismatch: respond with status `0x01`.
5. If already authed: respond with status `0x02`.

**In `_onPacket()` dispatch:**
- Add cases for `RK_CMD_SET_CONF` (0x19) and `RK_CMD_PWD_AUTH` (0x1A).
- Add auth gate: if `_authenticated == false` and `_nvsPwd[0] != '\0'` (password is set) and cmd is not one of the allowed commands → respond with auth-error.

**In `startBLE()`:**
- Use `_nvsName` (NVS-backed) instead of `config.name` for the BLE advertisement name prefix `RK_`.

**In `update()`:**
- `_authenticated` is NOT checked here — it only gates incoming commands from the transport.

### Changes to `RadioKitProtocol.h`

```cpp
#define RK_CMD_SET_CONF     0x19
#define RK_CMD_PWD_AUTH     0x1A
```

**Note:** Since there's no backward compatibility requirement, the existing command ID space is clean. Old firmware won't be mixed with new app.

## Flutter-Side Implementation

### Protocol constants (`protocol.dart`)

```dart
const int kCmdSetConf = 0x19;
const int kCmdPwdAuth = 0x1A;
const int kConfProtocolV4 = 0x04;

const int kPwdAuthOk = 0x00;
const int kPwdAuthMismatch = 0x01;
const int kPwdAuthAlready = 0x02;
```

### Protocol service (`protocol_service.dart`)

```dart
Uint8List buildSetConfPacket({String? name, String? description, String? password});
Uint8List buildPwdAuthPacket(String password);
int? parseSetConfAck(Uint8List payload);     // returns fieldMask, or error
int? parsePwdAuthResponse(Uint8List payload); // returns status code
```

Parsers return `null` for invalid/malformed frames.

### DeviceProvider (`device_provider.dart`)

New state and methods:
```dart
bool _authenticated = false;
bool get isAuthenticated => _authenticated;

Future<void> sendSetConf({String? name, String? description, String? password});
Future<bool> authenticate(String password);
```

- `sendSetConf()`: builds packet via protocol service, sends via transport, awaits ACK. After ACK, expects a fresh CONF_DATA re-broadcast.
- `authenticate()`: sends `CMD_PWD_AUTH`, awaits response. Sets `_authenticated` on success. Reports mismatch.
- Wire `kCmdSetConf` and `kCmdPwdAuth` into `_handlePacket()` dispatch.
- Parse `CONF_DATA` version: if `0x04`, skip password field parsing.
- Clear `_authenticated` on disconnect.

### UI — Device Info Sheet (`models_tab.dart`)

In the **INFO tab**, above the chip info section, add editable fields:

```
┌─ DEVICE SETTINGS ──────────────────────┐
│                                         │
│  NAME                    [RadioKit_X]   │
│                                         │
│  DESCRIPTION   [My custom device...]    │
│                                         │
│  PASSWORD              [••••••••]       │
│                                         │
│  [ SAVE ]                               │
└─────────────────────────────────────────┘
```

- Pre-fill fields from `CONF_DATA` values (name, description).
- Password field shows placeholder dots, masked input.
- SAVE button calls `sendSetConf()` with only changed fields.
- Show success/error snackbar after save.
- If name changed, note in snackbar that BLE name will update (may need re-scan).

### UI — Pairing Auth Dialog

When connecting to a device that has a password (detected via features bitmask or by receiving auth-error responses):

1. Show dialog: password text field + "Authenticate" button.
2. Include a "Remember password" switch (default ON).
3. On success: if "Remember" was ON, store in `flutter_secure_storage` with device ID as key.
4. On mismatch: show error, allow retry or cancel connection.
5. On automatic reconnection: check if device has stored password → auto-authenticate using secure storage.

## Persistence Behavior Summary

```
┌────────────────────────────┬──────────────────┬──────────────────────────────┐
│ Scenario                   │ NVS behavior     │ Result                       │
├────────────────────────────┼──────────────────┼──────────────────────────────┤
│ Fresh USB flash (1st boot) │ NVS empty        │ Compile-time defaults → NVS  │
│ OTA update                 │ NVS intact       │ All values survive           │
│ App changes via SET_CONF   │ NVS updated      │ Persist across reboot + OTA  │
│ USB flash (subsequent)     │ NVS intact       │ Old values survive (no wipe) │
│ Explicit erase (esptool)   │ NVS erased       │ Next boot: re-populate from  │
│                            │                  │ compile-time defaults        │
│ App renames via SET_CONF   │ NVS + BLE name   │ BLE re-advertises, app      │
│                            │ updated          │ reconnects by device ID      │
└────────────────────────────┴──────────────────┴──────────────────────────────┘
```

## Implementation Order

1. **Arduino: NVS utility** — `RadioKitNVS.h/.cpp` with nvs_flash wrappers.
2. **Arduino: RadioKit.cpp/h integration** — NVS init in `begin()`, `char[]` buffers, `_buildConfPayload()` v0x04, BLE name re-advertise.
3. **Arduino: Protocol commands** — `CMD_SET_CONF` (0x19), `CMD_PWD_AUTH` (0x1A) handlers and dispatch.
4. **Flutter: Protocol layer** — constants, `buildSetConfPacket()`, `buildPwdAuthPacket()`, parsers.
5. **Flutter: DeviceProvider** — wire commands, `sendSetConf()`, `authenticate()`, v0x04 CONF_DATA parsing.
6. **Flutter: INFO tab UI** — editable name/desc/password fields + save button.
7. **Flutter: Pairing auth** — password dialog, "Remember password" + secure storage.
8. **Testing** — flash with NVS init, verify OTA persistence, verify USB flash preservation, verify name re-advertisement.

## Key Files Changed

| File | Change |
|------|--------|
| `arduino-library/src/connection/RadioKitNVS.h` | NEW — NVS utility class declaration |
| `arduino-library/src/connection/RadioKitNVS.cpp` | NEW — NVS implementation (nvs_flash) |
| `arduino-library/src/RadioKit.h` | Add char[] buffers, new handler declarations, auth flag |
| `arduino-library/src/RadioKit.cpp` | NVS init in begin(), CMD_SET_CONF/BLE/CMD_PWD_AUTH handlers, CONF_DATA v0x04 |
| `arduino-library/src/RadioKitProtocol.h` | Add RK_CMD_SET_CONF (0x19), RK_CMD_PWD_AUTH (0x1A) |
| `flutter-app/lib/models/protocol.dart` | Add kCmdSetConf, kCmdPwdAuth, v0x04 constants |
| `flutter-app/lib/services/protocol_service.dart` | Add buildSetConfPacket(), buildPwdAuthPacket(), parsers |
| `flutter-app/lib/providers/device_provider.dart` | Wire new commands, sendSetConf(), authenticate(), v0x04 parsing |
| `flutter-app/lib/screens/home/models_tab.dart` | Add editable fields + save button in INFO tab above chip info |
| `flutter-app/lib/services/remote_access_service.dart` | (Deferred) HTTP endpoints for set-conf and auth |
