# Spec: BLE TX Optimization

## Requirement: TX Throughput

The firmware must handle 10Hz command traffic without growing lag.

### Acceptance Criteria

1. **Latency**: 5-minute stress test at 10Hz shows <50ms average, 0 commands >100ms
2. **No main loop starvation**: Hazard light blink timing remains 300ms ±1ms under load
3. **Serial monitor text**: Displays in real-time without drops
4. **No feedback loop**: No echo mechanism creates additional traffic

### Constraints

- BLE connection interval: 48ms (Android negotiated)
- MTU: 498 bytes
- TX ring buffer: 8 slots (existing)
- ESP32 dual-core: core 0 (protocol), core 1 (application)

## Requirement: Frame Budget

Total outgoing frames must not exceed BLE capacity (~21 frames/sec at 48ms interval).

### Current Budget

| Source | Frames/sec |
|--------|-----------|
| Firmware ACK | ~10 |
| Firmware VAR_UPDATE | ~6 |
| Firmware SET_INPUT echo | ~3 |
| App VAR_UPDATE | ~10 |
| Telemetry response | ~0.2 |
| **Total** | **~30** |

### Target Budget (after fix)

| Source | Frames/sec |
|--------|-----------|
| Firmware ACK | 0 (removed) |
| Firmware VAR_UPDATE | ~6 |
| Firmware SET_INPUT echo | ~3 |
| App VAR_UPDATE | ~10 |
| Telemetry response | ~0.2 |
| **Total** | **~19** |

19 < 21 → within BLE capacity ✓
