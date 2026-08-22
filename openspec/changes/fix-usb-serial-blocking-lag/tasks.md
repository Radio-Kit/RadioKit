## 1. Firmware Zero-Timeout and Atomic Ring Buffer

- [x] 1.1 Configure `HWCDC` zero-timeout (`setTxTimeoutMs(0)`) in `RadioKitSerialTransport::begin` / `RadioKit::startSerial` on ESP32 targets
- [x] 1.2 Fix `RadioKitSerialTransport::update` to only write and advance `_txTail` when `availableForWrite() >= frame.len`
- [x] 1.3 Gate internal debug print logging and dropped frame diagnostics in `RadioKitSerial.cpp` to avoid blocking writes

## 2. Multi-Transport Routing & Dispatch Optimization

- [x] 2.1 Update `RadioKitClass::_sendToAllTransports` to only forward frames to `RadioKitSerialInstance` when Serial is primary or has an active session
- [x] 2.2 Verify `RadioKit.update()` loop rate remains high (>1000 Hz) even when USB is connected to an unread port

## 3. Companion App Android Polling Protection

- [x] 3.1 Refactor `RawUsbSerialService._startReadPoll` in Flutter to avoid scheduling overlapping blocking MethodChannel calls
- [x] 3.2 Ensure Android USB read timeout is non-blocking or managed sequentially

## 4. Hardware and Remote API Verification

- [x] 4.1 Benchmark BLE command latency via Remote API while `/dev/ttyACM0` is connected and idle
- [x] 4.2 Benchmark BLE command latency via Remote API while `/dev/ttyACM0` is connected and actively monitored
- [x] 4.3 Verify instant recovery and stability during continuous sustained control traffic
