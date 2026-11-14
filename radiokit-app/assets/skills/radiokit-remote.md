---
name: radiokit-remote
description: Remote testing, diagnostics, packet tracing, LittleFS manipulation, OTA flashing, and widget telemetry via the in-app Model Context Protocol (MCP) server.
---

# RadioKit Remote Skill (In-App MCP Server)

RadioKit features a built-in **Model Context Protocol (MCP)** server on port `7007` (`http://127.0.0.1:7007` via ADB or local LAN). AI agents can connect over SSE to discover, control, and test hardware connected to the companion app.

## Quick Start (SSE Handshake)

1. **Ensure Port Forwarding**:
   ```bash
   adb forward tcp:7007 tcp:7007
   ```

2. **Connect SSE**:
   ```bash
   curl -N http://127.0.0.1:7007/sse
   ```
   Server responds with:
   ```text
   event: endpoint
   data: /messages?sessionId=<session-id>
   ```

3. **Initialize Protocol**:
   Send JSON-RPC POST to `http://127.0.0.1:7007/messages?sessionId=<session-id>`:
   ```json
   {
     "jsonrpc": "2.0",
     "id": 1,
     "method": "initialize",
     "params": {
       "protocolVersion": "2024-11-05",
       "clientInfo": {"name": "agent", "version": "1.0.0"}
     }
   }
   ```

4. **Call Tools**:
   Send `tools/call` requests with standard MCP arguments. Results stream back over the SSE connection.

---

## 68 Registered MCP Tools

### 1. Connection & Multi-Device Management
- `radiokit_scan_devices`: Scans for BLE / serial devices (`timeoutSeconds`, `transport`).
- `radiokit_connect`: Connects to target device (`deviceId`, `transport`, `baudRate`, `skipConf`). Set `skipConf: true` to bypass strict `CONF_DATA` handshake during board bringup.
- `radiokit_disconnect`: Disconnects active or specified device (`deviceId`).
- `radiokit_get_connection_status`: Queries connection state, transport, device name, and RSSI (`deviceId`).
- `radiokit_get_connection_diagnostics`: Returns low-level GATT diagnostics (services, characteristics, CCCD status, negotiated MTU, connection event timeline).
- `radiokit_retry_handshake`: Manually re-sends widget handshake config query to active device (`deviceId`).
- `radiokit_list_active_devices`: Lists all active devices in the multi-device pool with connection and transport status.
- `radiokit_switch_device`: Switches the actively focused device in the multi-device pool (`deviceId`).

### 2. Pairing & Saved Devices
- `radiokit_reconnect`: Reconnects to most recent device or specific device from history (`deviceId`).
- `radiokit_get_paired_devices`: Lists all previously paired devices saved in local history.
- `radiokit_forget_device`: Removes a device from paired history (`uid`).
- `radiokit_clear_paired_devices`: Clears all paired devices from history.

### 3. Diagnostics & Raw Packet Snoop
- `radiokit_get_packet_log`: Retrieves raw TX/RX packet logs with hex frames, sub-protocol channels (`widget`, `fs`, `ota`, `settings`, `print`, `raw`), and CRC verification (`limit`, `direction`, `channel`, `clear`).
- `radiokit_send_raw_packet`: Injects raw hex byte frame directly into transport stream (`packetHex`).

### 4. Widgets & Telemetry
- `radiokit_list_widgets`: Lists all widgets with current state, bounds, and values (`deviceId`).
- `radiokit_get_widget`: Fetches a single widget by numeric ID (`widgetId`, `deviceId`).
- `radiokit_set_widget`: Sets widget input values (e.g. button state, slider value, joystick `[x, y]`) (`widgetId`, `values`, `deviceId`).
- `radiokit_get_pages`: Retrieves all widget page configurations (`deviceId`).
- `radiokit_set_page`: Switches the active widget page (`pageIndex`, `pageId`, `deviceId`).
- `radiokit_clear_widgets`: Clears all widgets and page configuration for a device (`deviceId`).

### 5. LittleFS Device Filesystem
- `radiokit_fs_list`: Lists directory contents on device filesystem (`path`, `deviceId`).
- `radiokit_fs_info`: Returns filesystem usage (used bytes, total bytes, free bytes) (`deviceId`).
- `radiokit_fs_read`: Reads file contents as UTF-8 text or Base64 binary (`path`, `asBase64`, `deviceId`).
- `radiokit_fs_write`: Writes or creates a file on device filesystem (`path`, `content`, `base64`, `deviceId`).
- `radiokit_fs_delete`: Deletes a file or directory (`path`, `deviceId`).
- `radiokit_fs_mkdir`: Creates a directory on device filesystem (`path`, `deviceId`).
- `radiokit_fs_format`: Formats the LittleFS storage partition on device (`deviceId`).
- `radiokit_fs_rename`: Renames or moves a file or directory on device filesystem (`oldPath`, `newPath`, `deviceId`).
- `radiokit_fs_probe`: Probes LittleFS availability and reports storage readiness (`deviceId`).

### 6. OTA & Firmware Management
- `radiokit_ota_upload`: Streams new firmware binary block-by-block with progress events. Accepts `firmwareBase64` or `filePath`, and optional `force: true` (`deviceId`).
- `radiokit_ota_cancel`: Aborts an in-progress OTA firmware update (`deviceId`).
- `radiokit_ota_status`: Returns current OTA firmware transfer progress and status (`deviceId`).

### 7. Device NVS & System Control
- `radiokit_nvs_get`: Reads non-volatile storage key (`key`, `deviceId`).
- `radiokit_nvs_set`: Sets non-volatile storage key/value (`key`, `value`, `deviceId`).
- `radiokit_nvs_authenticate`: Unlocks protected NVS settings with password (`password`, `deviceId`).
- `radiokit_reboot`: Reboots connected device (`deviceId`).
- `radiokit_factory_reset`: Resets connected device to factory defaults (`deviceId`).
- `radiokit_nvs_raw_write`: Writes a raw key-value pair to device NVS via direct frame (`key`, `value`, `deviceId`).

### 8. Transport Diagnostics & Quick Commands
- `radiokit_transport_ping`: Pings device and measures round-trip latency (RTT) in milliseconds (`deviceId`).
- `radiokit_transport_wifi_info`: Returns device WiFi connection info (SSID, IP, RSSI) (`deviceId`).
- `radiokit_transport_quick_cmd`: Sends a raw single-byte quick command directly to the device (`command`, `deviceId`).

### 9. Serial ESP32 Flasher
- `radiokit_flasher_scan`: Detects USB serial ports available for ESP32 flashing.
- `radiokit_flasher_flash`: Flashes firmware image/bundle to ESP32 via serial (`port`, `baudRate`, `firmwareBase64`, `filePath`).
- `radiokit_flasher_status`: Returns current state, progress percentage, and stage of serial flasher.
- `radiokit_flasher_erase`: Erases flash memory of connected ESP32 (`port`, `baudRate`).
- `radiokit_flasher_clear_log`: Clears serial flasher debug logs.

### 10. Visual Designer & Code Generator
- `radiokit_designer_list`: Lists all saved visual designer templates.
- `radiokit_designer_get`: Gets a saved visual designer template by ID (`id`).
- `radiokit_designer_save`: Creates or updates a visual designer template (`id`, `name`, `layoutJson`).
- `radiokit_designer_delete`: Deletes a visual designer template (`id`).
- `radiokit_designer_duplicate`: Duplicates a visual designer template (`id`, `newName`).
- `radiokit_designer_import`: Imports a designer template from JSON string or file path (`json`, `filePath`).
- `radiokit_designer_export`: Exports a designer template as JSON (`id`).
- `radiokit_generate_design_header`: Generates Arduino C++ `.h` header from design layout (`id`, `layoutJson`).
- `radiokit_designer_parse_header`: Parses an Arduino C++ header file to extract widget definitions (`headerText`, `filePath`).

### 11. Cloud Relay & Identity
- `radiokit_cloud_status`: Returns cloud relay connection status, registered models, and active sessions.
- `radiokit_cloud_connect`: Connects to cloud relay with an account identity (`accountName`, `relayUrl`).
- `radiokit_cloud_disconnect`: Disconnects from cloud relay.
- `radiokit_cloud_list_accounts`: Lists all configured cloud identity accounts.
- `radiokit_cloud_create_account`: Generates a new cryptographic cloud identity account (`name`, `relayUrl`).
- `radiokit_cloud_delete_account`: Deletes a cloud identity account (`name`).
- `radiokit_cloud_switch_account`: Switches active cloud identity account (`name`).
- `radiokit_cloud_get_device_info`: Retrieves cloud provisioning info from connected device (`deviceId`).

### 12. App Settings, Session & Remote State
- `radiokit_get_settings`: Returns current companion app settings (theme, followRemote, log levels).
- `radiokit_update_settings`: Updates companion app settings (`followRemote`, `theme`, `autoReconnect`).
- `radiokit_get_session_state`: Returns overall companion app session state (viewState, currentRoute, active device, memory).
- `radiokit_clear_api_logs`: Clears remote access API / MCP call logs.

---

## 13 Live MCP Resources

| URI | Content | MIME Type |
|---|---|---|
| `radiokit://console` | Real-time MCU serial console text log output | `text/plain` |
| `radiokit://widgets` | Current widget tree hierarchy, layout bounds, and live telemetry values | `application/json` |
| `radiokit://fs` | Cached filesystem directory tree of connected device | `application/json` |
| `radiokit://diagnostics/connection` | Live connection & GATT diagnostics (services, characteristics, CCCD, MTU, event logs) | `application/json` |
| `radiokit://packets` | Real-time raw packet trace buffer (all TX/RX frames across protocols) | `application/json` |
| `radiokit://devices` | Active multi-device pool list with connection state and transport details | `application/json` |
| `radiokit://models` | Saved paired device models and hardware profiles from local history | `application/json` |
| `radiokit://designs` | Saved visual designer layouts and widget templates | `application/json` |
| `radiokit://session` | Overall app session state (current route, view state, focused device, memory) | `application/json` |
| `radiokit://app-log` | Remote access / MCP tool invocation and API event log | `application/json` |
| `radiokit://flasher/log` | Serial hardware flasher console logs | `text/plain` |
| `radiokit://docs` | Documentation index | `application/json` |
| `radiokit://docs/<skill>` | Bundled skill markdown manuals (firmware, widgets, transports, etc.) | `text/markdown` |
