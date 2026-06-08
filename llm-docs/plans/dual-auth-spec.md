# Dual-Auth Specification: User Mode + Admin Mode

## Overview

RadioKit currently has a single-password auth model. This spec extends it to a dual-password system:

- **Connection password** — unlocks **user mode**: widget control and monitoring only.
- **Admin password** — unlocks **admin mode**: full access including NVS config editing, Filesystem (FS), and OTA firmware updates.
- **No backward compatibility needed** — old firmware without dual-auth support will be treated by the new app at compile-time defaults (no password → no gate).

When no admin password is set and the user authenticates with the connection password, the session auto-upgrades to admin mode.

---

## 1. NVS Storage

### 1.1 Two separate NVS keys

| Key | C++ constant | Purpose |
|---|---|---|
| `nvs_pwd` | `RK_NVS_KEY_PWD` | Connection password (user mode) |
| `nvs_admin_pwd` | `RK_NVS_KEY_ADMIN_PWD` | Admin password (admin mode) |

### 1.2 Firmware buffers

```cpp
char _nvsPwd[RADIOKIT_MAX_PWD + 1];       // connection password
char _nvsAdminPwd[RADIOKIT_MAX_PWD + 1];   // admin password
```

### 1.3 Boot auth state

- If `_nvsAdminPwd[0] == '\0'` (no admin pwd) → `_authenticatedAdmin = true` (pre-authed admin).
- If `_nvsPwd[0] == '\0'` and `_nvsAdminPwd[0] == '\0'` → `_authenticated = true` (pre-authed user) AND `_authenticatedAdmin = true` (pre-authed admin).
- If `_nvsPwd[0] == '\0'` but `_nvsAdminPwd[0] != '\0'` → `_authenticated = true` (user pre-authed), `_authenticatedAdmin = false` (admin requires auth).

### 1.4 Auth state flags

```cpp
bool _authenticated;        // user mode authenticated
bool _authenticatedAdmin;   // admin mode authenticated
```

---

## 2. Feature Bitmask (extended)

| Bit | Current | New |
|---|---|---|
| Bit 0 | `RF_FEATURE_OTA` | `RK_FEATURE_OTA` |
| Bit 1 | `RK_FEATURE_FILESYSTEM` | `RK_FEATURE_FILESYSTEM` |
| Bit 2 | `RK_FEATURE_HAS_PASSWORD` | `RK_FEATURE_HAS_CONN_PWD` (connection pwd set) |
| Bit 3 | — | `RK_FEATURE_HAS_ADMIN_PWD` (admin pwd set) |

In `_handleGetFeatures()`:
```cpp
bitmask |= RK_FEATURE_HAS_CONN_PWD;   // if _nvsPwd[0] != '\0'
bitmask |= RK_FEATURE_HAS_ADMIN_PWD;  // if _nvsAdminPwd[0] != '\0'
```

Corresponding Dart constants:
```dart
const int kFeatureHasConnPassword = 1 << 2;
const int kFeatureHasAdminPassword = 1 << 3;
```

### 2.1 App-side getters

```dart
bool get hasConnPassword => (_deviceFeatures & kFeatureHasConnPassword) != 0;
bool get hasAdminPassword => (_deviceFeatures & kFeatureHasAdminPassword) != 0;
bool get isAdminMode => _authenticatedAdmin;
bool get isUserMode => _authenticated && !_authenticatedAdmin;
```

---

## 3. Auth Gate Protocol

### 3.1 Connection auth (unchanged)

- **Command**: `CMD_PWD_AUTH` (0x1A)
- **Payload**: `[pwd_len(1)] [password(pwd_len)]`
- **Response**: ACK with `RK_PWD_AUTH_OK` (0x00) or `RK_PWD_AUTH_MISMATCH` (0x01)
- **Firmware**: Compares against `_nvsPwd`. On match, sets `_authenticated = true`.

### 3.2 Admin auth (re-uses CMD_PWD_AUTH with flag)

- **Command**: `CMD_PWD_AUTH` (0x1A)
- **Payload**: `[pwd_len(1)] [password(pwd_len)] [flags(1)]` where `flags = 0x01` for admin auth
- **Response**: ACK with same status codes
- **Firmware**: When `flags & 0x01`, compares against `_nvsAdminPwd`. On match, sets `_authenticatedAdmin = true`.

### 3.3 Protocol constants

```cpp
// In PWD_AUTH payload
#define RK_PWD_AUTH_FLAG_ADMIN (1 << 0)

// In features bitmask
#define RK_FEATURE_HAS_CONN_PWD  (1 << 2)
#define RK_FEATURE_HAS_ADMIN_PWD (1 << 3)
```

---

## 4. Auth Gate (Firmware)

### 4.1 `_onPacket` dispatch rules

The auth gate currently blocks all commands except `CMD_PWD_AUTH`, `CMD_GET_CONF`, and `CMD_GET_FEATURES` when not authenticated.

**New rules** (applied in order):

| State | Allowed commands |
|---|---|
| Not user-authenticated | `CMD_PWD_AUTH`, `CMD_GET_CONF`, `CMD_GET_FEATURES` |
| User-authenticated (not admin) | All user-mode commands + `CMD_PWD_AUTH` (for admin upgrade) |
| Admin-authenticated | All commands |

**User-mode commands** (allowed after user auth):
- `CMD_GET_CONF`, `CMD_GET_VARS`, `CMD_GET_META` — read config
- `CMD_PING`, `CMD_ACK` — keep-alive
- `CMD_SET_INPUT`, `CMD_VAR_UPDATE`, `CMD_META_UPDATE` — widget interaction
- `CMD_GET_TELEMETRY`, `CMD_BLE_INFO`, `CMD_GET_FEATURES`, `CMD_GET_CHIP_INFO` — info queries
- `CMD_SET_INPUT` — widget input (app → device)

**Admin-only commands** (blocked in user mode):
- `CMD_SET_CONF` (0x19) — NVS config editing (name/desc/passwords)
- `CMD_FACTORY_RESET` (0x1B) — factory reset
- FS protocol (0xAA) frames — filesystem access
- OTA protocol (0xBB) frames — firmware updates

### 4.2 FS gate in user mode

When in user mode, FS frames (0xAA) received by the BLE/Serial transport byte feeder should still be parsed (to avoid corrupting the byte stream), but the FS dispatch should immediately reject with `RK_FS_ERR_ACCESS_DENIED` (0x04).

### 4.3 OTA gate in user mode

Same as FS — parse the 0xBB frames for stream integrity, but reject all OTA sub-commands with `RK_OTA_ERR_INVALID_STATE`.

### 4.4 Auth timeout

The 60s auth timeout (from `_startAuthTimeout()` in `DeviceProvider`) applies **only to the connection password gate** (user mode). Once the user authenticates with the connection password, the timeout is cancelled. Admin upgrade is separate and not timed.

---

## 5. Flutter App Changes

### 5.1 Password Gate UI

- **Single password field** — one text field at connection time.
- **Auto-detect mode**: The entered password is first tried as connection auth via `CMD_PWD_AUTH` (no flag). If it matches, the user gets user mode (or admin mode if no admin password is set). If the device has an admin password set and the user enters it, the connection auth will fail (since it doesn't match the connection password). But wait — the user said "the both passwords can be used for connection". So actually the flow should be:
  1. Send password as connection auth (`CMD_PWD_AUTH` without flag).
  2. If that succeeds → user mode granted.
  3. If that fails → send password as admin auth (`CMD_PWD_AUTH` with admin flag).
  4. If that succeeds → admin mode granted.
  
  Since the user said "save a single password field. since the both passwords can be used for connection" and the auth command auto-detects mode, we can simplify:
  
  1. Send `CMD_PWD_AUTH` with the password (no admin flag). This is the normal flow.
  2. If the device has an admin password and the user entered that password, connection auth fails (mismatch vs `_nvsPwd`).
  3. On connection auth failure, immediately retry with admin flag. If admin auth succeeds → admin mode.
  4. This way the user enters their password once and gets the right mode automatically.

### 5.2 Password persistence (SecureStorage)

Since the user said "save a single password field. since the both passwords can be used for connection":

- A single password is saved per device in secure storage (key: `radiokit_pwd_<device_id>`).
- On reconnect, the saved password is sent as connection auth first. If it fails, retry as admin auth.
- **Admin password** has an optional "Remember admin password" checkbox.
- When both "Remember password" and "Remember admin" are checked, the connection password is stored as-is, and the admin password is stored separately (key: `radiokit_admin_pwd_<device_id>`).
- On reconnect with both saved:
  1. Send saved password as connection auth.
  2. If success → user mode.
  3. Immediately try admin auth with saved admin password (if available).
  4. If admin auth succeeds → admin mode.

### 5.3 Admin Upgrade UI (Info Tab)

- A dedicated **"Admin Access"** section at the bottom of the INFO tab in the device info bottom sheet.
- Shows current status: `Mode: User` or `Mode: Admin`.
- When in user mode: shows an "AUTHENTICATE AS ADMIN" button. Tapping it reveals a password field and "UPGRADE" button.
- When in admin mode: shows a green checkmark + "ADMIN ACCESS GRANTED".
- If no admin password is set on the device (`hasAdminPassword == false`): the section shows "ADMIN ACCESS AVAILABLE" (pre-authed).

### 5.4 Tab gating (Info sheet tabs)

The bottom sheet has three tabs: INFO | FILESYSTEM | FIRMWARE.

- When in **user mode** (not admin):
  - FILESYSTEM tab shows a lock icon in the tab bar, or the tab content shows "Admin access required" with an upgrade button.
  - FIRMWARE tab same as FILESYSTEM.
- When in **admin mode**: tabs function normally.
- **Instant unlock**: When the user upgrades to admin via the INFO tab, the FS and OTA tabs should immediately become functional without switching away. This can be done by:
  - The `_DeviceInfoTabsState` watches `DeviceProvider.isAdminMode` and calls `setState` to rebuild.
  - The FS and OTA tab content widgets also check `DeviceProvider.isAdminMode` and show content vs locked state.

### 5.5 DeviceProvider changes

New state:
```dart
bool _authenticatedAdmin = false;

bool get isAdminMode => _authenticatedAdmin || !hasAdminPassword;
bool get isUserMode => _authenticated && !isAdminMode;
```

New methods:
```dart
/// Authenticate as admin with the admin password.
/// Returns true on success.
Future<bool> authenticateAdmin(String password) async {
  // Uses CMD_PWD_AUTH with admin flag
  ...
}
```

Modified `authenticate()`:
```dart
Future<bool> authenticate(String password) async {
  // Current flow: send CMD_PWD_AUTH, check response
  // On mismatch AND device has admin password:
  //   → auto-retry with admin flag
  //   → if admin auth succeeds → set _authenticatedAdmin = true
  ...
}
```

### 5.6 Auth timeout

- Only applies while waiting for user-mode (connection password) auth.
- Once `_authenticated` is true, timeout is cancelled — regardless of admin auth state.
- Admin upgrade is not timed.

---

## 6. UI Mockups

### 6.1 Password Gate (connection)

```
┌─────────────────────────────────────────┐
│ 🔒 PASSWORD REQUIRED         55s        │
│ RC_CONTROLLER                           │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ ••••••••               👁          │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ☑ Remember password                     │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │           UNLOCK                     │ │
│ └─────────────────────────────────────┘ │
│                                         │
│           DISCONNECT                    │
└─────────────────────────────────────────┘
```

### 6.2 Info Tab — User Mode

```
┌─ INFO ───────┬─ [🔒] FILESYSTEM ─┬─ [🔒] FIRMWARE ─┐
│                                              │
│ RC_CONTROLLER                                │
│ 🔵 BLE  |  Connection: 12ms  |  MTU: 512    │
│                                              │
│ ── DEVICE SETTINGS ──                       │
│ [NAME] [DESCRIPTION] [PASSWORD]              │
│ [SAVE] [FACTORY RESET]                       │
│                                              │
│ ── CHIP INFO ──                             │
│ ...                                          │
│                                              │
│ ── ADMIN ACCESS ──                           │
│ Mode: User  🔒                               │
│ ┌─────────────────────────────────────────┐ │
│ │      AUTHENTICATE AS ADMIN              │ │
│ └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### 6.3 Info Tab — Admin Mode

```
┌─ INFO ───────┬─ FILESYSTEM ──┬─ FIRMWARE ────┐
│                                              │
│ ...same as above...                          │
│                                              │
│ ── ADMIN ACCESS ──                           │
│ Mode: Admin  ✅  FULL ACCESS                 │
│ ┌─────────────────────────────────────────┐ │
│ │      REVOKE ADMIN ACCESS                │ │
│ └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### 6.4 Admin Auth Dialog

```
┌─────────────────────────────────────────┐
│     🔐 ADMIN AUTHENTICATION             │
│                                         │
│ Enter admin password to unlock          │
│ filesystem and firmware access.         │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ ••••••••               👁          │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ☐ Remember admin password               │
│                                         │
│ ┌──────────┐  ┌──────────────────────┐ │
│ │ CANCEL   │  │     UPGRADE          │ │
│ └──────────┘  └──────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## 7. Implementation Plan

### Phase 1: Firmware (Arduino library)

1. Add `_nvsAdminPwd` buffer and `_authenticatedAdmin` flag to `RadioKitClass`.
2. Add `RK_NVS_KEY_ADMIN_PWD` NVS key constant.
3. Update `_syncNvsToBuffers()` to load admin password from NVS.
4. Update `begin()` boot auth logic for dual-auth state.
5. Extend feature bitmask: `RK_FEATURE_HAS_CONN_PWD` (bit 2), `RK_FEATURE_HAS_ADMIN_PWD` (bit 3).
6. Update `_handlePwdAuth()` to check `flags` byte for admin auth request.
7. Update `_onPacket()` auth gate: allow more commands in user mode, block admin-only commands.
8. Update `_handleSetConf()` to handle admin password field (new SET_CONF mask bit `RK_SET_CONF_ADMIN_PWD`).
9. Update `_handleFactoryReset()` to erase both passwords.
10. Gate FS dispatch and OTA dispatch behind admin auth.

### Phase 2: Flutter app

1. Add `kFeatureHasConnPassword` and `kFeatureHasAdminPassword` constants.
2. Add `_authenticatedAdmin`, `isAdminMode`, `isUserMode` to `DeviceProvider`.
3. Add `authenticateAdmin()` method using `CMD_PWD_AUTH` with admin flag.
4. Modify `authenticate()` fallback: on mismatch, auto-retry with admin flag.
5. Add `_AdminAccessSection` widget to info tab.
6. Lock FS and OTA tab content when in user mode (show locked placeholder with upgrade button).
7. Add "Remember admin password" checkbox to admin auth dialog.
8. Update `SecureStorageService` with admin password key.

---

## 8. Open Questions / Future Work

- Should the admin password prompt time out? (Currently: no timeout — user can take as long as they want.)
- Should there be a "Revoke admin" button in the admin section? (Worth adding for UX parity.)
- Should user-mode locks show a small badge on the tab bar for FS/OTA? (Nice-to-have.)
