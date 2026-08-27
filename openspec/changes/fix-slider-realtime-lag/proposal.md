## Why

The slider-to-brightness control has multi-second lag when dragging on the tablet. Diagnostic testing with minimal firmware (slider → PWM on L1) confirmed:
- Firmware loop: 166K/sec, 3μs update — NOT the bottleneck
- BLE transport: 2ms overhead — NOT the bottleneck
- API path: 46ms total — works perfectly
- Touch path: seconds of delay — the bottleneck is in Flutter's widget callback chain

Root cause: `setInputValue()` calls `_scheduleNotifyListeners()` which defers the `notifyListeners()` to a microtask. This delays the widget state update, causing the visual feedback and subsequent touch events to process stale state.

## What Changes

- **Revert `_scheduleNotifyListeners()` to synchronous `notifyListeners()`** in `DeviceProvider.setInputValue()` — the microtask deferral causes visual lag that outweighs the rebuild savings
- **Keep the `_listEquals` skip optimization** — still valuable to avoid redundant Map copies and BLE writes when value hasn't changed
- **Remove debug instrumentation** from `device_provider.dart` and `device_designer_bridge.dart`

## Capabilities

### New Capabilities

### Modified Capabilities
- `touch-path-optimization`: Revert the microtask batching that caused slider lag; keep the value-change skip optimization

## Impact

- **Files**: `radiokit-app/lib/providers/device_provider.dart`, `radiokit-app/lib/widgets/device_designer_bridge.dart`
- **Behavior**: Slider responds in real-time (<50ms) instead of seconds of lag
- **Risk**: Low — reverting to synchronous notify for the write path only; the incoming notification path still uses microtask batching
