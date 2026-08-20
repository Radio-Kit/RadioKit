## Context

The RadioKit Flutter app processes BLE notifications and touch events on the main isolate. The current architecture has three compounding performance issues:

1. `_syncValues()` fires `DesignerState.notifyListeners()` unconditionally on every BLE notification, even when no values changed
2. `DeviceProvider.setInputValue()` calls `notifyListeners()` synchronously, blocking the main isolate during touch handling
3. Each notification/touch event creates new `RadioWidgetState` objects via `copyWithInput`/`copyWithOutput`, generating GC pressure

Measured impact: touch lag grows from 0ms to 3-4 seconds over ~2 minutes of use.

## Goals / Non-Goals

**Goals:**
- Eliminate the growing touch lag (target: <100ms stable)
- Reduce rebuild cycles from ~21/sec to ~6/sec (only when values actually change)
- Reduce Map allocation rate by ~70%

**Non-Goals:**
- Changing the BLE protocol or firmware
- Restructuring the widget tree
- Adding isolates or complex concurrency

## Design

### Change 1: Conditional notify in `_syncValues()` (device_designer_bridge.dart)

Track whether any values actually changed during the sync loop. Only call `_designerState.notifyListeners()` if something changed.

```dart
void _syncValues() {
    final state = widget.deviceProvider.widgetState;
    if (state == null) return;

    _designerState.beginRuntimeSync();
    bool changed = false;  // ← NEW
    try {
      for (final el in _designerState.elements) {
        // ... existing normalization logic ...
        final currentVal = _designerState.getRuntimeWidgetValue(el.id, null);
        if (currentVal != normalized) {
          changed = true;  // ← NEW
          // ... existing setRuntimeWidgetValue call ...
        }
      }
      // ... hidden state sync ...
    } finally {
      _designerState.endRuntimeSync();
    }
    if (changed) {  // ← NEW: only notify if something changed
      _designerState.notifyListeners();
    }
}
```

### Change 2: Microtask-batched notify in `setInputValue()` (device_provider.dart)

Replace the synchronous `notifyListeners()` call with the existing `_scheduleNotifyListeners()` pattern (microtask batching). This defers the rebuild to after the current event handler completes, allowing touch events to be processed without waiting for the rebuild chain.

```dart
Future<void> setInputValue(int widgetId, List<int> values) async {
    final current = _widgetState;
    if (current == null) return;

    // ... existing interaction logging ...

    // Skip if value hasn't changed (avoids unnecessary Map allocation + notify)
    final currentInput = current.inputValues[widgetId];
    if (currentInput != null && _listEquals(currentInput, values)) return;  // ← NEW

    final next = current.copyWithInput(widgetId, values);
    _widgetState = next;
    _scheduleNotifyListeners();  // ← CHANGED: was notifyListeners()
    if (!_transport.isConnected) return;
    await _sendVarUpdate(widgetId, values);
}
```

### Change 3: Skip unchanged inputs in `_onWidgetValueChanged` (device_designer_bridge.dart)

Before calling `setInputValue`, check if the normalized value is actually different from the current value. This prevents redundant Map copies and BLE writes during rapid drag events where the quantized value hasn't changed.

```dart
void _onWidgetValueChanged(String id, dynamic value) {
    // ... existing normalization logic ...
    
    // NEW: skip if normalized value matches current
    final currentVal = _designerState.getRuntimeWidgetValue(el.id, null);
    if (currentVal == normalized && !isContinuous) return;

    // ... existing throttle/send logic ...
}
```

### Change 4: Add `_listEquals` helper (device_provider.dart)

Simple list equality check to avoid unnecessary `copyWithInput` calls:

```dart
bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
}
```

## Risks

- **Stale widget state**: If `_scheduleNotifyListeners()` defers notification too long, widget visuals might lag behind the actual value. Mitigated by the 25ms throttle already in place for continuous widgets.
- **Missing value sync**: If `changed` tracking misses a case, widget displays could freeze. Mitigated by the fact that `_syncValues` runs on every notification cycle (~21/sec), so any missed update is caught within 48ms.
