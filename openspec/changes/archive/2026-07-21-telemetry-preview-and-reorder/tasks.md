## 1. Model: Reorder method

- [x] 1.1 Add `reorderTelemetrySlot(int oldIndex, int newIndex)` to `DesignerState` with `_pushUndo()` and list mutation

## 2. Preview row

- [x] 2.1 Create `_TelemetryPreviewItem` widget in `designer_inspector.dart` (label, icon, sample value "120", unit — matching `_TelemetryItem` styling)
- [x] 2.2 Add preview row to `_buildTelemetrySection` between header and editor rows
- [x] 2.3 Skip empty slots in preview row (`label.isEmpty` check)
- [x] 2.4 Wrap preview items in `Flexible` with `Row(mainAxisAlignment: spaceEvenly)`

## 3. Drag-and-drop reorder

- [x] 3.1 Add `_draggingIndex` and `_dragOverIndex` state variables to `DesignerInspector` State
- [x] 3.2 Add grip handle (`LucideIcons.gripVertical`) to each editor row (left side, before icon picker)
- [x] 3.3 Wrap grip handle in `LongPressDraggable<int>` with slot index as data
- [x] 3.4 Wrap editor row in `DragTarget<int>` with `onWillAccept`, `onMove`, `onLeave`, `onAccept` callbacks
- [x] 3.5 Render drop indicator line (2px, `tokens.primary`) between rows based on `_dragOverIndex`
- [x] 3.6 Call `reorderTelemetrySlot()` in `onAccept` and reset drag state
- [x] 3.7 Hide grip handle when only 1 slot exists

## 4. Styling and polish

- [x] 4.1 Add `import 'package:google_fonts/google_fonts.dart'` to `designer_inspector.dart`
- [x] 4.2 Style grip handle: `onSurface @ 0.38` default, `tokens.primary` when active
- [x] 4.3 Style dragged row: `Opacity(0.8)` + `BoxShadow(blurRadius: 8)` in overlay
- [x] 4.4 Style drop indicator: 2px `tokens.primary`, full width, animated opacity

## 5. Tests

- [x] 5.1 Add unit test for `reorderTelemetrySlot` — list mutation and undo
- [x] 5.2 Add unit test for preview rendering — configured slots appear, empty slots skipped
- [x] 5.3 Add unit test for reorder undo — single undo reverts the full reorder

## 6. Verify

- [x] 6.1 Run `flutter analyze --fatal-warnings`
- [x] 6.2 Run `flutter test` — all tests pass
