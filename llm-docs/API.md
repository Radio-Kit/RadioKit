# RadioKit Model Context Protocol (MCP) Server

> **Status: REST API Retired**  
> The previous custom REST API (`/api/*`) on port 7007 has been **completely retired and replaced** by an in-app **Model Context Protocol (MCP)** server over HTTP/SSE. Backward compatibility was deprecated and removed.

The RadioKit Flutter companion app exposes a standard Model Context Protocol (MCP) server on port `7007`. AI agents connect directly to this port to discover tools, execute actions (pairing, widgets, filesystem, OTA, NVS, flasher), and read live resources (console logs, widget tree, filesystem tree, documentation).

---

## Connection & Transport

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/sse` | `GET` | Server-Sent Events stream for receiving JSON-RPC messages and endpoint notification |
| `/messages?sessionId=<id>` | `POST` | Bidirectional JSON-RPC 2.0 messages |
| `/status` | `GET` | Health check returning `{"server":"radiokit-app","protocol":"mcp","version":"2.1.1",...}` |
| `/` | `GET` | Human-readable MCP server status and greeting |

### Connection URLs
- **Over ADB Port Forward**: `http://127.0.0.1:7007` (run `adb forward tcp:7007 tcp:7007`)
- **Over LAN / USB Tethering**: `http://<device-ip>:7007` (e.g. `http://192.168.153.123:7007`)

---

## MCP Protocol Handshake

### 1. Initialize Handshake
**Client -> Server (`POST /messages?sessionId=<id>`):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": { "name": "agent-client", "version": "1.0.0" }
  }
}
```

**Server -> Client (`SSE`):**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": { "listChanged": true },
      "resources": { "subscribe": true, "listChanged": true }
    },
    "serverInfo": { "name": "radiokit-app", "version": "2.1.1" }
  }
}
```

---

## Available MCP Tools (26 Tools)

All previous REST endpoints are now available as typed MCP tools callable via `tools/call`:

### Connection & Discovery
- `radiokit_scan_devices`: Scans for BLE / serial RadioKit devices (`timeoutSeconds`, `transport`).
- `radiokit_connect`: Connects to a target device (`deviceId`, `transport`, `baudRate`).
- `radiokit_disconnect`: Disconnects the active or specified device.
- `radiokit_get_connection_status`: Queries connection state, transport, and device metadata.

### Widgets & Control UI
- `radiokit_list_widgets`: Lists all widgets with current state, bounds, and values.
- `radiokit_get_widget`: Fetches a single widget by `widgetId`.
- `radiokit_set_widget`: Sends user action or state change to a widget (`widgetId`, `value`, `action`).
- `radiokit_get_pages`: Retrieves all page configurations.
- `radiokit_set_page`: Switches active page (`pageIndex` or `pageId`).

### LittleFS Device Filesystem
- `radiokit_fs_list`: Lists directory contents on the connected device.
- `radiokit_fs_info`: Returns filesystem usage (used, total bytes).
- `radiokit_fs_read`: Reads file contents (base64 or text).
- `radiokit_fs_write`: Writes or creates a file on device filesystem.
- `radiokit_fs_delete`: Deletes a file or directory.
- `radiokit_fs_mkdir`: Creates a directory.
- `radiokit_fs_format`: Formats the device LittleFS partition.

### OTA Firmware Update
- `radiokit_ota_upload`: Streams new firmware binary block-by-block with progress events.

### Device NVS & System
- `radiokit_nvs_get`: Reads non-volatile storage key.
- `radiokit_nvs_set`: Sets non-volatile storage key/value.
- `radiokit_nvs_authenticate`: Unlocks protected NVS settings with password.
- `radiokit_reboot`: Reboots connected device.
- `radiokit_factory_reset`: Resets device to factory defaults.

### Serial Flasher
- `radiokit_flasher_scan`: Detects USB serial ports for ESP32 flashing.
- `radiokit_flasher_flash`: Flashes firmware image to ESP32 via serial.

### Designer
- `radiokit_get_design`: Reads saved visual designer layouts.
- `radiokit_generate_design_header`: Generates Arduino C++ `.h` header from design layout.

---

## Live MCP Resources

Agents can inspect dynamic app resources via `resources/read`:

| URI | Content |
| :--- | :--- |
| `radiokit://console` | Real-time MCU serial console log output |
| `radiokit://widgets` | Current widget tree hierarchy and values |
| `radiokit://fs` | Cached filesystem directory tree |
| `radiokit://docs` | Documentation index |
| `radiokit://docs/<skill>` | Bundled skill markdown manuals (firmware, widgets, transports, etc.) |

---

## Follow Remote Mode & UI Feedback

When the user enables **Follow Remote** in System Settings:
- MCP tool calls automatically navigate the app to the relevant screen (e.g. `radiokit_flasher_scan` -> `/flasher`, `radiokit_scan_devices` -> `/models`, `radiokit_fs_*` -> `/dev-tools/esp32-fs`).
- An edge glow indicator flashes on the phone screen to visually confirm agent activity.
- The in-app `ApiLogView` logs incoming MCP calls and tool execution results in real-time.
