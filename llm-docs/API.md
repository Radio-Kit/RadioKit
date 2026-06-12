# RadioKit Remote Access API

The RadioKit Flutter app exposes a REST API on the local network for test automation and remote control. The server is bound to `0.0.0.0:7007`.

> **Security**: This API is intended for LAN use only. There is no authentication or encryption. Do not expose the port to the public internet.

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
  "message": "At least one of: name, description, password, adminPassword"
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
    "hasOta": true
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
| `id` | string | yes | — | Device ID from `/api/pair/devices` |
| `type` | string | yes | — | `"ble"` or `"serial"` |
| `baudRate` | int | no | `1000000` | Serial baud rate (ignored for BLE) |

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
      "description": "Unit 02"
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

---

## 14. Cloud Relay (Cloud Auth)

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

## 15. Error Reference

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
