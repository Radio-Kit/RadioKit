---
name: radiokit-remote
description: Guide for controlling RadioKit devices remotely via the Flutter app's REST API. Use this skill when connecting to devices, managing filesystem, uploading OTA firmware, debugging device state, or building autonomous agent workflows.
---

# RadioKit Remote Access API

## Overview

The RadioKit Flutter app exposes a REST API on `http://<app-ip>:7007/api` for remote device control. An agent can use this API to:

- Discover and connect to devices (BLE, Serial, WiFi, Cloud)
- Read/write files on the device filesystem
- Upload OTA firmware updates
- Read and control widget state
- Monitor device console output
- Debug device issues autonomously

**Base URL**: `http://127.0.0.1:7007/api` (localhost) or `http://<app-ip>:7007/api` (LAN)

**Security**: LAN only. No auth or encryption. Never expose to the internet.

## Connection Flow

### 1. Check Server Status

```bash
curl http://127.0.0.1:7007/api/status
```

```json
{
  "version": "1.0.0",
  "uptime": 1234,
  "port": 7007,
  "localIp": "192.168.1.42",
  "platform": "linux"
}
```

### 2. Discover Devices

**BLE scan**:
```bash
curl -X POST http://127.0.0.1:7007/api/pair/scan
# Poll until complete:
curl http://127.0.0.1:7007/api/pair/devices
```

**Response**:
```json
{
  "devices": [
    {
      "id": "00:11:22:33:44:55",
      "name": "MyDevice",
      "rssi": -58,
      "type": "ble"
    }
  ]
}
```

### 3. Connect

```bash
curl -X POST http://127.0.0.1:7007/api/connection/connect \
  -H 'Content-Type: application/json' \
  -d '{"id": "00:11:22:33:44:55", "type": "ble"}'
```

**For WiFi**:
```bash
curl -X POST http://127.0.0.1:7007/api/connection/connect \
  -H 'Content-Type: application/json' \
  -d '{"id": "ws://192.168.1.100:5555", "type": "wifi"}'
```

**Poll until connected**:
```bash
curl http://127.0.0.1:7007/api/connection
```

```json
{
  "connected": true,
  "device": {
    "id": "00:11:22:33:44:55",
    "name": "MyDevice",
    "type": "ble",
    "hasFs": true,
    "hasOta": true
  },
  "rssi": -58,
  "latencyMs": 24
}
```

### 4. Disconnect

```bash
curl -X POST http://127.0.0.1:7007/api/connection/disconnect
```

## Filesystem Operations

All FS endpoints require a connected device with `hasFs: true`.

### List Directory

```bash
curl "http://127.0.0.1:7007/api/fs/list?path=/"
```

```json
{
  "path": "/",
  "entries": [
    {"name": "demo", "type": "directory", "size": 0},
    {"name": "README.txt", "type": "file", "size": 1240}
  ]
}
```

### Get Storage Info

```bash
curl http://127.0.0.1:7007/api/fs/info
```

```json
{
  "totalBytes": 2097152,
  "usedBytes": 452198,
  "freeBytes": 1644954,
  "blockSize": 4096
}
```

### Read File

```bash
curl "http://127.0.0.1:7007/api/fs/read?path=/config.json"
```

```json
{
  "path": "/config.json",
  "size": 1024,
  "encoding": "base64",
  "data": "eyJ0aGVtZSI6ICJkYXJrIn0="
}
```

Decode base64: `echo "eyJ0aGVtZSI6ICJkYXJrIn0=" | base64 -d`

### Write File

```bash
curl -X POST http://127.0.0.1:7007/api/fs/write \
  -H 'Content-Type: application/json' \
  -d '{
    "path": "/config.json",
    "data": "eyJ0aGVtZSI6ICJkYXJrIn0="
  }'
```

### Upload File (chunked, for large files)

```bash
curl -X POST http://127.0.0.1:7007/api/fs/upload \
  -H 'Content-Type: application/json' \
  -d '{
    "path": "/firmware.bin",
    "data": "<base64-encoded-content>",
    "chunkSize": 16384
  }'
```

### Create Directory

```bash
curl -X POST http://127.0.0.1:7007/api/fs/mkdir \
  -H 'Content-Type: application/json' \
  -d '{"path": "/logs"}'
```

### Delete File/Directory

```bash
curl -X POST http://127.0.0.1:7007/api/fs/delete \
  -H 'Content-Type: application/json' \
  -d '{"path": "/old_file.txt", "recursive": false}'
```

### Rename/Move

```bash
curl -X POST http://127.0.0.1:7007/api/fs/rename \
  -H 'Content-Type: application/json' \
  -d '{"oldPath": "/old.txt", "newPath": "/new.txt"}'
```

### Format Filesystem (destructive)

```bash
curl -X POST http://127.0.0.1:7007/api/fs/format
```

### Probe FS Support

```bash
curl -X POST http://127.0.0.1:7007/api/fs/probe
```

## OTA Firmware Update

### Upload Firmware

```bash
# Read binary and base64-encode
FIRMWARE_B64=$(base64 -w0 firmware.bin)

curl -X POST http://127.0.0.1:7007/api/ota/upload \
  -H 'Content-Type: application/json' \
  -d "{\"data\": \"$FIRMWARE_B64\", \"eraseAll\": false}"
```

| Field | Type | Description |
|-------|------|-------------|
| `data` | string | Base64-encoded firmware binary |
| `eraseAll` | bool | Erase NVS + FS after update (default: false) |

**Response** (may take 10-60s):
```json
{
  "ok": true,
  "size": 1048576,
  "eraseAll": false,
  "message": "Firmware uploaded successfully - device rebooting"
}
```

### Check OTA Progress

```bash
curl http://127.0.0.1:7007/api/ota/progress
```

```json
{
  "active": true,
  "received": 524288,
  "total": 1048576,
  "status": "uploading",
  "percentage": 50
}
```

**Status values**: `idle`, `starting`, `uploading`, `rebooting`

## Widget Control

### List All Widgets

```bash
curl http://127.0.0.1:7007/api/widgets
```

```json
{
  "widgets": [
    {
      "widgetId": 1,
      "type": "button",
      "name": "button_1",
      "label": "FIRE",
      "hasOutput": false,
      "state": {"value": 0}
    },
    {
      "widgetId": 4,
      "type": "text",
      "name": "text_1",
      "label": "Status",
      "hasOutput": true,
      "state": {"text": "Hello"}
    }
  ]
}
```

### Get Single Widget

```bash
curl http://127.0.0.1:7007/api/widgets/1
```

### Set Widget Value

```bash
# Push button press
curl -X PUT http://127.0.0.1:7007/api/widgets/1 \
  -H 'Content-Type: application/json' \
  -d '{"values": [1]}'

# Slider to 75%
curl -X PUT http://127.0.0.1:7007/api/widgets/7 \
  -H 'Content-Type: application/json' \
  -d '{"values": [75]}'

# Joystick X=12, Y=-30
curl -X PUT http://127.0.0.1:7007/api/widgets/10 \
  -H 'Content-Type: application/json' \
  -d '{"values": [12, -30]}'
```

**Widget value reference**:

| Widget Type | `values` | Effect |
|-------------|----------|--------|
| Push button | `[1]` then `[0]` | Press then release |
| Toggle button | `[1]` or `[0]` | Set ON/OFF |
| Slider | `[-100]` to `[100]` | Set position |
| Joystick | `[x, y]` | Set both axes (-100..+100) |
| Multiple (single) | `[index]` | Select item |
| Multiple (multi) | `[bitmask]` | Toggle items |

## Console Monitoring

### Get Console Output

```bash
curl http://127.0.0.1:7007/api/console
```

```json
{
  "entries": [
    {"timestamp": "2026-06-20T12:00:00.000Z", "level": "info", "message": "Connected"},
    {"timestamp": "2026-06-20T12:00:01.000Z", "level": "info", "message": "Temp: 24.5 C"}
  ]
}
```

### Clear Console

```bash
curl -X DELETE http://127.0.0.1:7007/api/console
```

## Multi-Device Control

### List All Connected Devices

```bash
curl http://127.0.0.1:7007/api/devices
```

```json
{
  "devices": [
    {"id": "AA:BB:CC:DD:EE:01", "name": "Device1", "connected": true, "transport": "ble"},
    {"id": "ws://192.168.1.100:5555", "name": "Device2", "connected": true, "transport": "wifi"}
  ],
  "count": 2,
  "focusedDeviceId": "AA:BB:CC:DD:EE:01"
}
```

### Per-Device Operations

Target a specific device regardless of focus:

```bash
# Widgets
curl http://127.0.0.1:7007/api/devices/AA:BB:CC:DD:EE:01/widgets
curl -X PUT http://127.0.0.1:7007/api/devices/AA:BB:CC:DD:EE:01/widgets/1 \
  -H 'Content-Type: application/json' -d '{"values": [1]}'

# Console
curl http://127.0.0.1:7007/api/devices/AA:BB:CC:DD:EE:01/console

# FS (per-device)
curl "http://127.0.0.1:7007/api/devices/AA:BB:CC:DD:EE:01/fs/list?path=/"
```

## Autonomous Debugging Patterns

### Pattern 1: Health Check Loop

```bash
#!/bin/bash
# Monitor device health every 5 seconds

while true; do
  # Check connection
  STATUS=$(curl -s http://127.0.0.1:7007/api/connection)
  CONNECTED=$(echo "$STATUS" | jq -r '.connected')

  if [ "$CONNECTED" != "true" ]; then
    echo "Device disconnected! Attempting reconnect..."
    # Try to reconnect
    curl -X POST http://127.0.0.1:7007/api/connection/reconnect
    sleep 5
    continue
  fi

  # Check RSSI
  RSSI=$(echo "$STATUS" | jq -r '.rssi')
  LATENCY=$(echo "$STATUS" | jq -r '.latencyMs')

  echo "RSSI: $RSSI dBm | Latency: $LATENCY ms"

  # Alert on poor signal
  if [ "$RSSI" -lt -80 ] 2>/dev/null; then
    echo "WARNING: Weak signal ($RSSI dBm)"
  fi

  sleep 5
done
```

### Pattern 2: Log File Sync

```bash
#!/bin/bash
# Sync device logs to local machine

DEVICE_LOG_DIR="./device_logs"
mkdir -p "$DEVICE_LOG_DIR"

while true; do
  # List files in device /logs directory
  FILES=$(curl -s "http://127.0.0.1:7007/api/fs/list?path=/logs")

  for ROW in $(echo "$FILES" | jq -r '.entries[] | select(.type=="file") | .name'); do
    LOCAL_FILE="$DEVICE_LOG_DIR/$ROW"

    # Read file content
    CONTENT=$(curl -s "http://127.0.0.1:7007/api/fs/read?path=/logs/$ROW")
    DATA=$(echo "$CONTENT" | jq -r '.data')

    # Decode and save
    echo "$DATA" | base64 -d > "$LOCAL_FILE"
    echo "Synced: $ROW"
  done

  sleep 60
done
```

### Pattern 3: Widget State Monitor

```bash
#!/bin/bash
# Monitor widget state changes and react

PREV_STATE=""

while true; do
  STATE=$(curl -s http://127.0.0.1:7007/api/widgets | jq -c '.widgets')

  if [ "$STATE" != "$PREV_STATE" ] && [ -n "$PREV_STATE" ]; then
    echo "Widget state changed!"
    # Diff and log changes
    echo "$PREV_STATE" | jq -c '.[]' > /tmp/prev_widgets
    echo "$STATE" | jq -c '.[]' > /tmp/curr_widgets
    diff /tmp/prev_widgets /tmp/curr_widgets || true
  fi

  PREV_STATE="$STATE"
  sleep 1
done
```

### Pattern 4: Autonomous Firmware Update

```bash
#!/bin/bash
# Build and upload firmware automatically

FIRMWARE_PATH="./build/firmware.bin"

# 1. Build firmware
echo "Building firmware..."
pio run -e esp32dev
cp .pio/build/esp32dev/firmware.bin "$FIRMWARE_PATH"

# 2. Check OTA support
CONN=$(curl -s http://127.0.0.1:7007/api/connection)
HAS_OTA=$(echo "$CONN" | jq -r '.device.hasOta')

if [ "$HAS_OTA" != "true" ]; then
  echo "ERROR: Device does not support OTA"
  exit 1
fi

# 3. Upload firmware (eraseAll: true ensures stale NVS settings are cleared)
echo "Uploading firmware..."
FIRMWARE_B64=$(base64 -w0 "$FIRMWARE_PATH")
RESULT=$(curl -s -X POST http://127.0.0.1:7007/api/ota/upload \
  -H 'Content-Type: application/json' \
  -d "{\"data\": \"$FIRMWARE_B64\", \"eraseAll\": true}")

echo "$RESULT" | jq .

# 4. Wait for reboot
echo "Waiting for device to reboot..."
sleep 10

# 5. Reconnect
curl -X POST http://127.0.0.1:7007/api/connection/reconnect
sleep 5

# 6. Verify
CONN=$(curl -s http://127.0.0.1:7007/api/connection)
echo "Reconnected: $(echo "$CONN" | jq -r '.connected')"
```

### Pattern 5: Filesystem Integrity Check

```bash
#!/bin/bash
# Verify all expected files exist on device

EXPECTED_FILES=(
  "/config.json"
  "/scripts/main.py"
  "/data/sensors.csv"
)

for FILE in "${EXPECTED_FILES[@]}"; do
  RESP=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:7007/api/fs/read?path=$FILE")

  if [ "$RESP" = "200" ]; then
    echo "OK: $FILE"
  else
    echo "MISSING: $FILE (HTTP $RESP)"
    # Create default if missing
    case "$FILE" in
      /config.json)
        curl -X POST http://127.0.0.1:7007/api/fs/write \
          -H 'Content-Type: application/json' \
          -d '{"path":"/config.json","data":"eyJ0aGVtZSI6ImRlZmF1bHQifQ=="}'
        echo "  -> Created default config.json"
        ;;
    esac
  fi
done
```

## Error Handling

All endpoints return standard error format:

```json
{
  "error": "error_code",
  "message": "Human-readable description"
}
```

**Common error codes**:

| Code | HTTP | Meaning |
|------|------|---------|
| `not_found` | 404 | Device/file/widget not found |
| `invalid_params` | 400 | Bad request parameters |
| `connection_failed` | 200 | Device did not respond |
| `ota_not_supported` | 400 | Device lacks OTA support |
| `ota_failed` | 200 | OTA upload failed |
| Service unavailable | 503 | Not connected to any device |

## Quick Reference

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Server status | GET | `/api/status` |
| BLE scan | POST | `/api/pair/scan` |
| Scan results | GET | `/api/pair/devices` |
| Connect | POST | `/api/connection/connect` |
| Connection state | GET | `/api/connection` |
| Disconnect | POST | `/api/connection/disconnect` |
| Reconnect | POST | `/api/connection/reconnect` |
| List widgets | GET | `/api/widgets` |
| Get widget | GET | `/api/widgets/{id}` |
| Set widget | PUT | `/api/widgets/{id}` |
| FS list | GET | `/api/fs/list?path=/` |
| FS info | GET | `/api/fs/info` |
| FS read | GET | `/api/fs/read?path=/file` |
| FS write | POST | `/api/fs/write` |
| FS upload | POST | `/api/fs/upload` |
| FS mkdir | POST | `/api/fs/mkdir` |
| FS delete | POST | `/api/fs/delete` |
| FS rename | POST | `/api/fs/rename` |
| FS format | POST | `/api/fs/format` |
| FS probe | POST | `/api/fs/probe` |
| OTA upload | POST | `/api/ota/upload` |
| OTA progress | GET | `/api/ota/progress` |
| Library version | GET | `/api/library/version` |
| Library download | GET | `/api/library/download` |
| Console log | GET | `/api/console` |
| Console clear | DELETE | `/api/console` |
| Device list | GET | `/api/devices` |
| Per-device widgets | GET | `/api/devices/{id}/widgets` |
| Per-device console | GET | `/api/devices/{id}/console` |
