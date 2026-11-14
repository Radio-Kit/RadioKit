---
name: radiokit-remote
description: Guide for controlling RadioKit devices remotely via the in-app Model Context Protocol (MCP) server. Use this skill when connecting to devices, managing LittleFS, uploading OTA firmware, debugging device state, or building autonomous agent workflows.
---

# RadioKit Remote Control via In-App MCP Server

## Overview

The RadioKit Flutter companion app embeds a native **Model Context Protocol (MCP)** server on `http://<app-ip>:7007` operating over HTTP with Server-Sent Events (SSE). An AI agent connects directly to this server to discover devices, read/write files, control widget state, update firmware, and stream MCU logs in real-time.

- **SSE Transport Endpoint**: `GET http://<app-ip>:7007/sse`
- **JSON-RPC Messages**: `POST http://<app-ip>:7007/messages?sessionId=<sessionId>`
- **Local Port**: `7007` (accessible on localhost or over LAN Wi-Fi / ADB port forward)

---

## Agent Configuration

To register RadioKit in your MCP client environment (Antigravity, Claude Desktop, Cursor, etc.):

### Direct Network SSE
If your agent client supports SSE / Streamable HTTP:
```json
{
  "mcpServers": {
    "radiokit": {
      "url": "http://127.0.0.1:7007/sse"
    }
  }
}
```

### Stdio Bridge via Generic Proxy
If your agent client requires local `stdio` subprocesses:
```json
{
  "mcpServers": {
    "radiokit": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:7007/sse"]
    }
  }
}
```

---

## Protocol Lifecycle

1. **SSE Handshake**:
   - The client connects to `GET /sse` with `Accept: text/event-stream`.
   - The server responds with an `endpoint` event:
     ```
     event: endpoint
     data: /messages?sessionId=44c8a3e38ac0ef6bd931f7b1e2a734f8
     ```

2. **Initialize**:
   - Post JSON-RPC request to `/messages?sessionId=<sessionId>`:
     ```json
     {
       "jsonrpc": "2.0",
       "id": 1,
       "method": "initialize",
       "params": {
         "protocolVersion": "2024-11-05",
         "clientInfo": {"name": "agent", "version": "1.0"}
       }
     }
     ```

3. **Tool Invocations**:
   - Call tools via standard `tools/call`. Results and progress updates stream back over the SSE connection.

---

## Available MCP Tools

### 1. Connection & Discovery
- `radiokit_scan_devices`
  - Arguments: `transport` ("ble" | "serial" | "all"), `timeoutSeconds` (int)
  - Returns array of discovered devices with RSSI and capabilities.
- `radiokit_connect`
  - Arguments: `id` (string), `type` ("ble" | "serial" | "wifi" | "cloud"), `baudRate` (optional int), `skipConf` (optional bool)
  - Connects app and MCU. If `skipConf: true`, connection is established without waiting for or failing on `CONF_DATA` handshake.
- `radiokit_disconnect`
  - Closes active device connection.
- `radiokit_get_connection_status`
  - Returns connection state, latency, RSSI, and device UID.
- `radiokit_get_connection_diagnostics`
  - Returns full transport/connection diagnostics: discovered services, characteristics, CCCD subscriptions, negotiated MTU, and timestamped event timeline.
- `radiokit_retry_handshake`
  - Retries requesting widget configuration (`CONF_DATA`) from the connected device.

### 2. Diagnostics & Raw Packet Snoop
- `radiokit_get_packet_log`
  - Arguments: `limit` (optional int), `direction` ("tx" | "rx"), `channel` ("widget" | "fs" | "ota" | "settings" | "print" | "raw"), `clear` (optional bool)
  - Inspects live raw frames exchanged across all transports with CRC verification flags.
- `radiokit_send_raw_packet`
  - Arguments: `packetHex` (hex string, e.g. "550004...")
  - Injects a raw byte frame directly over the active transport.

### 3. Widget Control
- `radiokit_list_widgets`
  - Lists all widgets, IDs, types, and current state values.
- `radiokit_get_widget`
  - Arguments: `widgetId` (int)
- `radiokit_set_widget`
  - Arguments: `widgetId` (int), `values` (array of numbers)
  - Example: `{"widgetId": 1, "values": [1]}` to activate a switch or push button.
- `radiokit_get_pages`
  - Lists UI page names and active page index.
- `radiokit_set_page`
  - Arguments: `page` (int)
  - Switches the active screen on MCU and companion app.

### 4. LittleFS Filesystem
- `radiokit_fs_list`
  - Arguments: `path` (default: "/")
  - Lists directory entries, sizes, and file types.
- `radiokit_fs_info`
  - Returns total, used, and free filesystem bytes.
- `radiokit_fs_read`
  - Arguments: `path` (string), `asBase64` (bool)
  - Reads file content as text or base64.
- `radiokit_fs_write`
  - Arguments: `path` (string), `data` (string), `isBase64` (bool)
  - Writes data directly to LittleFS on the MCU.
- `radiokit_fs_delete`
  - Arguments: `path` (string), `recursive` (bool)
- `radiokit_fs_mkdir`
  - Arguments: `path` (string)
- `radiokit_fs_format`
  - Erases and formats the LittleFS partition.

### 5. Over-The-Air (OTA) Updates
- `radiokit_ota_upload`
  - Arguments: `firmwareBase64` (string) or `filePath` (string), `fileName` (optional string), `eraseAll` (bool), `force` (optional bool)
  - Flashes firmware binary or `.zip` bundle to the ESP32. Set `force: true` to bypass device OTA feature flag checks. Progress notifications stream over SSE.

### 6. NVS & System Configuration
- `radiokit_nvs_get`
  - Reads device name, description, and auth state.
- `radiokit_nvs_set`
  - Arguments: `name`, `description`, `password`, `adminPassword`, `icon`.
- `radiokit_nvs_authenticate`
  - Arguments: `password` (string).
- `radiokit_reboot`
  - Reboots connected MCU.
- `radiokit_factory_reset`
  - Clears NVS and restarts device.

### 7. Hardware Flasher
- `radiokit_flasher_scan`
  - Lists available USB CDC / serial ports.
- `radiokit_flasher_flash`
  - Arguments: `portId` (string), `firmwareBase64` (string).

---

## Live MCP Resources

Agents can read live device resources without calling explicit polling endpoints:

| Resource URI | Description | MIME Type |
|---|---|---|
| `radiokit://console` | Live serial console log stream | `text/plain` |
| `radiokit://widgets` | Active widget tree & hierarchy | `application/json` |
| `radiokit://fs` | LittleFS directory structure | `application/json` |
| `radiokit://diagnostics/connection` | Live connection & GATT diagnostics | `application/json` |
| `radiokit://packets` | Real-time raw packet trace buffer | `application/json` |
| `radiokit://docs` | Available firmware skills index | `application/json` |
| `radiokit://docs/<skill>` | Markdown content of specified skill | `text/markdown` |

Subscribed resources receive `notifications/resources/updated` whenever the MCU prints a log line or changes state.
