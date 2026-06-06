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

## 2. Settings

### `GET /api/settings`

Returns all current app settings.

**Response `200`:**

```json
{
  "showDemo": true,
  "useFullscreen": false,
  "enableDevTools": true,
  "interfaceScale": 100,
  "enableRemoteAccess": true
}
```

### `PUT /api/settings`

Update one or more settings. Only include the fields you want to change.

**Request:**

```json
{
  "showDemo": false,
  "interfaceScale": 120
}
```

**Response `200`:**

```json
{
  "ok": true
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
    "hasFs": true
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

Write data to a file. Creates or truncates the file.

**Request:**

```json
{
  "path": "/demo/config.json",
  "data": "eyJ0aGVtZSI6ICJkYXJrIn0="
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | File path |
| `data` | string | yes | File content as base64 |

**Response `200`:**

```json
{
  "ok": true,
  "path": "/demo/config.json",
  "bytesWritten": 256
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

## 12. Error Reference

| `error` | Meaning |
|---------|---------|
| `not_connected` | No device is connected |
| `no_fs` | Device does not support filesystem |
| `not_found` | Resource not found |
| `invalid_type` | Invalid transport type |
| `invalid_hex` | Payload is not valid hex |
| `invalid_values` | Wrong number/type of values for widget |
| `connection_failed` | Could not connect to device |
| `no_history` | No previously paired device in history |
| `demo_not_found` | Invalid demo ID |
| `demo_load_failed` | Failed to load demo asset or parse config |
| `timeout` | Device did not respond |
| `fs_error` | Filesystem operation failed (check `message` for details) |
| `internal_error` | Unexpected server error |
