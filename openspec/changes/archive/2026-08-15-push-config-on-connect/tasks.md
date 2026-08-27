# Push Config on Connect — Tasks

## 1. Firmware: push config on widget-char subscribe

- [x] 1.1 Add a public method to `RadioKitClass` (e.g. `pushConfigAndVars()`) that builds and sends CONF_DATA + VAR_DATA, reusing `_handleGetConf()` / `_handleGetVars()` bodies (declare in `RadioKitClass.h`, define in `RadioKit.cpp`)
- [x] 1.2 In `RadioKitBLE.cpp`, widget char `onSubscribe` callback: when `subValue != 0`, call `RadioKit.pushConfigAndVars()` (guard unsubscribes)
- [x] 1.3 Build `Filesystem_LED`, `BasicSwitch`, and `FsCommandTest` with pio to confirm the guarded `#if RK_ENABLE_BLE` compile path

## 2. App: remove the fixed startup delay

- [x] 2.1 Remove `await Future.delayed(const Duration(milliseconds: 5000));` from `DeviceProvider.connectToDevice()`
- [x] 2.2 Add push-first support to `_requestConfig()`: for BLE transports, attempt 0 waits a short window (`kPushWaitTimeout`, e.g. 3s) for the pushed CONF_DATA before sending GET_CONF; non-BLE sends GET_CONF immediately as today

## 3. Tests

- [x] 3.1 Add a unit test for the push-first request strategy (BLE waits for push; non-BLE sends GET_CONF immediately) — extract the decision into a testable helper if needed
- [x] 3.2 Run `flutter analyze --fatal-warnings` and `flutter test` in `radiokit-app`

## 4. Hardware verification

- [x] 4.1 Rebuild + flash `Filesystem_LED` (flash erase per AGENTS.md §1.1) and connect the tablet; measure tap-to-usable latency before/after (expect ~5s faster)
- [x] 4.2 Verify the control UI renders and the ACTIVE_LINKS buttons respond immediately after connect without the dead-air window
- [x] 4.3 Verify Serial (or a demo) connection still acquires config immediately with the delay removed

## 5. Docs sync

- [x] 5.1 Update `website/src/content/docs/arduino/protocol.mdx` (or the connect/handshake doc) noting the proactive push on BLE subscribe
- [x] 5.2 Update `AGENTS.md` if it documents the connect handshake or `kConfTimeout`
