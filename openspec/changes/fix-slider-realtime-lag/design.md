## Context

The slider-to-PWM path has two phases:
1. **Write path** (touch → BLE): User drags slider → `onChanged` → `setRuntimeWidgetValue` → `_onWidgetValueChanged` → `setInputValue` → BLE write
2. **Read path** (BLE notification → widget update): BLE notification → `_handleVarUpdate` → `_scheduleNotifyListeners` → `_syncValues` → widget rebuild

The write path needs synchronous `notifyListeners()` so the widget state updates immediately and the next touch event sees current state. The read path can use microtask batching because BLE notifications arrive faster than the UI can render.

## Design

### Change 1: Revert `setInputValue` to synchronous notify

```dart
// BEFORE (broken):
_scheduleNotifyListeners();  // deferred → visual lag

// AFTER (fixed):
notifyListeners();  // synchronous → immediate visual update
```

### Change 2: Keep `_listEquals` skip (already implemented)

```dart
final currentInput = current.inputValues[widgetId];
if (currentInput != null && _listEquals(currentInput, values)) return;
```

This still avoids redundant Map copies and BLE writes when the value hasn't changed.

### Change 3: Remove debug instrumentation

Remove the `debugPrint` lines added for diagnostics in `setInputValue` and `_onWidgetValueChanged`.

## Risks

- Synchronous `notifyListeners()` in the write path means each touch event triggers a rebuild. With rapid drag events (~60/sec), this is ~60 rebuilds/sec. Flutter handles this efficiently with incremental diffing.
- The read path still uses microtask batching, so incoming BLE notifications don't cause rebuild storms.
