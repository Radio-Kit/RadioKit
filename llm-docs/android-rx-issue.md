# Android Serial — ESP32-S3 USB Serial/JTAG

> Status: **RX works via FSC. TX broken. Protocol handshake times out.**
> Last updated: 2026-06-19

## Problem

On Android, ESP32-S3 native USB Serial/JTAG:
- **RX works** via FSC (mik3y) — data flows from device to host
- **TX fails** — `write()` returns `false` on all packets, preventing host-to-device communication
- Protocol handshake (GET_CONF → CONF_DATA) never completes because GET_CONF never reaches the device

On Linux, the exact same hardware works perfectly.

## Test Environment

| Component | Detail |
|-----------|--------|
| Android tablet | Lenovo TB373FU (Android 14) |
| Connection | Wireless ADB (`10.0.0.6:5555`) |
| ESP32-S3 | WEMOS LOLIN S3 Mini |
| USB interface | Native USB Serial/JTAG (NOT TinyUSB CDC) |
| USB descriptor | `Espressif USB JTAG/serial debug unit` |
| Baud rate | 1000000 |
| FSC source | `flutter_serial_communication: ^0.2.8` (mik3y) |
| Firmware | BasicSwitch with `ARDUINO_USB_MODE=1` |

## Board Finding: LOLIN S3 Mini USB Architecture

The LOLIN S3 Mini's USB port is hardwired to the native USB Serial/JTAG controller. Setting `ARDUINO_USB_MODE=0` switches the PHY to TinyUSB CDC ACM, but TinyUSB doesn't work on Android (ignores `SET_CONTROL_LINE_STATE`).

```
IFACE 0: class=2(CDC Control)  — INT EP 0x82
IFACE 1: class=10(CDC Data)    — BULK EP 0x01 OUT, BULK EP 0x81 IN
IFACE 2: class=255(Vendor)     — BULK EP 0x02 OUT, BULK EP 0x83 IN
```

## Key Findings

### Why Linux Works But Android Doesn't

| OS | Driver | Behavior on STALL |
|----|--------|-------------------|
| Linux | `cdc_acm` kernel driver | Automatic STALL clearing, data toggle managed transparently |
| Android | `UsbDeviceConnection.bulkTransfer()` | Returns -1 on STALL. Manual `clearHalt()` required. Host-side data toggle not resettable. |

### Why FSC RX Works But TX Doesn't

- **RX (EP 0x81 IN)**: ESP32-S3 native controller actively sends data on the bulk IN endpoint. Android reads it successfully.
- **TX (EP 0x01 OUT)**: `bulkTransfer` on the OUT endpoint returns -1 immediately (STALL, not timeout). The native controller's OUT endpoint is not properly accepting data from the Android host.

### Root Cause

The ESP32-S3 native USB Serial/JTAG controller's bulk OUT endpoint STALLs on Android. The `bulkTransfer()` call returns -1 immediately — this is a USB protocol-level rejection, not a timeout. The false disconnect event from mik3y's connection listener (~7s) was a red herring; removing it didn't fix writes.

## Fix History (What Was Tried)

| Fix | What | Result |
|-----|------|--------|
| TinyUSB CDC tuning | Buffer sizes, `tud_cdc_connected` guard | Ineffective — TinyUSB not active on this board |
| Deep recovery | `releaseInterface`/`claimInterface` + `clearHalt` | Still no RX — bulkTransfer still -1 |
| Firmware keepalive | Null byte every 250ms | Still no RX |
| IFACE 0 claiming | Claim CDC Control interface alongside data | Flasher works, serial transport still broken |
| UsbRequest I/O | Replaced `bulkTransfer` with `UsbRequest.queue()` | Works with TinyUSB, STALLs on native controller |
| TinyUSB PHY switch | `ARDUINO_USB_MODE=0` | TinyUSB ignores Android control transfers — reverted |
| `while(!Serial)` DTR wait | Wait for host DTR before sending | Works on Linux, no effect on Android |
| Dart setDTR/setRTS | FFI calls after port open | FFI no-ops on Android — reverted |
| **FSC routing** | Android through mik3y Java library | **RX works!** TX still broken |
| FSC connection listener removal | Remove false disconnect subscription | Didn't fix writes — damage is on Java side |
| FSC at 115200 baud | Lower baud rate | Same result — baud rate doesn't affect endpoint behavior |

## Current Architecture

| Component | Android | Desktop |
|-----------|---------|---------|
| Serial transport | FSC (mik3y) | flserial |
| Flasher | flserial | flserial |

**Why flasher works but serial transport doesn't**: Flasher enters bootloader mode via DTR/RTS toggle. In bootloader mode, the ROM bootloader uses a simple request/response USB protocol — not CDC ACM. The bulk OUT endpoint works fine in bootloader mode.

## FSC vs flserial Comparison

| Aspect | FSC (mik3y) | flserial |
|--------|-------------|----------|
| RX | Works (64-byte chunks) | Zero bytes |
| TX | write() returns false | TX appears to work (no error) |
| Control transfer timeout | 5000ms | 2000ms |
| DTR/RTS | Java MethodChannel → USB controlTransfer | Dart FFI → termios (no-op on Android) |
| Connection listener | Removed (false disconnect at ~7s) | N/A |

## Test Results Summary

| Round | Fixes | TX | RX | Platform |
|-------|-------|----|----|----------|
| 1-4 | Baseline + TinyUSB + deep recovery | OK | Zero | Android |
| 5-8 | UsbRequest + TinyUSB PHY + native | OK | Failed/Zero | Android |
| 9-10 | Linux DTR test | OK | CONF_DATA | Linux |
| 11-13 | IFACE 0 + bulkTransfer + Dart DTR | OK | Zero | Android |
| **14** | **FSC routing** | **write() false** | **64-byte chunks** | **Android** |
| 15 | Connection listener removal | write() false | Zero | Android |

## What Was Proven

| Component | MODE=0 (TinyUSB) | MODE=1 (Native USB) |
|-----------|-------------------|---------------------|
| USB enumeration | `vid=0x303A pid=0x8167` | `vid=0x303A pid=0x1001` |
| TX | GET_CONF sent | write() returns false |
| RX | Zero bytes | **Works with FSC** |
| Flasher | N/A | Works (bootloader mode) |
| Protocol handshake | Timeout | Timeout — device never receives GET_CONF |

## Current State

| Component | Status |
|-----------|--------|
| Firmware | `ARDUINO_USB_MODE=1` (native USB) |
| IFACE 0 claiming | Applied in FlserialPlugin.kt |
| bulkTransfer reader | Applied in FlserialPlugin.kt |
| serial_service_native.dart | Android → FSC, desktop → flserial |
| serial_service_fsc.dart | Active on Android — connection listener removed |
| Android RX | **Works with FSC** |
| Android TX | **Broken** — write() returns false |
| Linux connectivity | Works |
| Flasher | Works |

## Potential Next Steps

1. **Investigate FSC write() failure** — Check if mik3y's `CdcAcmSerialDriver.java` selects the wrong endpoint, or if ESP32-S3 native USB Serial/JTAG requires a specific control transfer sequence before OUT endpoint becomes writable.

2. **Add explicit DTR assertion via MethodChannel** — Verify FSC Dart `setDTR(true)` actually sends `SET_CONTROL_LINE_STATE` with DTR bit set. Add logging to Java side.

3. **Test with external USB-UART bridge** — Connect via CP2102/CH340 instead of native USB Serial/JTAG to confirm whether the issue is specific to the native controller.

## Appendix: Key Source Files

| File | Path | Role |
|------|------|------|
| FlserialPlugin.kt | `~/.pub-cache/git/flserial-e1156.../android/.../FlserialPlugin.kt` | Kotlin plugin with IFACE 0 claiming + bulkTransfer reader |
| serial_service_flserial.dart | `radiokit-app/lib/services/serial_service_flserial.dart` | Flutter serial transport (flserial) |
| serial_service_fsc.dart | `radiokit-app/lib/services/serial_service_fsc.dart` | Flutter serial transport (FSC/mik3y) — active on Android |
| serial_service_native.dart | `radiokit-app/lib/services/serial_service_native.dart` | Platform dispatcher |
| protocol_service.dart | `radiokit-app/lib/services/protocol_service.dart` | Packet framing, parsing |
| device_provider.dart | `radiokit-app/lib/providers/device_provider.dart` | Connection state machine |
| RadioKitSerial.cpp | `rk-arduino/src/connection/RadioKitSerial.cpp` | Device-side serial transport |
| CdcAcmSerialDriver.java | `ref/usb-serial-for-android/.../CdcAcmSerialDriver.java` | mik3y's Java CDC ACM driver |
