# Push Config on Connect

## Why

After connecting to a device, it takes several seconds before the control UI and settings surfaces are usable. The root cause is a hardcoded, unconditional `await Future.delayed(Duration(milliseconds: 5000))` in `DeviceProvider.connectToDevice()` (bumped from 3.5s to 5s in `6528dce4`) that sleeps **before** the app even requests the config. Every transport (BLE, Serial, WiFi, Cloud) pays this cost — Serial never needed it at all.

The sleep exists as a blunt "let BLE settle" guard against a race that is not measured anywhere: the BLE transport's `connect()` already completes MTU negotiation + service discovery + notify subscription (GATT is ready), and the firmware is ready as soon as it advertises. The firmware already has a per-characteristic `onSubscribe` callback that today only prints to Serial — the natural hook for a proactive config push.

## What Changes

- **Firmware**: when a BLE client subscribes to the widget characteristic (post-connect, post-MTU), the device immediately pushes `CONF_DATA` + `VAR_DATA` — the same packets it would send in response to `GET_CONF`/`GET_VARS`, via the same generic send path. No new commands, no wire-format changes; the protocol stays transport-agnostic. Other transports (Serial/WiFi/Cloud) keep their existing request/response flow.
- **App**: remove the 5s delay entirely. Fire `GET_CONF` (and device-info/features/pages) immediately after `transport.connect()` for non-BLE transports; for BLE, rely on the device push first with a short fallback window before sending `GET_CONF` (avoids a redundant double send). Add a fast-retry so a dropped first request recovers quickly instead of after the current 8s timeout.

## Capabilities

### New Capabilities

- `config-push-on-connect`: firmware pushes CONF_DATA/VAR_DATA on BLE client subscribe, and the app consumes the pushed config immediately without a fixed startup delay.

### Modified Capabilities

<!-- No existing spec-level requirements change; all additions are new behavior. -->

## Impact

- **Firmware**: `rk-arduino/src/connection/RadioKitBLE.cpp` (widget char `onSubscribe` callback), `rk-arduino/src/RadioKitClass.h` / `RadioKit.cpp` (public method to build+send CONF_DATA/VAR_DATA), `rk-arduino/src/RadioKit.h` if the class declaration lives there.
- **App**: `radiokit-app/lib/providers/device_provider.dart` (remove the 5s sleep; push-first config request with fallback; fast retry), `radiokit-app/lib/models/protocol.dart` (`kConfTimeout` if adjusted).
- **Docs**: `website/src/content/docs/arduino/protocol.mdx` (note the proactive push), AGENTS.md if needed.
- **Testing**: pio build of all examples; app unit tests for the request strategy; hardware verification on the connected tablet + ESP32-S3 measuring connect-to-usable latency.
