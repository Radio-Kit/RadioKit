# RadioKit Remote Access API

The RadioKit Flutter app exposes a REST API on the local network for test automation and remote control. The server is bound to `0.0.0.0:7007`.

> **Security**: This API is intended for LAN use only. There is no authentication or encryption. Do not expose the port to the public internet.

> **Multi-Device Mode**: The app supports simultaneous connections to multiple RadioKit devices. Every device-specific endpoint (widgets, filesystem, transport, NVS, OTA, console) has a **per-device** variant under `/api/devices/<id>/...` that targets a specific device regardless of focus. The legacy single-device endpoints under `/api/widgets`, `/api/fs/`, etc. operate on the **active** device — the one currently focused in the app's UI. Use `GET /api/devices` to list all connected devices with their IDs, or `GET /api/connection` to check the legacy active device.

---

## Base URL

```
http://<device-ip>:7007/api
```

On the device (localhost):
```
http://127.0.0.1:7007/api
http://[::1]:7007/api
```

---

## Common

### Content-Type

All request bodies are `application/json`. All responses are `application/json`.

### Standard error body

```json
{
  "error": "<error_code>",
  "message": "Human-readable description."
}
```

### HTTP status codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created (e.g., scan started) |
| 400 | Bad request (invalid params) |
| 404 | Not found |
| 503 | Service unavailable (not connected to a device) |

---

## 1. Server Info

### `GET /api/status`

General server health and version info.

**Response `200`:**

```json
{
  "version": "1.0.0",
  "uptime": 1234,
  "port": 7007,
  "localIp": "192.168.1.42",
  "platform": "android",
  "debug": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | App version |
| `uptime` | int | Server uptime in seconds |
| `port` | int | Listening port |
| `localIp` | string | Local network IP address |
| `platform` | string | `android`, `ios`, `linux`, `macos`, `windows`, `web` |
| `debug` | bool | Whether this is a debug build |

---

## 2. App Settings

### `GET /api/settings`

Returns all current app settings.

**Response `200`:**

```json
{
  "showDemo": true,
  "useFullscreen": false,
  "enableDevTools": true,
  "enableRemoteAccess": true,
  "followRemoteAccess": true
}
```

### `PUT /api/settings`

Update one or more settings. Only include the fields you want to change.

**Request:**

```json
{
  "showDemo": false,
  "enableDevTools": true
}
```

**Response `200`:**

```json
{
  "ok": true
}
```

### `GET /api/settings/nvs`

Returns the current NVS (Non-Volatile Storage) config values from the connected device: device name, description, and authentication state.

> **Guard**: Returns `503` if not connected to a device.

**Response `200`:**

```json
{
  "name": "6X6 OFF ROAD CHASSIS",
  "description": "Unit 02",
  "hasPassword": true,
  "hasAdminPassword": true,
  "isAuthenticated": false,
  "isAdminMode": false,
  "isUserMode": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Device name from NVS config |
| `description` | string | Device description from NVS config |
| `hasPassword` | bool | Whether a connection password is set on the device |
| `hasAdminPassword` | bool | Whether an admin password is set on the device |
| `isAuthenticated` | bool | Whether the current session is authenticated (connection password verified) |
| `isAdminMode` | bool | Whether the current session has admin privileges (admin password verified, or no admin password set) |
| `isUserMode` | bool | Whether the current session is in user-only mode (authenticated but not admin) |

> **Auth tiers**: `isUserMode` = `isAuthenticated && !isAdminMode`. When no admin password exists (`hasAdminPassword` = false), admin mode is auto-granted on authentication. The 60-second auth timeout starts when a password-gated device connects; disconnect occurs automatically if not authenticated within 60s.

### `POST /api/settings/nvs`

Write new config values to the device's NVS. Only fields provided in the request body will be updated. Passwords can be cleared by sending an empty string.

> **Guard**: Returns `503` if not connected to a device.

**Request:**

```json
{
  "name": "My Device",
  "description": "Updated description",
  "password": "newpass123",
  "adminPassword": "admin456"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | no | Device name (1–32 chars) |
| `description` | string | no | Device description (0–128 chars) |
| `password` | string | no | Connection password (0–32 chars, empty to clear) |
| `adminPassword` | string | no | Admin password (0–32 chars, empty to clear) |
| `icon` | string | no | Device icon (max 32 chars, empty to clear) |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Config saved to NVS"
}
```

**Response `400`:**

```json
{
  "error": "invalid_params",
  "message": "At least one of: name, description, password, adminPassword, icon"
}
```

### `POST /api/settings/nvs/authenticate`

Authenticate with the device password. The entered password is first tried as a connection password. If that fails and the device has an admin password, it is retried as admin authentication (admin password can also be used for connection).

> **Guard**: Returns `503` if not connected to a device.

**Request:**

```json
{
  "password": "mypassword"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `password` | string | yes | Device password (connection or admin) |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Authenticated successfully"
}
```

**Response `401`:**

```json
{
  "error": "auth_failed",
  "message": "Password mismatch or timeout"
}
```

### `POST /api/settings/nvs/reboot`

Reboot the device without erasing NVS. The device's NVS keys (`rk_ble_on`, `rk_wifi_on`, etc.) are preserved.

> **Guard**: Returns `503` if not connected to a device.

**Request:** (no body)

**Response `200`:**

```json
{
  "ok": true,
  "message": "Reboot sent — device will reboot (NVS preserved)"
}
```

### `POST /api/settings/nvs/factory-reset`

Erase all NVS config (name, description, passwords) and reboot the device. Compile-time defaults will be restored after reboot. **This cannot be undone.**

> **Guard**: Returns `503` if not connected to a device.

**Request:**

```json
{
  "confirm": true
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `confirm` | bool | yes | Must be `true` to proceed (safety gate) |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Factory reset sent — device will reboot"
}
```

**Response `400`:**

```json
{
  "error": "confirmation_required",
  "message": "Set confirm: true to proceed with factory reset. This will erase all config and reboot the device."
}
```

### `GET /api/settings/nvs/raw/<key>`

Read a raw NVS key from the device. Supports both uint8 and string keys.

> **Guard**: Returns `503` if not connected to a device.

**Response `200` (string key):**

```json
{
  "ok": true,
  "key": "device_name",
  "value": "6X6 OFF ROAD CHASSIS"
}
```

**Response `200` (uint8 key, not found):**

```json
{
  "ok": true,
  "key": "rk_ble_on",
  "value": null
}
```

### `POST /api/settings/nvs/raw/<key>`

Write a raw uint8 value to an NVS key.

> **Guard**: Returns `503` if not connected to a device.

**Request:**

```json
{
  "value": 1
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `value` | int | yes | Value 0–255 |

**Response `200`:**

```json
{
  "ok": true,
  "key": "rk_ble_on",
  "value": 1
}
```

### `GET /api/settings/nvs/cloud-info`

Read cloud relay URL and account from the device via the `GET_CLOUD_INFO` protocol command.

> **Guard**: Returns `503` if not connected to a device.

**Response `200`:**

```json
{
  "ok": true,
  "url": "wss://relay.radiokit.app:443",
  "account": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `url` | string? | Cloud relay WebSocket URL configured on the device |
| `account` | string? | Ed25519 public key (account) configured on the device |

---

## 3. API Log

### `GET /api/log`

Returns recent HTTP request log entries kept by the server.

**Response `200`:**

```json
{
  "entries": [
    {
      "timestamp": "2026-06-06T12:34:56.789Z",
      "method": "GET",
      "path": "/api/status",
      "statusCode": 200,
      "durationMs": 12
    }
  ]
}
```

### `DELETE /api/log`

Clear the request log.

**Response `200`:**

```json
{
  "ok": true
}
```

---

## 4. Console Log

The console log is the main application diagnostic log. It captures BLE scan output, serial port enumeration, connection handshake progress, widget interactions, protocol errors, and filesystem operations — everything printed by `ConsoleProvider.log()` throughout the app.

### `GET /api/console`

Returns the console log entries.

**Response `200`:**

```json
{
  "entries": [
    {
      "timestamp": "2026-06-06T12:34:56.789Z",
      "level": "info",
      "message": "ESTABLISHING HANDSHAKE (Protocol v3)..."
    },
    {
      "timestamp": "2026-06-06T12:34:57.012Z",
      "level": "success",
      "message": "RECEIVED CONFIG: \"6X6 OFF ROAD CHASSIS\" with 12 widgets"
    },
    {
      "timestamp": "2026-06-06T12:34:58.100Z",
      "level": "error",
      "message": "FAILED TO SEND GET_CONF: Timeout"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | ISO 8601 timestamp |
| `level` | string | `"info"`, `"success"`, `"warning"`, or `"error"` |
| `message` | string | Log message text |

### `DELETE /api/console`

Clear the console log.

**Response `200`:**

```json
{
  "ok": true
}
```

---

## 5. Pairing (Device Discovery)

### `GET /api/pair/devices`

List currently discovered BLE and/or Serial devices. Returns whatever has been scanned so far.

**Response `200`:**

```json
{
  "devices": [
    {
      "id": "00:11:22:33:44:55",
      "name": "RadioKit RC Truck",
      "type": "ble",
      "rssi": -65
    },
    {
      "id": "/dev/ttyACM0",
      "name": "USB Serial Device @ /dev/ttyACM0",
      "type": "serial",
      "rssi": 0
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | BLE MAC/UUID or serial port path |
| `name` | string | Display name |
| `type` | string | `"ble"` or `"serial"` |
| `rssi` | int | Signal strength (0 for serial) |

### `POST /api/pair/scan`

Start or refresh a scan for devices of the given transport type.

**Request:**

```json
{
  "type": "ble"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | `"ble"` or `"serial"` |

**Response `201`:**

```json
{
  "ok": true,
  "message": "Scan started for ble"
}
```

**Response `400`:**

```json
{
  "error": "invalid_type",
  "message": "type must be 'ble' or 'serial'"
}
```

---

## 6. Connection

### `GET /api/connection`

Current connection state and telemetry.

**Response when connected `200`:**

```json
{
  "connected": true,
  "device": {
    "id": "00:11:22:33:44:55",
    "name": "RadioKit RC Truck",
    "type": "ble",
    "configName": "6X6 OFF ROAD CHASSIS",
    "description": "Unit 02",
    "hasFs": true,
    "hasOta": true,
    "deviceIcon": "truck"
  },
  "configJson": {
    "version": 1,
    "config": { "name": "6X6 OFF ROAD CHASSIS", "description": "Unit 02" },
    "canvas": { "size": [200, 100], "grid": "none", "skin": "dragon" },
    "widgets": []
  },
  "latencyMs": 24,
  "rssi": -58,
  "orientation": "landscape"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `configJson` | object | Full designer-format JSON config (same schema as `assets/demos/*.json`). `null` when disconnected. |

**Response when disconnected `200`:**

```json
{
  "connected": false,
  "device": null,
  "configJson": null,
  "latencyMs": null,
  "rssi": null,
  "orientation": null
}
```

### `POST /api/connection/connect`

Connect to a device by its ID.

**Request:**

```json
{
  "id": "00:11:22:33:44:55",
  "type": "ble",
  "baudRate": 1000000
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | string | yes | — | Device ID from `/api/pair/devices`, or a WebSocket URL for WiFi |
| `type` | string | yes | — | `"ble"`, `"serial"`, or `"wifi"` |
| `baudRate` | int | no | `1000000` | Serial baud rate (ignored for BLE/WiFi) |

> **WiFi connect**: For `type: "wifi"`, set `id` to a full WebSocket URL (e.g. `ws://192.168.1.42:81` or `wss://device.example.com:443`). |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Connected to RadioKit RC Truck"
}
```

**Response on failure:**

```json
{
  "error": "connection_failed",
  "message": "Device did not respond to GET_CONF after 3 attempts."
}
```

> **Polling pattern**: After calling this endpoint, agents should poll `GET /api/connection` until `connected` is `true` or `false` (connection is asynchronous and may take several seconds).

### `POST /api/connection/demo`

Load a built-in demo without any real device. The app simulates a connected device with widgets and optional auto-animation. Useful for testing the UI and API without hardware.

Valid demo IDs: `WIDGETS_DEMO`, `RC_CONTROLLER`, `IOT_DASHBOARD`.

**Request:**

```json
{
  "demoId": "WIDGETS_DEMO"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `demoId` | string | yes | One of `WIDGETS_DEMO`, `RC_CONTROLLER`, `IOT_DASHBOARD` |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Demo WIDGETS_DEMO loaded with 12 widgets"
}
```

**Response on failure:**

```json
{
  "error": "demo_not_found",
  "message": "Invalid demo ID: MY_DEMO"
}
```

### `GET /api/connection/params`

Returns detailed BLE connection parameters. Fetches live data from the device (may timeout if the device doesn't support the BLE_INFO command).

> **Guard**: Returns `503` if not connected to a device.

**Response `200`:**

```json
{
  "connIntervalMs": 12,
  "negotiatedMtu": 512,
  "rssi": -58,
  "latencyMs": 24,
  "deviceRssi": -60
}
```

| Field | Type | Description |
|-------|------|-------------|
| `connIntervalMs` | int? | BLE connection interval in ms |
| `negotiatedMtu` | int? | Negotiated ATT MTU |
| `rssi` | int? | Current RSSI from app's telemetry |
| `latencyMs` | int? | Current ping latency |
| `deviceRssi` | int? | RSSI reported by the device |

### `POST /api/connection/switch`

Switch the active transport for the connected device without disconnecting first (connect-first, then disconnect source on success).

> **Guard**: Returns `503` if not connected to a device.

**Request:**

```json
{
  "transport": "wifi"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `transport` | string | yes | `"ble"`, `"wifi"`, or `"cloud"` |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Switched to wifi",
  "transport": "wifi"
}
```

**Response `500` (switch failed):**

```json
{
  "error": "switch_failed",
  "message": "Failed to switch to wifi — target transport unreachable"
}
```

### `POST /api/connection/disconnect`

Disconnect from the currently connected device (or unload the demo).

**Response `200`:**

```json
{
  "ok": true,
  "message": "Disconnected"
}
```

### `POST /api/connection/reconnect`

Reconnect to the last connected device (looked up from paired history).

**Response `200`:**

```json
{
  "ok": true,
  "message": "Reconnecting to RadioKit RC Truck"
}
```

**Response when no history:**

```json
{
  "error": "no_history",
  "message": "No previously paired device found"
}
```

---

## 7. Models (Paired History)

### `GET /api/models`

List all paired devices from history.

**Response `200`:**

```json
{
  "models": [
    {
      "id": "00:11:22:33:44:55",
      "name": "RadioKit RC Truck",
      "type": "ble",
      "configName": "6X6 OFF ROAD CHASSIS",
      "description": "Unit 02",
      "deviceIcon": "truck"
    }
  ]
}
```

### `DELETE /api/models`

Remove all paired models (danger zone). Mirrors the "REMOVE ALL MODELS" button.

**Response `200`:**

```json
{
  "ok": true,
  "message": "All models removed"
}
```

### `DELETE /api/models/{id}`

Remove a single paired model by its device ID.

**Response `200`:**

```json
{
  "ok": true,
  "message": "Model removed"
}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "No model with id '00:11:22:33:44:55'"
}
```

---

## 8. Transport (Raw Protocol)

### `POST /api/transport/send`

Send a raw protocol packet. Useful for debug and protocol-level testing.

**Request:**

```json
{
  "cmd": 3,
  "payload": "FFAABB"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | int | yes | Protocol command byte (0–255) |
| `payload` | string | no | Hex-encoded payload (even-length hex string) |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Packet sent"
}
```

**Response `400`:**

```json
{
  "error": "invalid_hex",
  "message": "Payload must be an even-length hex string"
}
```

**Response `503` when not connected:**

```json
{
  "error": "not_connected",
  "message": "Not connected to a device"
}
```

### `POST /api/transport/ping`

Quick-send a PING frame. Shorthand for `{"cmd": 1, "payload": ""}`.

**Response `200`:**

```json
{
  "ok": true
}
```

### `POST /api/transport/wifi_info`

Get WiFi connection info from the connected device. Sends a GET_WIFI_INFO protocol command and returns the current network status.

> **Guard**: Returns `503` if not connected to a device.

**Response `200`:**

```json
{
  "ok": true,
  "ip": "192.168.1.42",
  "mode": "sta",
  "ssid": "MyHomeNetwork",
  "rssi": -65
}
```

| Field | Type | Description |
|-------|------|-------------|
| `ip` | string | Device IP address on the network |
| `mode` | string | WiFi mode: `"sta"` (station/client) or `"ap"` (access point) |
| `ssid` | string | Connected SSID (STA mode only) |
| `rssi` | int | WiFi signal strength in dBm |

**Response `200` (timeout):**

```json
{
  "ok": false,
  "error": "wifi_info_timeout",
  "message": "Device did not respond to WiFi info request in time"
}
```

### `POST /api/transport/{cmd}`

Quick-send predefined commands (shorthand names):

- `ping` — same as `POST /api/transport/ping`
- `get_conf` — request configuration
- `get_vars` — request variable states
- `get_meta` — request metadata
- `get_tele` — request telemetry

**Example:** `POST /api/transport/get_vars`

**Response `200`:**

```json
{
  "ok": true
}
```

---

## 9. Widgets (requires connection)

> **Guard**: All widget endpoints return `503` if not connected to a device.

### `GET /api/widgets`

List all widget configurations and their current runtime state.

**Response `200`:**

```json
{
  "widgets": [
    {
      "widgetId": 1,
      "type": "button",
      "name": "button_1",
      "label": "FIRE",
      "x": 10,
      "y": 20,
      "rotation": 0,
      "variant": "push",
      "hasOutput": false,
      "state": {
        "value": 0,
        "text": null
      }
    },
    {
      "widgetId": 4,
      "type": "text",
      "name": "text_1",
      "label": "Status",
      "x": 30,
      "y": 50,
      "rotation": 0,
      "variant": null,
      "hasOutput": true,
      "state": {
        "value": null,
        "text": "SYSTEM_UP: 42s"
      }
    },
    {
      "widgetId": 7,
      "type": "slider",
      "name": "slider_1",
      "label": "Speed",
      "x": 5,
      "y": 80,
      "rotation": 0,
      "variant": null,
      "hasOutput": false,
      "state": {
        "value": 50,
        "text": null
      }
    },
    {
      "widgetId": 10,
      "type": "joystick",
      "name": "joystick_1",
      "label": "Steer",
      "x": 40,
      "y": 10,
      "rotation": 0,
      "variant": null,
      "hasOutput": false,
      "state": {
        "values": [0, 0],
        "text": null
      }
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | One of: `button`, `switch`, `slideSwitch`, `slider`, `knob`, `joystick`, `led`, `text`, `multiple` |
| `variant` | string? | `"push"`, `"toggle"`, `"gasPedal"`, `"steeringWheel"`, `"multiSelect"`, or `null` |
| `hidden` | bool | Whether the widget is hidden in the UI (runtime-controllable via `rk.hidden`) |
| `hasOutput` | bool | True for display-only widgets (LED, Text), false for input widgets |
| `state.value` | int? | Numeric output value (for LED, Slider, Knob, etc.) |
| `state.values` | int[]? | Multi-value state (Joystick: `[x, y]`, Multiple: bitmask) |
| `state.text` | string? | Text output value (for Text widget) |

### `GET /api/widgets/{widgetId}`

Get the state of a single widget.

**Response `200`:**

```json
{
  "widgetId": 7,
  "type": "slider",
  "name": "slider_1",
  "label": "Speed",
  "state": {
    "value": 50
  }
}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "Widget 99 not found"
}
```

### `PUT /api/widgets/{widgetId}`

Set an input value on a widget. Only meaningful for input-type widgets (button, switch, slider, knob, joystick, multiple).

**Request:**

```json
{
  "values": [75]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `values` | int[] | yes | Input value(s). Single-value widgets use a 1-element array. Joystick uses `[x, y]`. Multiple uses bitmask. |

**Examples by widget type:**

| Type | `values` | Effect |
|------|----------|--------|
| Push button | `[1]` then `[0]` | Press then release |
| Toggle button | `[1]` or `[0]` | Set ON or OFF |
| SlideSwitch | `[2]` | Set position to index 2 |
| Slider | `[75]` | Set to 75% |
| Knob | `[30]` | Set to 30% |
| Knob (SteeringWheel) | `[45]` | Set to 45% |
| Slider (GasPedal) | `[80]` | Set to 80% |
| Joystick | `[12, -30]` | Set X=12, Y=-30 |
| Multiple (selector) | `[1]` | Select item index 1 |
| Multiple (multiSelect) | `[5]` | Set bitmask 5 (0b101) |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Widget 7 set to [75]"
}
```

**Response `400`:**

```json
{
  "error": "invalid_values",
  "message": "Widget 7 (slider) expects exactly 1 value, got 3"
}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "Widget 99 not found"
}
```

---

## 10. Filesystem (requires connection)

> **Guard**: All FS endpoints return `503` if not connected or if `device.hasFs` is false.

### `GET /api/fs/list`

List the contents of a directory.

**Query parameters:**

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | string | no | `/` | Directory path |

**Response `200`:**

```json
{
  "path": "/",
  "entries": [
    {
      "name": "demo",
      "type": "directory",
      "size": 0
    },
    {
      "name": "README.txt",
      "type": "file",
      "size": 1240
    }
  ]
}
```

### `GET /api/fs/info`

Get filesystem usage information.

**Response `200`:**

```json
{
  "totalBytes": 2097152,
  "usedBytes": 452198,
  "freeBytes": 1644954,
  "blockSize": 4096
}
```

### `GET /api/fs/read`

Read the entire contents of a file. Returns base64-encoded data.

**Query parameters:**

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | string | yes | — | File path |

**Response `200`:**

```json
{
  "path": "/demo/sensors.json",
  "size": 1024,
  "encoding": "base64",
  "data": "eyJ0ZW1wZXJhdHVyZSI6IDI0LjV9Cg=="
}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "File not found: /demo/nonexistent.txt"
}
```

### `POST /api/fs/write`

Write data to a file. Creates or truncates the file. Uses chunked writes for large files (default chunk size 4096 bytes).

**Request:**

```json
{
  "path": "/demo/config.json",
  "data": "eyJ0aGVtZSI6ICJkYXJrIn0=",
  "chunkSize": 4096
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | File path |
| `data` | string | yes | File content as base64 |
| `chunkSize` | int | no | Chunk size in bytes (default 4096, for throughput profiling) |

**Response `200`:**

```json
{
  "ok": true,
  "path": "/demo/config.json",
  "bytesWritten": 256
}
```

### `POST /api/fs/upload`

Upload a file using the chunked upload protocol (FS_UPLOAD_BEGIN / UPLOAD_CHUNK / UPLOAD_END). Supports a `chunkSize` parameter for throughput profiling. This is the recommended endpoint for large files.

**Request:**

```json
{
  "path": "/demo/firmware.bin",
  "data": "<base64-encoded content>",
  "chunkSize": 16384
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | File path |
| `data` | string | yes | File content as base64 |
| `chunkSize` | int | no | Upload chunk size in bytes (for profiling) |

**Response `200`:**

```json
{
  "ok": true,
  "path": "/demo/firmware.bin",
  "bytesWritten": 1048576
}
```

### `POST /api/fs/mkdir`

Create a directory.

**Request:**

```json
{
  "path": "/demo/subdir"
}
```

**Response `200`:**

```json
{
  "ok": true,
  "path": "/demo/subdir"
}
```

### `POST /api/fs/delete`

Delete a file or directory.

**Request:**

```json
{
  "path": "/demo/old_file.txt",
  "recursive": false
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | string | yes | — | Path to delete |
| `recursive` | bool | no | `false` | Recursively delete directories |

**Response `200`:**

```json
{
  "ok": true,
  "path": "/demo/old_file.txt"
}
```

### `POST /api/fs/rename`

Rename or move a file/directory.

**Request:**

```json
{
  "oldPath": "/demo/old_name.txt",
  "newPath": "/demo/new_name.txt"
}
```

**Response `200`:**

```json
{
  "ok": true,
  "oldPath": "/demo/old_name.txt",
  "newPath": "/demo/new_name.txt"
}
```

### `POST /api/fs/format`

Format the filesystem (destructive).

**Response `200`:**

```json
{
  "ok": true,
  "message": "Filesystem formatted"
}
```

### `POST /api/fs/probe`

Probe the connected device to check filesystem support. Sends an FS_PING frame and waits for a response. Useful for testing FS detection without waiting for the automatic probe.

> **Guard**: Returns `503` if not connected.

**Response `200`:**

```json
{
  "ok": true,
  "hasFs": true
}
```

---

## 11. Designs (Saved Projects)

Saved designer projects — the same entries visible in the PROJECTS tab. Each design stores a full designer-format JSON config.

### `GET /api/designs`

List all saved designs.

**Response `200`:**

```json
{
  "designs": [
    {
      "id": "abc123",
      "name": "My Controller UI",
      "timestamp": 1717000000000,
      "jsonContent": "{ \"version\": 1, \"config\": {...}, \"canvas\": {...}, \"widgets\": [...] }",
      "filePath": null,
      "appVersion": "1.0.0"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique design ID |
| `name` | string | Design name |
| `timestamp` | int | Last edit timestamp (ms since epoch) |
| `jsonContent` | string? | Full designer JSON content (null for file-mode entries) |
| `filePath` | string? | File path for file-mode entries, null for inline entries |
| `appVersion` | string? | App version that created the design |

### `POST /api/designs`

Create a new design or update an existing one (upsert by `id`).

**Request:**

```json
{
  "id": "abc123",
  "name": "My Controller UI",
  "jsonContent": "{ \"version\": 1, \"config\": {...}, \"canvas\": {...}, \"widgets\": [...] }"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique design ID (use a UUID or slug) |
| `name` | string | yes | Display name |
| `jsonContent` | string | yes | Full designer-format JSON as a string |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Design saved"
}
```

### `DELETE /api/designs`

Delete all saved designs.

**Response `200`:**

```json
{
  "ok": true,
  "message": "All designs removed"
}
```

### `DELETE /api/designs/{id}`

Delete a single design by its ID.

**Response `200`:**

```json
{
  "ok": true,
  "message": "Design removed"
}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "Design not found: abc123"
}
```

---

## 12. OTA Firmware Update (requires connection)

> **Guard**: All OTA endpoints return `503` if not connected. `POST /api/ota/upload` returns `400` if the device doesn't support OTA (`hasOta` is false).

### `POST /api/ota/upload`

Upload firmware to the connected device via OTA. The firmware binary is sent as base64-encoded data. The upload proceeds in chunks with ACK/retry logic. Supports optional erase of NVS config + filesystem after update. On success, the device reboots with the new firmware.

**Request:**

```json
{
  "data": "<base64-encoded firmware binary>",
  "eraseAll": false
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `data` | string | yes | — | Base64-encoded firmware binary (.bin file) |
| `eraseAll` | bool | no | `false` | If `true`, erases NVS config + filesystem after OTA update before reboot |

**Response `200`:**

```json
{
  "ok": true,
  "size": 1048576,
  "eraseAll": false,
  "message": "Firmware uploaded successfully — device rebooting"
}
```

**Response `400` if OTA not supported:**

```json
{
  "error": "ota_not_supported",
  "message": "Connected device does not support OTA"
}
```

**Response on failure:**

```json
{
  "error": "ota_failed",
  "message": "OTA_CHUNK failed at offset 4096: FLASH_ERROR"
}
```

> **Timing**: The upload is synchronous and may take 10–60 seconds depending on firmware size. Poll `GET /api/ota/progress` for real-time progress during upload.

### `GET /api/ota/progress`

Returns the current OTA upload progress. Returns `active: false` when no upload is in progress.

**Response `200` (idle):**

```json
{
  "active": false,
  "received": 0,
  "total": 0,
  "status": "idle"
}
```

**Response `200` (uploading):**

```json
{
  "active": true,
  "received": 524288,
  "total": 1048576,
  "status": "uploading",
  "percentage": 50
}
```

| Field | Type | Description |
|-------|------|-------------|
| `active` | bool | Whether an OTA upload is in progress |
| `received` | int | Bytes received so far |
| `total` | int | Total firmware size in bytes |
| `status` | string | `"starting"`, `"uploading"`, `"rebooting"`, or `"idle"` |
| `percentage` | int | Progress percentage (0–100) |

---

## 13. Session / Route

### `GET /api/session/route`

Returns the current app route (GoRouter location). Used by follow-mode to synchronize screen navigation across devices.

**Response `200`:**

```json
{
  "route": "/control"
}
```

Returns an empty string if no route has been synced yet:

```json
{
  "route": ""
}
```

### `GET /api/session/sheets`

Returns the available follow-mode sheets for each route. Useful for API consumers that want to know which bottom sheets can be auto-opened during follow mode.

**Response `200`:**

```json
{
  sheets: {
    /models: [pair, deviceSettings],
    /system: [accounts],
    /control: [],
    /dev-tools/esp32-fs: [],
    /designs: [],
    /debug: []
  }
}
```

| Route | Available Sheets | Description |
|-------|-----------------|-------------|
| `/models` | `pair`, `deviceSettings` | PairBottomSheet (device discovery), DeviceSettingsDialog (device config) |
| `/system` | `accounts` | AccountsSheet (cloud relay accounts) |
| `/control` | (none) | No auto-openable sheets |
| `/dev-tools/esp32-fs` | (none) | No auto-openable sheets |

---

## Follow Mode Sheet Query Parameters

When follow mode is enabled, API requests trigger automatic navigation to the mapped screen. Some routes include `?sheet=<name>` query parameters that trigger bottom sheets on the target screen.

| API Path Prefix | Follow Route | Sheet | Description |
|-----------------|-------------|-------|-------------|
| `/api/pair/*` | `/models?sheet=pair` | `pair` | Opens PairBottomSheet (device discovery) |
| `/api/devices/*/settings/*` | `/models?sheet=deviceSettings` | `deviceSettings` | Opens DeviceSettingsDialog (name, passwords, factory reset) |
| `/api/cloud/account*` | `/system?sheet=accounts` | `accounts` | Opens AccountsSheet (cloud relay accounts) |
| `/api/settings/nvs` | `/system` | (none) | Navigates to System tab |
| `/api/connection/connect` | `/control` | (none) | Navigates to Control screen |
| `/api/fs/*` | `/dev-tools/esp32-fs` | (none) | Navigates to Filesystem Explorer |

---

## 14. Flasher (ESP32 Serial Flashing)

The flasher API exposes ESP32 firmware flashing via `flutter_esptool` over the app's local serial port. All serial operations run in the app process — no raw serial access is exposed over HTTP.

> **Guard**: `POST /api/flasher/flash` returns 503 if not connected to a serial port, 400 if no firmware selected, and 409 if a flash is already in progress.

### `GET /api/flasher/ports`

Return the currently scanned serial port list.

**Response `200`:**

```json
{
  "ports": [
    {"id": "/dev/ttyACM0", "name": "/dev/ttyACM0"},
    {"id": "/dev/ttyUSB0", "name": "/dev/ttyUSB0"}
  ]
}
```

### `POST /api/flasher/scan`

Trigger a serial port scan. Fire-and-forget — poll `GET /api/flasher/ports` for results.

**Response `200`:**

```json
{"ok": true, "message": "Port scan started"}
```

### `POST /api/flasher/connect`

Connect to a serial port, enter ESP32 download mode (DTR/RTS bootloader toggle), sync with the ROM bootloader, and detect chip info.

**Request:**

```json
{
  "portId": "/dev/ttyACM0"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `portId` | string | yes | Serial port identifier from `GET /api/flasher/ports` |

**Response `200`:**

```json
{"ok": true, "message": "Connected to /dev/ttyACM0"}
```

**Response on failure:**

```json
{
  "error": "connection_failed",
  "message": "Sync failed. Check connection and boot mode."
}
```

### `POST /api/flasher/disconnect`

Disconnect from the serial port and clean up all esptool services.

**Response `200`:**

```json
{"ok": true, "message": "Disconnected"}
```

### `GET /api/flasher/status`

Returns the full flasher state: connection status, chip info, firmware selection, flash progress.

**Response `200`:**

```json
{
  "isConnected": true,
  "isScanning": false,
  "isLoadingChipInfo": false,
  "isFlashing": false,
  "isOperationActive": false,
  "portName": "/dev/ttyACM0",
  "baudRate": 921600,
  "errorMessage": null,
  "flashProgress": 0.0,
  "flashStatus": "",
  "eraseAll": false,
  "chipInfo": {
    "model": "ESP32-S3",
    "revision": "v1.0",
    "mac": "7c:9e:bd:xx:xx:xx",
    "flashSize": "16.0 MB",
    "psramSize": "8.0 MB",
    "cores": "2"
  },
  "selectedFirmware": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `isConnected` | bool | Whether a serial port is connected and synced |
| `isFlashing` | bool | Whether a flash operation is in progress |
| `flashProgress` | double | Progress 0.0–1.0 |
| `flashStatus` | string | Human-readable flash status text |
| `chipInfo` | object? | ESP chip information (null when not connected) |
| `chipInfo.model` | string | Chip model (e.g. "ESP32-S3") |
| `chipInfo.revision` | string | Chip revision (e.g. "v1.0") |
| `chipInfo.mac` | string | MAC address |
| `chipInfo.flashSize` | string | Flash size (e.g. "16.0 MB") |
| `chipInfo.psramSize` | string | PSRAM size (e.g. "8.0 MB") |
| `chipInfo.cores` | string | Number of cores |
| `selectedFirmware` | object? | Selected firmware info (null if no firmware selected) |
| `selectedFirmware.name` | string | Firmware file name |
| `selectedFirmware.size` | string | Formatted size (e.g. "1.2 MB") |
| `selectedFirmware.bytes` | int | Size in bytes |

### `GET /api/flasher/log`

Returns the flasher log entries (color-coded: `[OK]`, `[ERROR]`, `[WARN]`).

**Response `200`:**

```json
{
  "entries": [
    "[14:23:45] Connecting to /dev/ttyACM0...",
    "[14:23:46] [OK] Port opened at 115200 baud",
    "[14:23:47] Chip is ESP32-S3 (revision v1.0)"
  ]
}
```

### `POST /api/flasher/log/clear`

Clear the flasher log.

**Request:** (no body)

**Response `200`:**

```json
{"ok": true}
```

### `POST /api/flasher/select-firmware`

Upload a firmware binary (base64-encoded) to be flashed. The file is saved to a temp directory and set as the selected firmware.

**Request:**

```json
{
  "data": "<base64-encoded firmware binary>",
  "name": "my_firmware.bin"
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `data` | string | yes | — | Base64-encoded ESP32 firmware binary |
| `name` | string | no | `firmware.bin` | Firmware file name |

**Response `200`:**

```json
{
  "ok": true,
  "name": "my_firmware.bin",
  "size": 1048576
}
```

### `POST /api/flasher/clear-firmware`

Clear the current firmware selection.

**Response `200`:**

```json
{"ok": true}
```

### `POST /api/flasher/erase-all`

Set or clear the "erase all before flashing" flag.

**Request:**

```json
{
  "eraseAll": true
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `eraseAll` | bool | yes | Erase entire flash before writing firmware |

**Response `200`:**

```json
{"ok": true, "eraseAll": true}
```

### `POST /api/flasher/flash`

Start the flashing operation. Fire-and-forget — poll `GET /api/flasher/status` for progress (`flashProgress`, `flashStatus`, `isFlashing`). Requires firmware selected via `select-firmware` and an active serial connection.

**Request:** (no body)

**Response `200`:**

```json
{"ok": true, "message": "Flashing started"}
```

**Response `503` (not connected):**

```json
{
  "error": "not_connected",
  "message": "Not connected to a serial port"
}
```

**Response `400` (no firmware):**

```json
{
  "error": "no_firmware",
  "message": "No firmware selected. Use /api/flasher/select-firmware first"
}
```

**Response `409` (already flashing):**

```json
{
  "error": "already_flashing",
  "message": "A flashing operation is already in progress"
}
```

---

## 15. Cloud Relay (Cloud Auth)

Cloud relay endpoints manage the Ed25519 challenge-response authentication flow with the Rust relay server. The relay acts as a bridge between the app and the ESP32 device over the internet.

### Auth Flow

```
App                     Relay                    Device
 │                        │                        │
 ├── auth_request ───────→│                        │
 │                        │                        │
 │←──── auth_challenge ───┤                        │
 │   (random 32-byte     │                        │
 │    nonce, base64)     │                        │
 │                        │                        │
 ├── auth_response ──────→│                        │
 │   (nonce signed with   │                        │
 │    Ed25519 private key)│                        │
 │                        │                        │
 │←──── auth_ok ──────────┤                        │
 │                        │                        │
 ├── list_devices ───────→│                        │
 │                        │                        │
 │←──── ["Device1", ...] ─┤                        │
 │                        │                        │
 ├── join "Device1" ─────→│─────── forward ────────→│
 │                        │                        │
 │←──── join_ok ──────────┤←─────── ack ───────────┤
 │                        │                        │
 │   (Widget frames now   │                        │
 │    route through relay)│                        │
```

> **How it works**: The app generates an Ed25519 keypair on first launch. The **public key hex** is the account identifier — set this on the ESP32 firmware's `cloud_account` field. The **private key hex** is used to sign relay challenges and is stored in platform secure storage on the device. When connecting via the API, both hex strings are passed explicitly.

---

### `POST /api/cloud/connect`

Connect to a relay, authenticate with Ed25519 challenge-response, and retrieve the device list.

**Request:**

```json
{
  "host": "10.0.0.17",
  "port": 9000,
  "account": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed",
  "privateKey": "1f2919214484bb4100aad318e572ca75a605b551ef68a2111b3cff56165fb654"
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `host` | string | no | `relay.radiokit.app` | Relay server hostname or IP |
| `port` | int | no | `443` | Relay server port (`443`→`wss://`, otherwise `ws://`) |
| `account` | string | yes | — | Ed25519 public key in hex (64 hex chars) |
| `privateKey` | string | yes | — | Ed25519 private key in hex (64 hex chars) for signing the challenge nonce |

**Response `200`:**

```json
{
  "ok": true,
  "host": "10.0.0.17",
  "port": 9000,
  "account": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed",
  "devices": ["WiFi_Cloud_Switch"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `devices` | string[] | List of device names registered with the same account on the relay |

**Response `401` (auth failed):**

```json
{
  "error": "auth_failed",
  "message": "Signing failed: ..."
}
```

**Response `504` (timeout):**

```json
{
  "error": "timeout",
  "message": "Timed out waiting for relay response"
}
```

> **Internal flow**: `auth_request` is sent automatically by `WebSocketService` on connect. The relay responds with `auth_challenge` containing a random 32-byte nonce (base64). The app signs the nonce with the Ed25519 private key and sends `auth_response`. The relay verifies the signature against the stored public key and sends `auth_ok` or `auth_failed`.

---

### `GET /api/cloud/devices`

Returns the cached connection state and device list from the last successful `POST /api/cloud/connect`.

**Response `200`:**

```json
{
  "connected": true,
  "host": "10.0.0.17",
  "port": 9000,
  "account": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed",
  "devices": ["WiFi_Cloud_Switch"]
}
```

**Response `503` (not connected):**

```json
{
  "error": "not_connected",
  "message": "Not connected to a relay"
}
```

---

### `POST /api/cloud/join`

Join a specific device through the relay. Wires up the `DeviceProvider` so widget interaction (toggle switches, read LED state, etc.) works through the cloud relay. The device is automatically saved to paired history on success.

> **Guard**: Returns `503` if no relay connection is active.

**Request:**

```json
{
  "device": "WiFi_Cloud_Switch"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `device` | string | yes | Device name as returned by `GET /api/cloud/devices` |

**Response `200` (success):**

```json
{
  "ok": true,
  "device": "WiFi_Cloud_Switch",
  "host": "10.0.0.17",
  "port": 9000,
  "message": "Connected to WiFi_Cloud_Switch via cloud relay"
}
```

**Response `200` (timeout):**

```json
{
  "ok": false,
  "device": "WiFi_Cloud_Switch",
  "host": "10.0.0.17",
  "port": 9000,
  "message": "Join timed out — device may be offline"
}
```

> **Internal flow**: The join URL becomes `ws://host:port/DeviceName`. `connectToDevice` calls `WebSocketService.connect(url)` which (on an already-connected session) sends the join message through the existing authenticated WebSocket. The relay confirms the join, then forwards all widget frames between the app and the device.

---

### `POST /api/cloud/disconnect`

Disconnect from the relay. Clears the cached device list and closes the WebSocket.

**Response `200`:**

```json
{
  "ok": true,
  "message": "Disconnected from relay"
}
```

---

## 16. Cloud Account Management

Cloud accounts store Ed25519 identity (keypair) and relay connection info. The app generates a keypair on first launch and stores it in platform secure storage. Accounts allow multiple relay configurations to be saved and switched.

### `GET /api/cloud/account`

Returns the current Ed25519 identity info. The account public key is what users set on their ESP32 devices' `cloud_account` config.

**Response `200`:**

```json
{
  "hasIdentity": true,
  "account": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `hasIdentity` | bool | Whether an Ed25519 keypair has been generated |
| `account` | string? | Public key hex (null if no identity exists) |

### `POST /api/cloud/account`

Generate a new Ed25519 identity. This resets the account — after calling this, update the `cloud_account` config on your ESP32 device to match the new public key.

**Response `200`:**

```json
{
  "ok": true,
  "account": "7c9ebd...",
  "message": "New Ed25519 identity generated. Set cloud_account on your ESP32 to the public key above."
}
```

### `GET /api/cloud/accounts`

List all stored cloud accounts.

**Response `200`:**

```json
{
  "accounts": [
    {
      "id": "m1abc",
      "name": "Local Relay",
      "publicKey": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed",
      "relay": "ws://10.0.0.17:9000"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Account ID (unique) |
| `name` | string | Account display name |
| `publicKey` | string | Ed25519 public key hex |
| `relay` | string | Relay WebSocket URL |

### `POST /api/cloud/accounts`

Create a new cloud account with a name and relay URL. Uses the existing Ed25519 keypair from `CloudIdentityService`.

**Request:**

```json
{
  "name": "Local Relay",
  "relay": "ws://10.0.0.17:9000"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Account display name |
| `relay` | string | no | Relay WebSocket URL (default: empty) |

**Response `200`:**

```json
{
  "ok": true,
  "account": {
    "id": "m1abc",
    "name": "Local Relay",
    "publicKey": "4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed",
    "relay": "ws://10.0.0.17:9000"
  }
}
```

### `PUT /api/cloud/accounts/{id}`

Update an account's name or relay URL.

**Request:**

```json
{
  "name": "Office Relay",
  "relay": "wss://relay.example.com:443"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | no | New display name |
| `relay` | string | no | New relay URL |

**Response `200`:**

```json
{"ok": true}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "Account m1abc not found"
}
```

### `DELETE /api/cloud/accounts/{id}`

Delete a cloud account.

**Response `200`:**

```json
{"ok": true, "message": "Account deleted"}
```

**Response `404`:**

```json
{
  "error": "not_found",
  "message": "Account m1abc not found"
}
```

---

## 17. Multi-Device API

Every device-specific endpoint (widgets, FS, transport, NVS, OTA, console) has a per-device variant that targets a specific device by its map key ID. The map key is the original BLE address / serial port path / WebSocket URL used when connecting — it does **not** change after connection.

Use `GET /api/devices` to discover connected device IDs.

### `GET /api/devices`

List all devices in the multi-device collection with their connection state.

**Response `200`:**

```json
{
  "devices": [
    {
      "id": "B4:3A:45:AE:BA:25",
      "name": "Basic_Switch",
      "connected": true,
      "hasFs": true,
      "hasOta": true,
      "hasPassword": false,
      "rssi": -48,
      "latencyMs": 40,
      "transport": "ble"
    },
    {
      "id": "ws://192.168.1.42:81",
      "name": "WiFi_Cloud_Switch",
      "connected": true,
      "hasFs": true,
      "hasOta": true,
      "hasPassword": false,
      "rssi": 0,
      "latencyMs": 12,
      "transport": "wifi"
    }
  ],
  "count": 2,
  "focusedDeviceId": "B4:3A:45:AE:BA:25"
}
```

### `POST /api/devices/connect`

Connect a new device (any transport). Creates a new `DeviceProvider` with its own transport and adds it to the collection.

**Request:**

```json
{
  "id": "B4:3A:45:AE:BA:25",
  "type": "ble",
  "baudRate": 115200
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | string | yes | — | Device ID from scan results, WebSocket URL, or demo ID |
| `type` | string | yes | — | `"ble"`, `"serial"`, `"wifi"`, `"cloud"`, or `"demo"` |
| `baudRate` | int | no | `115200` | Serial baud rate |
| `deviceName` | string | no | — | Cloud device name (cloud type only) |

**Response `200`:**

```json
{
  "ok": true,
  "message": "Connected to Basic_Switch",
  "device": {
    "id": "B4:3A:45:AE:BA:25",
    "name": "Basic_Switch",
    "connected": true,
    "transport": "ble"
  }
}
```

### `POST /api/devices/disconnect`

Disconnect a specific device. Cleans up its transport and removes it from the collection.

**Request:**

```json
{"id": "B4:3A:45:AE:BA:25"}
```

**Response `200`:**

```json
{"ok": true, "message": "Disconnected Basic_Switch"}
```

### `GET /api/devices/<id>`

Get detailed info for a specific device.

**Response `200`:**

```json
{
  "id": "B4:3A:45:AE:BA:25",
  "name": "Basic_Switch",
  "description": "",
  "connected": true,
  "hasFs": true,
  "hasOta": true,
  "hasPassword": false,
  "rssi": -48,
  "latencyMs": 40,
  "transport": "ble",
  "configJson": {...},
  "orientation": "portrait",
  "isFocused": true
}
```

---

### Per-Device Widgets

#### `GET /api/devices/<id>/widgets`

List all widgets on a specific device with runtime state.

**Response `200`:**

```json
{
  "device": "B4:3A:45:AE:BA:25",
  "widgets": [
    {
      "widgetId": 0,
      "type": "slideSwitch",
      "name": "widget_0",
      "label": "",
      "hasOutput": false,
      "hasInput": true,
      "state": {"value": 0}
    }
  ]
}
```

#### `GET /api/devices/<id>/widgets/<wid>`

Get a single widget from a specific device.

**Response `200`:**

```json
{
  "device": "B4:3A:45:AE:BA:25",
  "widget": {
    "widgetId": 0,
    "type": "slideSwitch",
    "name": "widget_0",
    "label": "",
    "hasOutput": false,
    "hasInput": true,
    "state": {"value": 0}
  }
}
```

#### `PUT /api/devices/<id>/widgets/<wid>`

Set a widget value on a specific device. Same request/response format as `PUT /api/widgets/<wid>`.

**Request:**

```json
{"values": [1]}
```

**Response `200`:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "message": "Widget 0 set to [1]"}
```

---

### Per-Device Console

#### `GET /api/devices/<id>/console`

Get console log entries for a specific device.

**Response `200`:**

```json
{
  "device": "B4:3A:45:AE:BA:25",
  "entries": [
    {"timestamp": "2026-06-20T12:00:00.000Z", "level": "info", "message": "Connected"}
  ]
}
```

#### `DELETE /api/devices/<id>/console`

Clear the console log for a specific device.

**Response `200`:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "message": "Console cleared"}
```

---

### Per-Device Filesystem

All per-device FS endpoints follow the same request/response format as their single-device counterparts, with an additional `"device"` field in the response.

| Endpoint | Description |
|----------|-------------|
| `GET /api/devices/<id>/fs/list?path=/` | List directory |
| `GET /api/devices/<id>/fs/info` | FS usage info |
| `GET /api/devices/<id>/fs/read?path=/file` | Read file (base64) |
| `POST /api/devices/<id>/fs/write` | Write file |
| `POST /api/devices/<id>/fs/upload` | Upload file (chunked) |
| `POST /api/devices/<id>/fs/mkdir` | Create directory |
| `POST /api/devices/<id>/fs/delete` | Delete file/directory |
| `POST /api/devices/<id>/fs/rename` | Rename file |
| `POST /api/devices/<id>/fs/format` | Format filesystem (destructive) |
| `POST /api/devices/<id>/fs/probe` | Probe FS availability |

**Example — `POST /api/devices/<id>/fs/write`:**

```json
{"path": "/config.json", "data": "eyJ0aGVtZSI6ICJkYXJrIn0="}
```

**Response:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "path": "/config.json", "bytesWritten": 256}
```

**Example — `POST /api/devices/<id>/fs/rename`:**

```json
{"oldPath": "/old.txt", "newPath": "/new.txt"}
```

**Response:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "oldPath": "/old.txt", "newPath": "/new.txt"}
```

---

### Per-Device OTA

#### `POST /api/devices/<id>/ota/upload`

Upload firmware to a specific device. Same request format as `POST /api/ota/upload`.

**Request:**

```json
{"data": "<base64>", "eraseAll": false}
```

**Response:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "size": 1048576, "eraseAll": false, "message": "Firmware uploaded successfully -- device rebooting"}
```

#### `GET /api/devices/<id>/ota/progress`

Get OTA progress for a specific device.

**Response `200` (idle):**

```json
{"device": "B4:3A:45:AE:BA:25", "active": false, "received": 0, "total": 0, "status": "idle"}
```

**Response `200` (uploading):**

```json
{"device": "B4:3A:45:AE:BA:25", "active": true, "received": 524288, "total": 1048576, "status": "uploading", "percentage": 50}
```

---

### Per-Device Transport

| Endpoint | Description |
|----------|-------------|
| `POST /api/devices/<id>/transport/send` | Send raw protocol packet |
| `POST /api/devices/<id>/transport/ping` | Connection check |
| `POST /api/devices/<id>/transport/wifi_info` | WiFi info |
| `POST /api/devices/<id>/transport/get_conf` | Request config |
| `POST /api/devices/<id>/transport/get_vars` | Request variable states |
| `POST /api/devices/<id>/transport/get_meta` | Request metadata |
| `POST /api/devices/<id>/transport/get_tele` | Request telemetry |

**Example — `POST /api/devices/<id>/transport/wifi_info`:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "ip": "192.168.1.42", "mode": "sta", "ssid": "MyNetwork", "rssi": -65}
```

**Example — `POST /api/devices/<id>/transport/get_conf`:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25"}
```

---

### Per-Device Settings / NVS

All per-device NVS endpoints follow the same request/response format as their single-device counterparts under `GET /api/settings/nvs*`, with an additional `"device"` field in the response.

| Endpoint | Description |
|----------|-------------|
| `GET /api/devices/<id>/settings/nvs` | NVS config (name, desc, auth state) |
| `POST /api/devices/<id>/settings/nvs` | Write config (name, desc, passwords, icon) |
| `POST /api/devices/<id>/settings/nvs/authenticate` | Authenticate with device password |
| `POST /api/devices/<id>/settings/nvs/factory-reset` | Erase NVS + reboot (requires `confirm: true`) |
| `POST /api/devices/<id>/settings/nvs/reboot` | Reboot device (NVS preserved) |
| `GET /api/devices/<id>/settings/nvs/raw/<key>` | Read raw NVS key |
| `POST /api/devices/<id>/settings/nvs/raw/<key>` | Write raw NVS key (0-255) |
| `GET /api/devices/<id>/settings/nvs/cloud-info` | Cloud relay info |

**Example — `GET /api/devices/<id>/settings/nvs`:**

```json
{
  "device": "B4:3A:45:AE:BA:25",
  "name": "Basic_Switch",
  "description": "",
  "hasPassword": false,
  "hasAdminPassword": false,
  "isAuthenticated": false,
  "isAdminMode": false,
  "isUserMode": false
}
```

**Example — `POST /api/devices/<id>/settings/nvs`:**

```json
{"name": "Updated Name", "description": "New description"}
```

**Response:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "message": "Config saved to NVS"}
```

**Example — `GET /api/devices/<id>/settings/nvs/cloud-info`:**

```json
{"ok": true, "device": "B4:3A:45:AE:BA:25", "url": "wss://relay.radiokit.app:443", "account": "4b6afa..."}
```

---

### Error Handling

All per-device endpoints return standard error responses. The `not_found` error is returned when the device ID does not match any device in the collection.

```json
{"error": "not_found", "message": "Device FAKE_ID not found"}
```

---

## 18. Error Reference


| `error` | Meaning |
|---------|---------|
| `not_connected` | No device is connected / not connected to relay |
| `no_fs` | Device does not support filesystem |
| `not_found` | Resource not found |
| `invalid_type` | Invalid transport type |
| `invalid_url` | WiFi ID must be a WebSocket URL (ws:// or wss://) |
| `invalid_hex` | Payload is not valid hex |
| `invalid_values` | Wrong number/type of values for widget |
| `connection_failed` | Could not connect to device |
| `no_history` | No previously paired device in history |
| `demo_not_found` | Invalid demo ID |
| `demo_load_failed` | Failed to load demo asset or parse config |
| `timeout` | Device did not respond / relay timed out |
| `fs_error` | Filesystem operation failed (check `message` for details) |
| `internal_error` | Unexpected server error |
| `auth_failed` | Password mismatch or auth timeout / cloud Ed25519 signing failed |
| `auth_error` | Internal authentication error |
| `nvs_error` | Failed to read/write NVS config |
| `confirmation_required` | Factory reset requires `confirm: true` |
| `ota_not_supported` | Device doesn't support OTA firmware update |
| `ota_failed` | OTA upload failed (check `message` for details) |
| `invalid_name` | Name exceeds max length |
| `invalid_description` | Description exceeds max length |
| `invalid_password` | Password exceeds max length |
| `invalid_admin_password` | Admin password exceeds max length |
| `cloud_error` | Cloud relay operation failed (check `message` for details) |
| `no_identity` | No Ed25519 identity found (generate one first) |
| `invalid_transport` | Transport must be 'ble', 'wifi', or 'cloud' |
| `switch_failed` | Transport switch failed — target unreachable |
| `switch_error` | Transport switch threw an exception |
| `not_connected` (flasher) | Not connected to a serial port |
| `no_firmware` | No firmware selected for flashing |
| `already_flashing` | A flashing operation is already in progress |
| `invalid_encoding` | Failed to decode base64-encoded data |
| `file_error` | Failed to write temp file for firmware |
