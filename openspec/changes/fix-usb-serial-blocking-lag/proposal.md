## Why

When an ESP32-S3 board (such as the Mikro board) is connected to a host via its native USB-Serial-JTAG port, the hardware CDC IN endpoint stalls if the host is not actively consuming serial output. Because `HWCDC::write()` blocks on a FreeRTOS semaphore timeout (100–250ms per write) when the CDC FIFO is full, any `Serial.print()` or frame transmission blocks the main loop, introducing severe lag that disappears as soon as the USB cable is unplugged. Furthermore, `RadioKitSerial`'s TX ring buffer discards untransmitted bytes during partial writes and triggers recursive blocking diagnostics.

## What Changes

- Set `HWCDC` TX timeout to 0 ms (`setTxTimeoutMs(0)`) on ESP32-S3 native USB to guarantee non-blocking serial writes.
- Gate all internal debug `Serial.printf` / `Serial.print` logging behind `availableForWrite()` and connection checks.
- Prevent `_sendToAllTransports` from flooding `RadioKitSerialInstance` when Serial has no active connection or when BLE/WiFi is the active primary session.
- Fix `_txRing` draining in `RadioKitSerial` so partial frames are not dropped or corrupted.
- Optimize Android `RawUsbSerialService` read polling to prevent `MethodChannel` queue backup.

## Capabilities

### New Capabilities
- `serial-nonblocking-tx`: Non-blocking CDC transmit pipeline, zero-timeout serial stream behavior, and active-transport gated frame dispatching.

### Modified Capabilities
<!-- None -->

## Impact

- `rk-arduino/src/connection/RadioKitSerial.cpp` and `RadioKitSerial.h`
- `rk-arduino/src/RadioKit.cpp`
- `radiokit-app/lib/services/serial_service_raw_usb.dart`
- Real-time command response and loop latency on ESP32-S3 hardware
