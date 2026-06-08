# Linux Serial Hardware Testing — Progress

> Last updated: 2026-06-08

---

## Overview

Testing the RadioKit Flutter Linux debug app (built at `flutter-app/build/linux/x64/debug/bundle/radiokit`) with an ESP32-S3 (LOLIN S3 Mini) connected via USB CDC Serial at `/dev/ttyACM0`. The test uses the `Filesystem_LED` example modified to use **Serial transport** instead of BLE, with full filesystem (LittleFS) support and a slide switch + LED widget.

---

## Test Setup

| Component | Detail |
|-----------|--------|
| **MCU** | ESP32-S3 (LOLIN S3 Mini) |
| **Port** | `/dev/ttyACM0` (USB JTAG/serial debug unit, VID:PID=303A:1001) |
| **Firmware** | `arduino-library/examples/Filesystem_LED/` (modified) |
| **App** | `flutter-app/build/linux/x64/debug/bundle/radiokit` (Flutter Linux debug) |
| **API** | `http://127.0.0.1:7007/api` (shelf HTTP server in debug mode) |
| **Display** | `xvfb-run` for headless CI/server environments |

### Firmware Changes Made

The `Filesystem_LED` example was modified from BLE → Serial transport:

1. **`Filesystem_LED.cpp`:**
   - `Serial.begin(115200)` (was 115200 originally, bumped to 1000000 then back to 115200 for reliability)
   - Added `delay(2000)` after `Serial.begin()` to allow USB CDC enumeration (matching `BasicSwitch` pattern)
   - Comment updated from "BLE transport" to "USB Serial transport"

2. **`RADIOKIT.h`:**
   - JSON config `transport`: changed from `"BLE"` to `"SERIAL"`
   - `RadioKit.config.baudrate = 115200`
   - `RadioKit.startBLE()` → `RadioKit.startSerial(Serial)`

3. **`platformio.ini`:**
   - No changes needed (already has `-D ARDUINO_USB_MODE=1` and `-D ARDUINO_USB_CDC_ON_BOOT=1`)

---

## Test Results

### ✅ 1. Firmware Build & Flash

| Step | Status | Duration |
|------|--------|----------|
| `pio run` (build) | ✅ Success | ~18s |
| `pio run -t upload` (flash) | ✅ Success | ~16s |

### ✅ 2. Flutter Linux App Build

| Step | Status | Duration |
|------|--------|----------|
| `flutter build linux --debug` | ✅ Success | ~4min |
| `libsecret-devel` dependency | ✅ Installed via `dnf` |
| `xorg-x11-server-Xvfb` | ✅ Installed for headless operation |

The app HTTP server auto-starts on `0.0.0.0:7007` in `kDebugMode`. Responds:

```json
{"version":"1.0.0","uptime":0,"port":7007,"localIp":"10.0.0.17","platform":"linux","debug":true}
```

### ✅ 3. Serial Port Enumeration

The Flutter app's `LinuxSerialService` successfully lists `/dev/ttyACM0`:

```json
{"devices":[{"id":"/dev/ttyACM0","name":"USB JTAG/serial debug unit - 10:20:BA:2F:91:1C (Espressif)","type":"serial","rssi":0}]}
```

### ✅ 4. Protocol Handshake (Python — Verified)

The ESP32 firmware correctly responds to the RadioKit GET_CONF protocol handshake over USB Serial at 115200 baud. Tested via Python `pyserial`:

- `GET_CONF` sent → `CONF_DATA` received (78 bytes)
- Response includes device name "OTA_Persist_Test" and description
- Boot output shows: `FS: mounted, total=1441792, used=16384`
- LittleFS seeded with `/demo/README.txt` on first boot
- Firmware stable and responsive

**Confirmed working at all DTR states:**
| DTR Configuration | Result |
|-------------------|--------|
| `dtr=None` (no DTR) | ✅ Handshake works immediately |
| DTR asserted → set low with 3s wait | ✅ Handshake works after boot delay |

### ❌ 5. Linux App Serial Handshake (Blocking)

The Flutter app opens the serial port and sends `GET_CONF`, but gets **no response** after 3 attempts (3× timeout).

**Root cause identified:** `flutter_libserialport`'s `SerialPort.openReadWrite()` asserts **DTR** when opening the port. The ESP32-S3's USB CDC interprets DTR assertion as a chip reset signal (`rst:0x15 USB_UART_CHIP_RESET`), rebooting the firmware mid-handshake.

**Evidence chain:**
1. Python opens with `dtr=None` → GPIO 40 LED can be toggled, protocol works
2. Python opens normally (DTR asserted) → ESP32 reboots, bootloader output appears
3. Python opens with DTR → sets DTR low immediately → waits 3s → handshake works
4. Flutter opens → DTR pulse resets ESP32 → GET_CONF sent before ESP32 boots → timeout

**Fix applied but not fully resolved:**

In `serial_service_linux.dart`:
```dart
// Added after port.openReadWrite():
final config = SerialPortConfig()
  ..dtr = 0
  ..rts = 0
  ...;
port.config = config;
// Re-apply DTR/RTS after setFlowControl (belt-and-suspenders)
final adj = port.config;
adj.dtr = 0;
adj.rts = 0;
port.config = adj;
```

The DTR pulse still occurs during `openReadWrite()` before the Dart-level config is applied. The 3.5s delay in `DeviceProvider.connectToDevice()` should handle the boot time, but something deeper prevents the handshake from completing through `flutter_libserialport`.

### ❌ 6. Widget Control (Deferred)

Blocked by handshake failure. Once connected, the test would:
- Toggle `slide_switch_1` via `PUT /api/widgets/0`
- Verify GPIO 40 LED state change

### ❌ 7. Filesystem Operations (Deferred)

Blocked by handshake failure. Once connected, the test would:
- `GET /api/fs/list /` — list root directory
- `GET /api/fs/read /demo/README.txt` — read seed file
- `POST /api/fs/write` — create test files
- `POST /api/fs/delete` — delete test files

---

## Known Issues

### DTR Reset on ESP32-S3 USB CDC (Critical)

**Problem:** `flutter_libserialport` (`v0.6.0`) asserts DTR when `openReadWrite()` is called. The ESP32-S3 ROM bootloader interprets DTR assertion as a chip reset. This is standard behavior for ESP32 USB CDC/JTAG ports.

**Potential fixes (ordered by feasibility):**

| Fix | Effort | Description |
|-----|--------|-------------|
| `-D USB_CDC_IGNORE_DTR` | Low | Add to firmware `build_flags` in `platformio.ini`. Tells the ESP32 Arduino core to ignore DTR changes. |
| Open port without DTR in C | Medium | Modify the libserialport C library or use `fcntl` + `TIOCMSET` to open without asserting DTR. |
| Hardware capacitor | Low | Add ~10µF capacitor between DTR (GPIO 0) and EN on the ESP32 board. |

### Recommended Fix

Add `-D USB_CDC_IGNORE_DTR` to `arduino-library/examples/Filesystem_LED/platformio.ini`:

```ini
build_flags =
    -D ARDUINO_USB_MODE=1
    -D ARDUINO_USB_CDC_ON_BOOT=1
    -D USB_CDC_IGNORE_DTR
    ...
```

This prevents the ESP32 Arduino core from resetting when DTR toggles, allowing `flutter_libserialport` to connect without timing issues.

---

## Files Modified for Linux Test

| File | Change |
|------|--------|
| `arduino-library/examples/Filesystem_LED/platformio.ini` | ⏳ Add `-D USB_CDC_IGNORE_DTR` (pending) |
| `arduino-library/examples/Filesystem_LED/Filesystem_LED.cpp` | Serial at 115200, delay(2000), comment update |
| `arduino-library/examples/Filesystem_LED/RADIOKIT.h` | `startSerial(Serial)`, baudrate=115200, transport=SERIAL |
| `flutter-app/lib/services/serial_service_linux.dart` | DTR=0,RTS=0 fix after port open (partial) |
| `flutter-app/build/linux/x64/debug/bundle/radiokit` | Rebuilt with DTR fix |

---

## Next Steps to Continue Testing

1. Add `-D USB_CDC_IGNORE_DTR` to firmware `platformio.ini`, rebuild & reflash
2. Rebuild Flutter Linux app with the DTR fix
3. Clear app history (`~/.local/share/com.radiokit.app/shared_prefs/`)
4. Launch app → scan serial → connect at 115200 → verify handshake
5. Test widget control: `PUT /api/widgets/0 {"values": [1]}`
6. Test FS operations: list, read, write, delete
7. Test follow mode: enable via settings, verify API calls trigger navigation
