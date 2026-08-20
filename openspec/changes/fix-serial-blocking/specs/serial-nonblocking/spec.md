# Spec: Serial Transport Non-Blocking

## Requirement: No Main Loop Blocking

The serial transport must not block the main loop during packet transmission.

### Acceptance Criteria

1. **sendPacket() latency**: Returns in <100μs (memcpy only, no I/O)
2. **No growing lag**: 5-minute stress test at 10Hz shows stable latency (<50ms avg)
3. **Blink timing preserved**: Hazard light blink remains 300ms ±1ms with USB connected
4. **Dual transport**: BLE + Serial work simultaneously without interference
5. **Debug output**: Serial monitor still shows STATUS lines and events

### Constraints

- ESP32-S3 native USB CDC at 2MHz baud
- USB CDC FIFO: 512 bytes
- Ring buffer: 8 slots × 768 bytes = 6KB max
- Must not break existing serial protocol (0x55, 0xAA, 0xBB, 0xDD, 0xEE framing)
