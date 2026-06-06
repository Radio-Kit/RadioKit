# Agent Test Manual — Automatic Testing with Android + MCU

## Overview

This manual describes how to automatically test RadioKit end-to-end using:
- A **Flutter Android app** installed via ADB on a connected Android device
- A **microcontroller** (ESP32-S3) flashed with an example sketch
- The **Remote Access API** (HTTP on port 7007) exposed by the app in debug mode

## Prerequisites

| Component | Requirement |
|-----------|-------------|
| Android device | Connected via USB ADB (`adb devices` shows it) |
| MCU | ESP32-S3 (or similar) connected via USB serial |
| Build tools | `pio` (PlatformIO), Flutter SDK, `adb`, `curl`, `python3` |
| Network | Both devices must be on the same LAN (Android on Wi-Fi) |

## Workflow

```
┌──────────────┐    USB ADB     ┌──────────────┐     LAN (Wi-Fi)     ┌────────────┐
│  Host PC     │ ─────────────→ │  Android Tab  │ ←───────────────── │  ESP32-S3  │
│  (curl/pio)  │                │  (port 7007)  │    BLE (RK_ prefix) │  (serial)  │
└──────────────┘                └──────────────┘                     └────────────┘
```

## Step-by-Step

### 1. Build & Flash MCU Firmware

```bash
cd arduino-library/examples/<EXAMPLE_DIR>
pio run -t upload --upload-port /dev/ttyACM0
```

Verify the device boots correctly by reading serial output after reset:

```bash
python3 -c "
import serial, time
s = serial.Serial('/dev/ttyACM0', 115200, timeout=3)
time.sleep(1)
data = s.read(4096)
print(data.decode('utf-8', errors='replace'))
s.close()
"
```

Expected output includes:
- `BLE: Starting advertising...`
- `FS: mounted, total=..., used=...` (if filesystem example)

The ESP32 will advertise as `RK_<config.name>` (e.g., `RK_FS LED`).

### 2. Build & Install Flutter APK

```bash
cd flutter-app
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### 3. Launch App & Wait for Server

```bash
adb shell am force-stop com.rambros3d.radiokit
adb shell am start -n com.rambros3d.radiokit/.MainActivity
```

Wait for the local HTTP server on port 7007:

```bash
for i in $(seq 1 15); do
    curl -s --connect-timeout 2 http://10.0.0.6:7007/api/status > /dev/null 2>&1 \
        && echo "Server up" && break
    sleep 1
done
```

The server auto-starts on debug builds (`kDebugMode`). The Android device IP must be known (retrieve with `adb shell ip addr show wlan0`).

### 4. BLE Scan & Connect

Start a BLE scan:

```bash
curl -s -X POST http://<ANDROID_IP>:7007/api/pair/scan \
    -H 'Content-Type: application/json' \
    -d '{"type":"ble"}'
```

Wait 5-10s for discovery, then list devices:

```bash
curl -s http://<ANDROID_IP>:7007/api/pair/devices
```

Look for the device name matching your example (e.g., `"FS LED"` with MAC `B4:3A:45:AE:BA:25`).

Connect:

```bash
curl -s -X POST http://<ANDROID_IP>:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<MAC>","type":"ble"}'
```

### 5. Verify Connection & FS Detection

After connection, the app runs FS detection asynchronously (~5s). Wait and verify `hasFs`:

```bash
sleep 8
curl -s http://<ANDROID_IP>:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'connected: {d[\"connected\"]}')
print(f'hasFs: {d[\"device\"][\"hasFs\"]}')
print(f'latency: {d[\"latencyMs\"]}ms')
"
```

**Troubleshooting FS detection:** If `hasFs: false`, the FS sub-command ACK-bit matching may be broken. The MCU responds to `FS_PING (0x0B)` with `FS_PING_ACK (0x8B)`. The app registers a pending completer for `0x0B` but receives `0x8B`. Fix: in `device_provider.dart:_handleFsPacket`, match both `packet.subCmd` and `packet.subCmd & 0x7F`:

```dart
Completer<ParsedFsPacket>? pending = _pendingFs.remove(packet.subCmd);
if (pending == null) {
  pending = _pendingFs.remove(packet.subCmd & 0x7F);
}
```

### 6. Test LED / Widget Control

Toggle widget state via `PUT /api/widgets/<id>`:

```bash
# ON
curl -s -X PUT http://<ANDROID_IP>:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'

# OFF
curl -s -X PUT http://<ANDROID_IP>:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[0]}'
```

> **Note:** The API expects `{"values": [<int>]}` (array), NOT `{"value": <int>}` (singular).

Read widget state:

```bash
curl -s http://<ANDROID_IP>:7007/api/widgets/0
```

List all widgets:

```bash
curl -s http://<ANDROID_IP>:7007/api/widgets
```

### 7. Test Filesystem (if applicable)

```bash
# Info
curl -s "http://<ANDROID_IP>:7007/api/fs/info"

# List directory
curl -s "http://<ANDROID_IP>:7007/api/fs/list?path=/"

# Read file (returns base64-encoded data)
curl -s "http://<ANDROID_IP>:7007/api/fs/read?path=/demo/README.txt"

# Create directory
curl -s -X POST http://<ANDROID_IP>:7007/api/fs/mkdir \
    -H 'Content-Type: application/json' \
    -d '{"path":"/test_dir"}'

# Write file
curl -s -X POST http://<ANDROID_IP>:7007/api/fs/write \
    -H 'Content-Type: application/json' \
    -d '{"path":"/test_dir/hello.txt","data":"SGVsbG8="}'  # base64

# Delete
curl -s -X POST http://<ANDROID_IP>:7007/api/fs/delete \
    -H 'Content-Type: application/json' \
    -d '{"path":"/test_dir/hello.txt"}'
```

### 8. Test Console Log

The console log captures device-level diagnostic messages:

```bash
# Get all console entries
curl -s http://<ANDROID_IP>:7007/api/console

# Clear console
curl -s -X DELETE http://<ANDROID_IP>:7007/api/console
```

### 9. Test API Log

The API log captures all incoming HTTP requests to the remote access server:

```bash
# Get all API log entries
curl -s http://<ANDROID_IP>:7007/api/log

# Clear API log
curl -s -X DELETE http://<ANDROID_IP>:7007/api/log
```

### 10. Test Demo Loading

```bash
curl -s -X POST http://<ANDROID_IP>:7007/api/connection/demo \
    -H 'Content-Type: application/json' \
    -d '{"demoId":"WIDGETS_DEMO"}'
```

Valid demo IDs: `WIDGETS_DEMO`, `RC_CONTROLLER`, `IOT_DASHBOARD`.

### 11. Test Designs CRUD

```bash
# List designs
curl -s http://<ANDROID_IP>:7007/api/designs

# Save a design
curl -s -X POST http://<ANDROID_IP>:7007/api/designs \
    -H 'Content-Type: application/json' \
    -d '{"id":"test1","name":"Test Design","jsonContent":"{\"version\":1}"}'

# Delete single design
curl -s -X DELETE http://<ANDROID_IP>:7007/api/designs/test1

# Delete all designs
curl -s -X DELETE http://<ANDROID_IP>:7007/api/designs
```

### 12. Disconnect & Cleanup

```bash
curl -s -X POST http://<ANDROID_IP>:7007/api/connection/disconnect
```

## API Reference Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/status` | Server status, version, platform |
| GET | `/api/log` | API request log |
| DELETE | `/api/log` | Clear API log |
| GET | `/api/settings` | Read app settings |
| PUT | `/api/settings` | Update app settings |
| GET | `/api/pair/devices` | Discovered BLE/Serial devices |
| POST | `/api/pair/scan` | Start BLE/Serial scan |
| GET | `/api/connection` | Connection state + configJson |
| POST | `/api/connection/connect` | Connect to device |
| POST | `/api/connection/disconnect` | Disconnect |
| POST | `/api/connection/reconnect` | Reconnect |
| POST | `/api/connection/demo` | Load a demo |
| GET | `/api/models` | List known devices/models |
| DELETE | `/api/models` | Delete all models |
| DELETE | `/api/models/<id>` | Delete one model |
| POST | `/api/transport/send` | Send raw transport packet |
| POST | `/api/transport/ping` | Transport ping |
| POST | `/api/transport/<cmd>` | Quick transport command |
| GET | `/api/widgets` | List all widgets |
| GET | `/api/widgets/<id>` | Get single widget state |
| PUT | `/api/widgets/<id>` | Set widget input (`{"values":[<int>]}`) |
| GET | `/api/fs/info` | Filesystem info |
| GET | `/api/fs/list` | List directory |
| GET | `/api/fs/read` | Read file (base64) |
| POST | `/api/fs/write` | Write file (base64 data) |
| POST | `/api/fs/mkdir` | Create directory |
| POST | `/api/fs/delete` | Delete file/directory |
| POST | `/api/fs/rename` | Rename file/directory |
| POST | `/api/fs/format` | Format filesystem |
| GET | `/api/console` | Device console log |
| DELETE | `/api/console` | Clear console log |
| GET | `/api/designs` | List saved designs |
| POST | `/api/designs` | Save a design |
| DELETE | `/api/designs` | Delete all designs |
| DELETE | `/api/designs/<id>` | Delete one design |

## Known Issues

1. **FS sub-command ACK matching**: FS responses use sub-cmd with `0x80` bit (e.g., `FS_PING_ACK = 0x8B`), but the pending completer is registered for the request sub-cmd (e.g., `FS_PING = 0x0B`). The fix is to also match `subCmd & 0x7F` in the response handler. See step 5.

2. **BLE transport FS detection timing**: FS detection runs after a 3.5s delay post-connection. If BLE is still establishing, the FS_PING may timeout. Wait 8-10s before relying on `hasFs`.

3. **Serial port permissions**: On Linux, `/dev/ttyACM0` may have group `nobody`. Add your user to the `dialout` group or use `chmod a+rw`.

4. **Remote access server is debug-only**: The server only starts automatically in `kDebugMode`. In release mode, it must be enabled manually in settings or via `POST /api/settings`.
