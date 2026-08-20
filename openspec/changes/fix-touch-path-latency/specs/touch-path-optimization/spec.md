# Touch Path Optimization

## Requirements

### R1: Conditional rebuild on BLE notification
`_syncValues()` in `DeviceDesignerBridge` must only call `DesignerState.notifyListeners()` when at least one widget value actually changed during the sync cycle. Unchanged values must not trigger rebuilds.

### R2: Batched touch-path notifications
`DeviceProvider.setInputValue()` must defer `notifyListeners()` via microtask (using `_scheduleNotifyListeners()`) instead of calling it synchronously. This prevents the touch→BLE write path from blocking the main isolate during rebuild.

### R3: Skip unchanged inputs
`DeviceProvider.setInputValue()` must compare the new values against the current input values and skip the update (no Map copy, no notify, no BLE write) if they are identical. This applies to both discrete and continuous widgets.

### R4: Skip unchanged normalized values in touch callback
`_onWidgetValueChanged` in `DeviceDesignerBridge` must compare the normalized value against the current runtime widget value and skip calling `setInputValue` if they match (for non-continuous widgets).

### R5: Stable touch latency
Touch-to-command latency must remain stable (<100ms) for at least 5 minutes of continuous use. The growing lag pattern (0ms → 3-4s over 2 minutes) must be eliminated.
