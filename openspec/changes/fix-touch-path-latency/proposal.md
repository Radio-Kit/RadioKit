## Why

Touch controls on the RadioKit app develop a multi-second lag after sustained use. The root cause is excessive Flutter rebuild cycles on the main isolate: every BLE notification (~21/sec at 48ms connection interval) triggers a full `_syncValues()` → `notifyListeners()` → rebuild chain, and every touch event triggers a synchronous `notifyListeners()` that blocks the main isolate. Over time, Dart GC pressure from hundreds of Map allocations per second (from `copyWithInput`/`copyWithOutput`) causes growing GC pauses that block touch event processing.

The API path (bypassing Flutter's widget layer) remains fast at ~30ms, confirming the bottleneck is entirely in the Flutter UI processing pipeline.

## What Changes

- **Skip unnecessary rebuilds**: `_syncValues()` should not fire `DesignerState.notifyListeners()` when no widget values actually changed
- **Batch touch-path notifications**: `DeviceProvider.setInputValue()` should defer `notifyListeners()` via microtask (matching the existing `_scheduleNotifyListeners()` pattern for incoming notifications) instead of calling it synchronously
- **Reduce allocation pressure**: Avoid creating new `RadioWidgetState` map copies when the input value hasn't changed
- **Fix the notification cascade**: `_onDeviceProviderChanged` → `_syncValues` → `DesignerState.notifyListeners()` → `setState(() {})` should only fire when there's actual data to propagate

## Capabilities

### New Capabilities
- `touch-path-optimization`: Reduces Flutter rebuild cycles in the touch→BLE write path and BLE notification→widget update path to eliminate multi-second touch lag

### Modified Capabilities

## Impact

- **Files**: `radiokit-app/lib/widgets/device_designer_bridge.dart`, `radiokit-app/lib/providers/device_provider.dart`, `flutter-widgets/lib/src/models/designer_state.dart`
- **Behavior**: Touch response latency drops from multi-second (growing) to <100ms (stable). Rebuild cycles drop from ~21/sec (constant) to ~6/sec (only when values actually change)
- **Risk**: Low — all changes are optimizations to existing notification/rebuild paths with no protocol or API changes
