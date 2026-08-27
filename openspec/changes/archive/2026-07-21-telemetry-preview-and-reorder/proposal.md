## Why

The telemetry section in the designer inspector is currently a blind form — icon picker, label input, unit input with no visual indication of what the final output looks like. Users configure telemetry slots without seeing how they'll render on the connected device card. Additionally, there's no way to reorder telemetry slots once added — the order is stuck as insertion order.

## What Changes

- Add a live preview row at the top of the telemetry section showing all configured slots rendered exactly as they appear on the connected device card (label, icon, sample value, unit)
- Add drag-and-drop reordering for telemetry editor rows via a grip handle on each slot
- Add a `reorderTelemetrySlot()` method to `DesignerState` for list reordering with undo support

## Capabilities

### New Capabilities
- `telemetry-preview`: Live preview row in the designer inspector telemetry section showing all configured slots as they'll appear on the control screen
- `telemetry-reorder`: Drag-and-drop reordering of telemetry slots in the designer inspector with undo support

### Modified Capabilities

## Impact

- `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` — `_buildTelemetrySection` rewritten with preview row and reorderable editor rows, new `_TelemetryPreviewItem` widget
- `flutter-widgets/lib/src/models/designer_state.dart` — new `reorderTelemetrySlot(int oldIndex, int newIndex)` method
- `radiokit-app/test/page_orientation_override_test.dart` — new tests for reorder and preview behavior
- No new dependencies (GoogleFonts already used in 18 files, LucideIcons already imported)
