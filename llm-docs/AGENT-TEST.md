# Agent Test Manual — Automatic Testing

## Overview

This manual describes how to automatically test RadioKit end-to-end using the **Remote Access API** (HTTP on port 7007) exposed by the app in debug mode.

The agent drives tests from the host PC via `curl` against a running instance of the RadioKit Flutter app that has its HTTP server enabled. The app connects to a real MCU over BLE or Serial and provides full control over pairing, widgets, filesystem, and settings.

### Architecture

```
┌──────────────┐   platform-specific   ┌──────────────┐   transport   ┌────────────┐
│  Host PC     │ ────────────────────→ │  RadioKit     │ ←─────────── │  MCU       │
│  (curl/pio)  │    ADB / native       │  Flutter App  │   BLE/Serial │  (ESP32)   │
└──────────────┘                       │  (port 7007)  │              └────────────┘
                                       └──────────────┘
```

### Prerequisites (all platforms)

| Dependency | Purpose |
|-----------|---------|
| `curl` | Making HTTP requests to the API |
| `python3` | Parsing JSON responses, reading serial output |
| Flutter SDK | Building the app |
| PlatformIO (`pio`) | Building MCU firmware |

### Common Setup

#### 1. Build & install the Flutter app

```bash
cd radiokit-app
flutter build <platform> --debug
# Install per platform (see platform sections below)
```

#### 2. Launch the app

```bash
# Launch per platform (see platform sections below)
```

#### 3. Wait for HTTP server

```bash
APP_IP="<device-ip>"
for i in $(seq 1 15); do
    curl -s --connect-timeout 2 http://$APP_IP:7007/api/status > /dev/null 2>&1 \
        && echo "Server up at http://$APP_IP:7007" && break
    sleep 1
done
```

The server auto-starts on `kDebugMode` builds. On release, enable via `PUT /api/settings` first.

#### 4. Wait for FOLLOW_REMOTE mode (optional)

Enable "FOLLOW_REMOTE" via the system tab toggle, or:

```bash
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":true}'
```

When enabled, all user touch is blocked, a faint yellow edge glow appears, and the app auto-navigates to the relevant screen for each API call. A red STOP button exits the mode.

---

# PLATFORMS

## ANDROID

Requires ADB (Android Debug Bridge) over USB or TCP/IP.

### Connection

```bash
# Check connected devices
adb devices -l

# If device is over TCP/IP
adb connect <IP>:5555

# Retrieve device IP (for the API server)
export APP_IP=$(adb shell ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
echo "App IP: $APP_IP"
```

### Build & Install

```bash
cd radiokit-app
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Launch

```bash
adb shell am force-stop com.rambros3d.radiokit
adb shell am start -n com.rambros3d.radiokit/.MainActivity
```

### View Logs

```bash
# All RadioKit logs
adb logcat -v time | grep -iE "radiokit|flutter"

# Clear log buffer first
adb logcat -c
```

### File Management

```bash
# Pull files from app data
adb shell run-as com.rambros3d.radiokit cat /data/data/com.rambros3d.radiokit/app_flutter/settings.json
```

---

## LINUX

The app runs as a native Linux desktop application.

### Build & Install

```bash
cd radiokit-app
flutter build linux --debug
```

### Launch

```bash
# Direct execution
./build/linux/x64/debug/bundle/radiokit

# Or via Flutter
flutter run -d linux
```

The app will listen on `0.0.0.0:7007` (all interfaces). Retrieve the local IP:

```bash
export APP_IP=$(hostname -I | awk '{print $1}')
echo "App IP: $APP_IP"
```

### Headless Mode

On Linux, the app runs as a normal window. For CI/automation, wrap with `xvfb-run`:

```bash
xvfb-run ./build/linux/x64/debug/bundle/radiokit &
sleep 5  # wait for startup
```

### Logs

```bash
# stdout contains debug prints; redirect to file
./build/linux/x64/debug/bundle/radiokit > /tmp/radiokit.log 2>&1 &
tail -f /tmp/radiokit.log
```

---

# MICROCONTROLLERS

## ESP32 (ESP32-S3)

### Build & Flash

```bash
cd rk-arduino/examples/<EXAMPLE_DIR>
pio run -t upload --upload-port /dev/ttyACM0
```

Common ports: `/dev/ttyACM0`, `/dev/ttyUSB0`.

### Verify Boot

Read serial output after reset to confirm the firmware is alive:

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
- `BLE: Starting advertising...` (for BLE examples)
- `FS: mounted, total=..., used=...` (for filesystem examples)
- `RadioKit: System ready`

The ESP32 advertises as `RK_<config.name>` (e.g., `RK_FS LED`).

### BLE Scan & Connect (from app)

```bash
# Start scan
curl -s -X POST http://$APP_IP:7007/api/pair/scan \
    -H 'Content-Type: application/json' \
    -d '{"type":"ble"}'

# Wait 5-10s for discovery
sleep 8

# List discovered devices
curl -s http://$APP_IP:7007/api/pair/devices

# Connect to specific device
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<MAC>","type":"ble"}'
```

### Verify Connection

```bash
sleep 8  # wait for FS detection (async, ~5s)
curl -s http://$APP_IP:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'connected: {d[\"connected\"]}')
print(f'hasFs: {d[\"device\"][\"hasFs\"]}')
print(f'latency: {d[\"latencyMs\"]}ms')
print(f'rssi: {d[\"rssi\"]}')
"
```

### Widget Control (LED test)

Toggle widgets via `PUT /api/widgets/<id>`:

```bash
# ON
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'

# OFF
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[0]}'
```

> **Note:** Uses `{"values": [<int>]}` (array), NOT `{"value": <int>}`.

Read widget state:

```bash
curl -s http://$APP_IP:7007/api/widgets/0
```

### Filesystem (if applicable)

```bash
# Info
curl -s "http://$APP_IP:7007/api/fs/info"

# List directory
curl -s "http://$APP_IP:7007/api/fs/list?path=/"

# Read file (returns base64-encoded data)
curl -s "http://$APP_IP:7007/api/fs/read?path=/demo/README.txt"

# Create directory
curl -s -X POST http://$APP_IP:7007/api/fs/mkdir \
    -H 'Content-Type: application/json' \
    -d '{"path":"/test_dir"}'

# Write file
curl -s -X POST http://$APP_IP:7007/api/fs/write \
    -H 'Content-Type: application/json' \
    -d '{"path":"/test_dir/hello.txt","data":"SGVsbG8="}'

# Delete
curl -s -X POST http://$APP_IP:7007/api/fs/delete \
    -H 'Content-Type: application/json' \
    -d '{"path":"/test_dir/hello.txt"}'
```

---

# Common Test Operations

These sections work identically across all platforms.

### Console Log

```bash
# Get all console entries (diagnostic messages from device)
curl -s http://$APP_IP:7007/api/console

# Clear console
curl -s -X DELETE http://$APP_IP:7007/api/console
```

### Print Stream (0xEE) Test

The print stream transmits `RadioKit.print/println/printf` messages from the MCU to the app as 0xEE-framed packets over the active transport. Messages appear in the console with `"level":"print"` and are styled in cyan with a `[PRINT]` prefix.

#### Verification procedure

1. **Build firmware** with `RadioKit.print()` calls (all boot/status/auth messages are dual-printed alongside `Serial.print`)
2. **Flash** to ESP32
3. **Launch app** and connect via BLE, WiFi, or Serial
4. **Check console** for `"level":"print"` entries:

```bash
# Get console entries and filter for print messages
curl -s http://$APP_IP:7007/api/console | python3 -c "
import json, sys
data = json.load(sys.stdin)
entries = data.get('entries', data) if isinstance(data, dict) else data
print(f'Total console entries: {len(entries)}')
for entry in entries:
    msg = entry.get('message', str(entry))
    level = entry.get('level', '')
    if level == 'print':
        print(f'[PRINT] {msg.rstrip()}')
"
```

#### Expected output (BLE test)

When connected via BLE to a device with the print stream enabled, the console should show `"level":"print"` entries like:

```
BLE: MTU negotiated to 498
BLE: Widget char subscribed (subValue=1)
BLE: FS char subscribed (subValue=1)
BLE: OTA char subscribed (subValue=1)
BLE: Settings char subscribed (subValue=1)
BLE: Print char subscribed (subValue=1)
DEVICE_INFO: Sending name='WiFi_Cloud_Switch' uid='<uid>'
```

#### What messages are included

All messages in the firmware that have `RadioKit.print/println/printf` calls are transmitted as 0xEE frames:

| Category | Examples |
|----------|----------|
| Boot | `BOOT: Pending erase flag=...`, `BOOT: Erasing NVS config...`, `BOOT: Erase complete — rebooting...` |
| Transport | `BLE: Initializing stack...`, `BLE: Client connected...`, `WiFi: STA connected...`, `Cloud: Connected to...` |
| Auth | `NVS: Device authentication successful — full access`, `RK: Rejected CMD 0x... — not authenticated` |
| OTA | `OTA: Update.begin failed`, `OTA: Write error`, `OTA: Complete — rebooting...` |
| NVS | `NVS: Raw write key='...' = ...`, `NVS: Config updated and committed` |
| Debug (verbose) | `[DBG] shadow MISMATCH for widget`, `RK: Dispatching CMD...` (via `RK_DEBUG_PRINT` macro) |

#### Transport-internal messages (Serial-only)

These messages are NOT sent via the print stream to avoid feedback loops and buffer spam:

**BLE sendPacket error paths** (would cause recursive buffer re-entry):
- `BLE: Cannot send (not connected)`
- `BLE: Cannot send (no char for protocol...)`
- `BLE: sendPacket timeout / aborted / notify failed`

**Cloud reconnect loop** (would flood the 256-byte print buffer):
- `Cloud: Timeout — no packets for 15s, disconnecting`
- `Cloud: Reconnecting (backoff=%us)...`
- `Cloud: Disconnected from relay`

They remain visible on the hardware Serial monitor but do not enter the app console.

#### Debug log level

The `RK_DEBUG_PRINT` macro (enabled when `RK_DEBUG_VERBOSE=1`) also transmits debug messages via the print stream, prefixed with `[DBG]`.

### API Log

```bash
# Get all API request log entries
curl -s http://$APP_IP:7007/api/log

# Clear API log
curl -s -X DELETE http://$APP_IP:7007/api/log
```

### WiFi / WebSocket Connection

Connect to a device over WiFi (local WebSocket server on port 5555):

```bash
# Connect directly — the pair bottom sheet has a WiFi tab (USB > BLE > WiFi ordering)
# Enter the ESP32's IP address and port 5555, then tap CONNECT

# Or via the API (if endpoint exists):
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"ws://<ESP32_IP>:5555","type":"wifi"}'
```

The device must be on the same WiFi network and have `-D RADIOKIT_ENABLE_WIFI` in its build flags. The ESP32 advertises via mDNS as `_radiokit._tcp` if STA mode is active.

### Cloud Relay Auth Flow

Connect to the Rust relay server, authenticate with Ed25519 challenge-response, discover and join a remote device.

**Prerequisites:**
- The ESP32 must be flashed with firmware that sets `cloud_url` and `cloud_account` (public key hex)
- The Rust relay must be running on the target server
- ADB port forwarding must be active (`adb forward tcp:7007 tcp:7007`)

**Step 1 — Connect to relay and authenticate:**

```bash
curl -s --max-time 30 -X POST http://127.0.0.1:7007/api/cloud/connect \
  -H 'Content-Type: application/json' \
  -d '{
    "host": "10.0.0.17",
    "port": 9000,
    "account": "<64-char-hex-public-key>",
    "privateKey": "<64-char-hex-private-key>"
  }'
```

Expected response:
```json
{
  "ok": true,
  "host": "10.0.0.17",
  "port": 9000,
  "account": "4b6afa33...",
  "devices": ["WiFi_Cloud_Switch"]
}
```

**Step 2 — Check device list:**

```bash
curl -s http://127.0.0.1:7007/api/cloud/devices
```

Expected response:
```json
{
  "connected": true,
  "host": "10.0.0.17",
  "port": 9000,
  "devices": ["WiFi_Cloud_Switch"]
}
```

**Step 3 — Join a device:**

```bash
curl -s --max-time 20 -X POST http://127.0.0.1:7007/api/cloud/join \
  -H 'Content-Type: application/json' \
  -d '{"device": "WiFi_Cloud_Switch"}'
```

Expected response:
```json
{
  "ok": true,
  "device": "WiFi_Cloud_Switch",
  "host": "10.0.0.17",
  "port": 9000,
  "message": "Connected to WiFi_Cloud_Switch via cloud relay"
}
```

**Step 4 — Verify connection and control widgets:**

```bash
# Check connection status
curl -s http://127.0.0.1:7007/api/connection | python3 -m json.tool

# List widgets
curl -s http://127.0.0.1:7007/api/widgets | python3 -m json.tool

# Toggle a widget (e.g., switch widget to ON)
curl -s -X PUT http://127.0.0.1:7007/api/widgets/0 \
  -H 'Content-Type: application/json' \
  -d '{"values":[1]}'

# Toggle OFF
curl -s -X PUT http://127.0.0.1:7007/api/widgets/0 \
  -H 'Content-Type: application/json' \
  -d '{"values":[0]}'
```

**Step 5 — Disconnect from relay:**

```bash
curl -s -X POST http://127.0.0.1:7007/api/cloud/disconnect
```

**Keypair generation (Python):**

```python
from cryptography.hazmat.primitives.asymmetric import ed25519

private_key = ed25519.Ed25519PrivateKey.generate()
public_key = private_key.public_key()

print(f'Private key hex: {private_key.private_bytes_raw().hex()}')
print(f'Public key hex:  {public_key.public_bytes_raw().hex()}')
```

The public key hex goes into the ESP32's `cloud_account` config. The app uses the private key to sign challenge nonces. Store the private key securely — it cannot be recovered.

**Troubleshooting:**

| Symptom | Likely cause |
|---------|--------------|
| `auth_failed: Signing failed` | Private key doesn't match account (public key) |
| Timeout on connect | Relay not running or host:port unreachable |
| Empty device list | No ESP32 registered with this account, or device hasn't connected to relay yet |
| Join times out | ESP32 is offline, or `cloud_account` in firmware doesn't match the account sent to API |
| `cloud_error: Connection lost` | ESP32 disconnected from relay mid-session |

### Demo Loading

Load a built-in demo (replaces any connected device with a simulated one):

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/demo \
    -H 'Content-Type: application/json' \
    -d '{"demoId":"WIDGETS_DEMO"}'
```

Valid demo IDs: `WIDGETS_DEMO`, `RC_CONTROLLER`, `IOT_DASHBOARD`.

### Designs CRUD

```bash
# List saved designs
curl -s http://$APP_IP:7007/api/designs

# Save a design
curl -s -X POST http://$APP_IP:7007/api/designs \
    -H 'Content-Type: application/json' \
    -d '{"id":"test1","name":"Test Design","jsonContent":"{\"version\":1}"}'

# Delete single design
curl -s -X DELETE http://$APP_IP:7007/api/designs/test1

# Delete all designs
curl -s -X DELETE http://$APP_IP:7007/api/designs
```

### Settings

```bash
# Read all settings
curl -s http://$APP_IP:7007/api/settings

# Update a setting
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"showDemo":true, "enableDevTools":true}'
```

### Disconnect & Cleanup

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect
```

---

# API Reference Summary

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
| POST | `/api/cloud/connect` | Connect to relay, Ed25519 auth, list devices |
| GET | `/api/cloud/devices` | Cached relay connection state + device list |
| POST | `/api/cloud/join` | Join a device through the relay |
| POST | `/api/cloud/disconnect` | Disconnect from relay |
| GET | `/api/session/route` | Current app route (follow-mode / test sync) |

---

# Known Issues and Limitations

### FS Detection over BLE

**Issue:** FS sub-command ACK matching. The MCU responds to `FS_PING (0x0B)` with `FS_PING_ACK (0x8B)`. The app registers a pending completer for `0x0B` but receives `0x8B`.

**Fix** (applied to `device_provider.dart:_handleFsPacket`):
```dart
Completer<ParsedFsPacket>? pending = _pendingFs.remove(packet.subCmd);
if (pending == null) {
  pending = _pendingFs.remove(packet.subCmd & 0x7F);
}
```

**Workaround:** Wait 8-10s after connection before relying on `hasFs`. If still `false`, reconnecting usually triggers successful detection.

### Serial Port Permissions (Linux)

`/dev/ttyACM0` may have group `nobody`. Add your user to `dialout` or use `chmod a+rw`.

### Remote Access Server is Debug-Only

The server auto-starts only in `kDebugMode`. In release mode, enable via:
```bash
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"enableRemoteAccess":true}'
```

### Upload Failures (ESP32)

If `esptool` reports "Lost connection" during upload, retry with a lower baud rate:
```ini
upload_speed = 115200
```
Add to `platformio.ini` `[env]` section.

### USB CDC Serial on ESP32-S3

Boards like LOLIN S3 Mini require `ARDUINO_USB_MODE=1` and `ARDUINO_USB_CDC_ON_BOOT=1` build flags for Serial over USB. Without these, Serial output won't appear over the USB port.

### ADB Device Goes Offline

Android devices connected over TCP/IP may disconnect after idle time. Reconnect with:
```bash
adb kill-server && adb connect <IP>:5555
```

### FOLLOW_REMOTE Mode — Test Usage

**Always enable Follow Mode when starting an automated test, and disable it when the test is complete.**

```bash
# Enable Follow Mode (blocks all touch, auto-navigates on API calls)
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":true}'

# Verify it's active
curl -s http://$APP_IP:7007/api/settings | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'followRemoteAccess: {d[\"followRemoteAccess\"]}')
"
```

When Follow Mode is enabled:
- **All touch input is blocked** — user cannot interact with the app
- The app auto-navigates to the relevant screen for each API call
- A faint yellow edge glow appears as a visual indicator
- A red STOP button (bottom-right) exits the mode

```bash
# Disable Follow Mode after test completes
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":false}'
```

**Screen coverage (route mapping):**

| API path prefix | Navigates to screen |
|----------------|-------------------|
| `/api/pair/` | `/pair` |
| `/api/connection/connect` | `/control` |
| `/api/connection/disconnect` | `/models` |
| `/api/connection/reconnect` | `/models` |
| `/api/connection/demo` | `/control` |
| `/api/pair/` | `/pair` |
| `/api/widgets` | `/control` |
| `/api/fs/` | `/dev-tools/esp32-fs` |
| `/api/ota/` | `/control` |
| `/api/designs` | `/designs` |
| `/api/transport/` | `/debug` |
| `/api/settings` | `/system` |
| `/api/console` | `/system` |
| `/api/log` | `/system` |
| `/api/models` | `/models` |

**Blocking behavior:**
- All screens except `/control` are wrapped in `AbsorbPointer` — touch is fully blocked
- Dialogs (`showDialog`) and bottom sheets (`showModalBottomSheet`) are inside the Navigator's overlay, so they are also blocked
- The `/control` screen remains interactive so the remote client can still control widgets
- The red STOP button and edge glow overlay sit above the `AbsorbPointer` and are always tappable
