# Multi-Device Test Manual

## Overview

The multi-device feature allows the RadioKit app to maintain simultaneous connections to multiple RadioKit devices. Each connected device gets its own `DeviceProvider` with its own transport, widget state, auth, FS, and console log. The "focused" device is the one whose control screen is currently active.

### Architecture

```
┌──────────────┐   HTTP :7007   ┌──────────────────────┐   transport   ┌────────────┐
│  Host PC     │ ─────────────→ │  RadioKit App         │ ←─────────── │  Device A  │
│  (curl/pio)  │                │  MultiDeviceProvider  │   BLE/Ser    │  (ESP32 #1)│
└──────────────┘                │  ├─ DeviceProvider A  │              └────────────┘
                                │  ├─ DeviceProvider B  │   transport   ┌────────────┐
                                │  └─ focusedDevice ──→ │ ←─────────── │  Device B  │
                                │     (primaryDevice)   │   BLE/WiFi   │  (ESP32 #2)│
                                └──────────────────────┘              └────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `MultiDeviceProvider` | `lib/providers/multi_device_provider.dart` | Manages collection of DeviceProviders. Each connected device gets its own provider instance with independent transport, widgets, auth, FS, and console. |
| `RemoteAccessProvider` | `lib/providers/remote_access_provider.dart` | Wraps MultiDeviceProvider. Exposes `_activeDevice` (primary/focused) for the Remote Access API. API endpoints operate on the focused device. |
| `RemoteAccessService` | `lib/services/remote_access_service.dart` | HTTP REST API server on port 7007. Routes widget, FS, transport, and settings commands to the active (focused) DeviceProvider. |

### MultiDeviceProvider API

| Method | Description |
|--------|-------------|
| `connectDevice(device, transport)` | Creates a new DeviceProvider with its own transport. Returns existing provider if device ID is already connected. |
| `connectDemo(demoId)` | Creates a DemoFsTransport-based DeviceProvider for a built-in demo. |
| `disconnectDevice(deviceId)` | Disconnects and disposes a specific device. Clears focus if it was focused. |
| `disconnectAll()` | Disconnects all devices. |
| `setFocusedDevice(deviceId)` | Sets which device is "active" (whose control screen is shown). Pass null when leaving control screen. |
| `reconnectDevice(deviceId)` | Reconnects a previously connected device. |
| `primaryDevice` | Backward-compatible getter: returns focused device, or first connected device. |
| `getDevice(deviceId)` | Get the DeviceProvider for a specific device. |
| `deviceIds` | Read-only list of all connected device IDs. |
| `devices` | Read-only list of all connected DeviceProviders. |
| `focusedDevice` | The currently focused DeviceProvider (control screen), or null. |

### API vs UI Multi-Device

**Important**: The Remote Access API (`POST /api/connection/connect`) always targets the `primaryDevice` (the focused or first-connected device). It does **not** add a second device to the MultiDeviceProvider collection.

True multi-device connections are initiated through the **UI**:
- The pair sheet's "CONNECT ANOTHER" button calls `MultiDeviceProvider.connectDevice()` directly
- Tapping a device card in the Models tab focuses that device (`setFocusedDevice`)
- The control screen for the focused device is shown

The API operates on whatever device is currently focused. There is no API endpoint to switch device focus — focus switching is UI-driven only.

---

## Prerequisites

| Dependency | Purpose |
|-----------|---------|
| `curl` | HTTP requests to the Remote Access API |
| `python3` | JSON parsing, serial output reading |
| PlatformIO (`pio`) | Building and flashing MCU firmware |
| Flutter SDK | Building the app |
| ADB | Android device management |
| 2x ESP32-S3 boards | Test targets (e.g., LOLIN S3 Mini) |
| Android tablet or phone | Running the RadioKit app |

---

## Setup

### 1. Flash firmware to both ESP32-S3 boards

Use two different firmware examples to test cross-device communication:

**Device A — Filesystem_LED (BLE + FS):**

```bash
cd rk-arduino/examples/Filesystem_LED
pio run -t upload --upload-port /dev/ttyACM0
```

Config: BLE name "FS LED", password "1234", single RockerSwitch widget, LittleFS enabled.

**Device B — WiFiCloudSwitch (BLE + WiFi + Cloud):**

```bash
cd rk-arduino/examples/WiFiCloudSwitch
pio run -t upload --upload-port /dev/ttyACM1
```

Config: BLE name "WiFi_Cloud_Switch", RockerSwitch + LED widgets, WiFi + Cloud relay enabled.

### 2. Verify boot on both devices

```bash
python3 -c "
import serial, time
for port in ['/dev/ttyACM0', '/dev/ttyACM1']:
    s = serial.Serial(port, 115200)
    s.dtr = False; s.rts = True; time.sleep(0.1); s.rts = False; time.sleep(3)
    data = s.read(8192).decode('utf-8', errors='replace')
    lines = [l for l in data.split('\n') if l.strip()]
    print(f'=== {port} ({len(lines)} lines) ===')
    for l in lines[:15]: print(l)
    s.close()
"
```

Expected: ESP32 #1 shows `BLE: Starting advertising...` and `FS: mounted`. ESP32 #2 shows BLE + WiFi init messages.

### 3. Build and install the Flutter app

```bash
cd radiokit-app
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### 4. Launch and enable Remote Access

```bash
adb shell am force-stop com.rambros3d.radiokit
adb shell am start -n com.rambros3d.radiokit/.MainActivity
adb forward tcp:7007 tcp:7007
```

Wait for the HTTP server:

```bash
APP_IP="127.0.0.1"
for i in $(seq 1 15); do
    curl -s --connect-timeout 2 http://$APP_IP:7007/api/status > /dev/null 2>&1 \
        && echo "Server up" && break
    sleep 1
done
```

Enable Follow Remote mode (blocks touch, auto-navigates):

```bash
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":true}'
```

---

## Test Cases

### TC-1: Single Device Connect (Baseline)

Verify the basic single-device connection still works before testing multi-device.

**Step 1 — Scan for BLE devices:**

```bash
curl -s -X POST http://$APP_IP:7007/api/pair/scan \
    -H 'Content-Type: application/json' \
    -d '{"type":"ble"}'
sleep 8
curl -s http://$APP_IP:7007/api/pair/devices
```

Expected: Both "FS LED" and "WiFi_Cloud_Switch" appear in the device list.

**Step 2 — Connect to Device A (FS LED):**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<FS_LED_MAC>","type":"ble"}'
sleep 8
curl -s http://$APP_IP:7007/api/connection | python3 -m json.tool
```

Expected: `connected: true`, device name "FS LED", `hasFs: true`.

**Step 3 — Verify single-device widget control:**

```bash
curl -s http://$APP_IP:7007/api/widgets | python3 -c "
import json, sys
d = json.load(sys.stdin)
for w in d['widgets']:
    print(f\"  {w['widgetId']}: {w['type']} ({w['name']})\")
"
```

Expected: Shows `slide_switch_1` (RockerSwitch).

**Step 4 — Toggle widget:**

```bash
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'
sleep 1
curl -s http://$APP_IP:7007/api/widgets/0 | python3 -m json.tool
```

Expected: Widget state shows `value: 1`.

**Step 5 — Disconnect:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect
```

---

### TC-2: Multi-Device Connect (UI-Driven)

Connect to both devices simultaneously via the UI. The API cannot add a second device — use the pair sheet's "CONNECT ANOTHER" button.

**Step 1 — Connect to Device A (FS LED) via API:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<FS_LED_MAC>","type":"ble"}'
sleep 8
```

**Step 2 — Connect to Device B via UI:**

On the Android tablet:
1. Navigate to the Models tab
2. Tap "PAIR NEW" to open the pair sheet
3. Tap "CONNECT ANOTHER" (or scan and tap CONNECT on Device B)
4. Wait for connection to establish

This calls `MultiDeviceProvider.connectDevice()` directly, adding Device B to the collection alongside Device A.

**Step 3 — Verify both devices appear in models:**

```bash
curl -s http://$APP_IP:7007/api/models | python3 -c "
import json, sys
d = json.load(sys.stdin)
for m in d['models']:
    print(f\"  {m['id']}: {m['name']} ({m['type']})\")
print(f\"Total: {len(d['models'])} models\")
"
```

Expected: Both "FS LED" and "WiFi_Cloud_Switch" appear.

**Step 4 — Verify the active device state:**

```bash
curl -s http://$APP_IP:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"connected: {d['connected']}\")
dev = d.get('device')
if dev:
    print(f\"device: {dev['name']}\")
    print(f\"hasFs: {dev.get('hasFs')}\")
print(f\"widgets: {len(d.get('configJson', {}).get('widgets', []))}\")
"
```

Expected: Shows the currently focused device's state. `primaryDevice` returns the focused device or the first connected one.

---

### TC-3: Demo + Real Device Coexistence

Load a demo while a real device is connected. This definitely creates two separate DeviceProvider instances (demo uses `DemoFsTransport`).

**Step 1 — Connect to a real device:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<FS_LED_MAC>","type":"ble"}'
sleep 8
```

**Step 2 — Load a demo:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/demo \
    -H 'Content-Type: application/json' \
    -d '{"demoId":"WIDGETS_DEMO"}'
sleep 3
```

**Step 3 — Verify demo is loaded:**

```bash
curl -s http://$APP_IP:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
dev = d.get('device', {})
print(f\"connected: {d['connected']}\")
print(f\"device: {dev.get('name')}\")
print(f\"widgets: {len(d.get('configJson', {}).get('widgets', []))}\")
"
```

Expected: Shows demo with 12 widgets.

**Step 4 — Control demo widgets:**

```bash
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'
sleep 1
curl -s http://$APP_IP:7007/api/widgets/0 | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"Widget {d['widgetId']}: value={d['state'].get('value')}\")
"
```

**Step 5 — Unload demo:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect
```

---

### TC-4: Widget Control on Active Device

Verify widget commands go to the currently focused/active device.

**Step 1 — Ensure Device A (FS LED) is focused, toggle its switch:**

```bash
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'
sleep 1
curl -s http://$APP_IP:7007/api/widgets/0 | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"Widget {d['widgetId']}: value={d['state']['value']}\")
"
```

**Step 2 — Switch focus to Device B via UI (tap its card in Models tab), then toggle its switch:**

```bash
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'
sleep 1
curl -s http://$APP_IP:7007/api/widgets/0 | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"Widget {d['widgetId']} ({d['name']}): value={d['state'].get('value')}\")
"
```

Expected: The widget command goes to whichever device is currently focused. The active device's widgets respond, the other device's widgets are unaffected.

---

### TC-5: Concurrent Widget State Preservation

Verify that Device A's widget state is preserved when Device B is focused and controlled.

**Step 1 — Set Device A's switch to ON:**

```bash
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'
sleep 1
curl -s http://$APP_IP:7007/api/widgets/0 | python3 -c "
import json, sys; d = json.load(sys.stdin); print(f\"A widget: {d['state']['value']}\")
"
```

**Step 2 — Switch focus to Device B, toggle its widget:**

Switch focus via UI, then:

```bash
curl -s -X PUT http://$APP_IP:7007/api/widgets/0 \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}'
```

**Step 3 — Switch focus back to Device A, verify its state is preserved:**

Switch focus via UI, then:

```bash
curl -s http://$APP_IP:7007/api/widgets/0 | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"A widget state preserved: value={d['state']['value']}\")
"
```

Expected: Device A's widget still shows `value: 1` (ON) — its state was not affected by Device B's operations.

---

### TC-6: Filesystem Operations on Active Device

When FS LED is the focused device, FS operations should work. When WiFi_Cloud_Switch is focused (which may not have FS), they should return an error.

**Step 1 — Focus Device A (FS LED) and test FS:**

```bash
curl -s http://$APP_IP:7007/api/fs/info | python3 -m json.tool
curl -s "http://$APP_IP:7007/api/fs/list?path=/" | python3 -m json.tool
```

Expected: FS info shows total/used/free bytes. Directory listing shows root contents.

**Step 2 — Switch focus to Device B via UI and verify FS is unavailable:**

```bash
curl -s http://$APP_IP:7007/api/fs/info
```

Expected: Returns `503` with `error: "not_connected"` or `error: "no_fs"` if the active device doesn't have FS.

---

### TC-7: Device Switch (Transport)

Test switching the active transport without disconnecting.

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/switch \
    -H 'Content-Type: application/json' \
    -d '{"transport":"wifi"}'
sleep 5
curl -s http://$APP_IP:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
dev = d.get('device', {})
print(f\"connected: {d['connected']}\")
print(f\"device: {dev.get('name')}\")
print(f\"type: {dev.get('type')}\")
"
```

Expected: Device switches from BLE to WiFi transport (or returns error if WiFi not available on the device).

---

### TC-8: Disconnect One Device, Keep Other

Disconnect one device while the other remains connected.

**Step 1 — Verify both are connected:**

```bash
curl -s http://$APP_IP:7007/api/models | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"Models: {len(d['models'])}\")
for m in d['models']:
    print(f\"  {m['name']}\")
"
```

**Step 2 — Disconnect Device B (WiFi_Cloud_Switch):**

Switch focus to Device B via UI, then:

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect
```

**Step 3 — Verify Device A (FS LED) is still available:**

```bash
curl -s http://$APP_IP:7007/api/models | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"Models after disconnect: {len(d['models'])}\")
"
```

Expected: At least one model remains in the history. The remaining device can still be controlled.

---

### TC-9: Reconnect a Device

Test reconnecting a device that was previously connected.

**Step 1 — Connect to Device A:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<FS_LED_MAC>","type":"ble"}'
sleep 8
```

**Step 2 — Disconnect:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect
sleep 2
```

**Step 3 — Reconnect:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/reconnect
sleep 8
curl -s http://$APP_IP:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"connected: {d['connected']}\")
dev = d.get('device')
if dev: print(f\"device: {dev['name']}\")
"
```

Expected: Device reconnects successfully and widget state is restored.

---

### TC-10: Console Log Per Device

Each device has its own console log. Verify that console entries from both devices are captured.

```bash
curl -s http://$APP_IP:7007/api/console | python3 -c "
import json, sys
data = json.load(sys.stdin)
entries = data.get('entries', data) if isinstance(data, dict) else data
print(f'Total console entries: {len(entries)}')
for entry in entries[-10:]:
    msg = entry.get('message', str(entry))
    level = entry.get('level', '')
    print(f'  [{level}] {msg[:80]}')
"
```

Expected: Console shows entries from both devices (connection handshakes, widget subscriptions, print stream messages).

---

### TC-11: Auth Dialog with Password-Protected Device

Test authentication flow with a password-protected device.

**Step 1 — Set a password on Device A:**

```bash
curl -s -X POST http://$APP_IP:7007/api/settings/nvs \
    -H 'Content-Type: application/json' \
    -d '{"password":"test123"}'
```

**Step 2 — Disconnect and reconnect:**

```bash
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect
sleep 2
curl -s -X POST http://$APP_IP:7007/api/connection/connect \
    -H 'Content-Type: application/json' \
    -d '{"id":"<FS_LED_MAC>","type":"ble"}'
```

**Step 3 — Authenticate via API (within 60s timeout):**

```bash
curl -s -X POST http://$APP_IP:7007/api/settings/nvs/authenticate \
    -H 'Content-Type: application/json' \
    -d '{"password":"test123"}'
```

Expected: Returns `{"ok": true, "message": "Authenticated successfully"}`.

**Note**: The 60-second auth timeout starts when a password-gated device connects. If not authenticated within 60s, the device disconnects automatically.

---

### TC-12: Settings Per Device

Verify that NVS settings are device-specific.

```bash
# Read NVS from focused device
curl -s http://$APP_IP:7007/api/settings/nvs | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"name: {d.get('name')}\")
print(f\"description: {d.get('description')}\")
print(f\"hasPassword: {d.get('hasPassword')}\")
print(f\"isAuthenticated: {d.get('isAuthenticated')}\")
"
```

---

## Cleanup

```bash
# Disable Follow Mode
curl -s -X PUT http://$APP_IP:7007/api/settings \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":false}'

# Disconnect all
curl -s -X POST http://$APP_IP:7007/api/connection/disconnect

# Clear models (optional)
curl -s -X DELETE http://$APP_IP:7007/api/models
```

---

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Only one device shows in pair scan | ESP32 not advertising, or BLE scanner timeout. Re-scan with `POST /api/pair/scan`. |
| Second connect via API fails | API always targets primaryDevice. Use the UI pair sheet's "CONNECT ANOTHER" button for true multi-device. |
| Widget commands go to wrong device | Focus not set correctly. Ensure the control screen for the target device is active. Tap its card in Models tab. |
| FS operations return 503 | Active device doesn't have FS, or device is not focused. Check `GET /api/connection` for `hasFs`. |
| Auth dialog auto-opens | Device has a password set. Use `POST /api/settings/nvs/authenticate` with the password. 60s timeout applies. |
| Console shows no entries | Console was cleared or device hasn't sent print messages yet. Wait for boot messages. |
| BLE scan finds no devices | ESP32 firmware not compiled with BLE, or radio disabled. Verify serial output shows `BLE: Starting advertising...`. |
| Connection drops intermittently | BLE signal weak (check RSSI in `GET /api/connection`). Move devices closer to the phone/tablet. |
| Device focus cannot be switched via API | Focus switching is UI-driven only. There is no API endpoint for `setFocusedDevice`. |
| Reconnect fails | Device may have been power-cycled. Re-scan and reconnect with the new MAC address. |
