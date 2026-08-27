# touch-path-optimization Specification

## Purpose
TBD - created by archiving change fix-touch-path-latency. Update Purpose after archive.

## Requirements

### Requirement: Conditional rebuild on BLE notification
`_syncValues()` in `DeviceDesignerBridge` must only call `DesignerState.notifyListeners()` when at least one widget value actually changed during the sync cycle. Unchanged values must not trigger rebuilds.

### Requirement: Batched touch-path notifications
`DeviceProvider.setInputValue()` must defer `notifyListeners()` via microtask (using `_scheduleNotifyListeners()`) instead of calling it synchronously. This prevents the touch-to-BLE write path from blocking the main isolate during rebuild.

### Requirement: Skip unchanged inputs
`DeviceProvider.setInputValue()` must compare the new values against the current input values and skip the update (no Map copy, no notify, no BLE write) if they are identical. This applies to both discrete and continuous widgets.

### Requirement: Skip unchanged normalized values in touch callback
`_onWidgetValueChanged` in `DeviceDesignerBridge` must compare the normalized value against the current runtime widget value and skip calling `setInputValue` if they match (for non-continuous widgets).

### Requirement: Stable touch latency
Touch-to-command latency must remain stable (<100ms) for at least 5 minutes of continuous use. The growing lag pattern (0ms to 3-4s over 2 minutes) must be eliminated.
