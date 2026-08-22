## ADDED Requirements

### Requirement: Non-blocking native USB CDC writes
The firmware SHALL configure native USB CDC interfaces with a transmit timeout of 0 milliseconds (`setTxTimeoutMs(0)`) so write calls never block the main loop on FreeRTOS semaphore waits when endpoint FIFOs are full.

#### Scenario: Host connected with unread CDC endpoint
- **WHEN** the ESP32-S3 is plugged into a USB host that is not reading the serial endpoint
- **THEN** calls to `Serial.print` and `RadioKit.printf` MUST return immediately without blocking the Arduino `loop()`

### Requirement: Active transport frame filtering
`RadioKitClass::_sendToAllTransports` SHALL only enqueue frames to `RadioKitSerialInstance` if `RadioKitSerialInstance` is actively connected or is the primary transport.

#### Scenario: BLE active and USB serial idle
- **WHEN** the primary active connection is BLE and no serial packets have been exchanged with the USB serial port
- **THEN** widget updates and prints MUST NOT overflow the serial TX ring buffer

### Requirement: Atomic TX ring buffer draining
`RadioKitSerialTransport::update` SHALL only advance the ring buffer tail (`_txTail`) and decrement `_txCount` when the full frame length has been successfully written to the stream.

#### Scenario: Stream buffer has insufficient space for complete frame
- **WHEN** `availableForWrite()` is less than `frame.len`
- **THEN** `RadioKitSerialTransport` MUST retain the frame in `_txRing` for the next update iteration without discarding remaining bytes

### Requirement: Non-blocking Android USB read polling
The Android companion app's `RawUsbSerialService` SHALL avoid queuing overlapping blocking read requests over Flutter's `MethodChannel`.

#### Scenario: USB port idle under Android connection
- **WHEN** no serial bytes arrive from the USB device
- **THEN** background polling MUST NOT accumulate blocking platform channel requests that delay UI write commands
