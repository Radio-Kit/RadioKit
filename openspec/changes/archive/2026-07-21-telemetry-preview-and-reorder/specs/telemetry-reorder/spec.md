## ADDED Requirements

### Requirement: Telemetry slots are reorderable via drag-and-drop

Each telemetry editor row SHALL display a grip handle that initiates drag-and-drop reordering via long-press.

#### Scenario: Drag handle visible on multi-slot lists
- **WHEN** the telemetry section has 2 or more slots
- **THEN** each editor row displays a grip handle (`LucideIcons.gripVertical`, 14px, `onSurface @ 0.38`) on the left side

#### Scenario: Drag handle hidden on single slot
- **WHEN** the telemetry section has exactly 1 slot
- **THEN** no grip handle is shown

#### Scenario: Long-press initiates drag
- **WHEN** the user long-presses the grip handle of slot 1
- **THEN** the row enters drag mode (lifted appearance, 0.8 opacity, shadow)

### Requirement: Drop indicator shows insertion point

A visual indicator SHALL show where the dragged item will be inserted.

#### Scenario: Indicator appears above target row
- **WHEN** the user drags a slot over the top half of another row
- **THEN** a 2px colored line (`tokens.primary`) appears between the row above and the hovered row

#### Scenario: Indicator appears below target row
- **WHEN** the user drags a slot over the bottom half of another row
- **THEN** a 2px colored line appears between the hovered row and the row below

#### Scenario: Indicator disappears on drop
- **WHEN** the user drops the dragged slot
- **THEN** the insertion line disappears

### Requirement: Drop reorders the telemetry list

Dropping a dragged slot SHALL reorder the `_telemetryWidgets` list and update the preview.

#### Scenario: Successful reorder
- **WHEN** the user drags slot 0 and drops it at position 2
- **THEN** the slot moves from index 0 to index 2 in the list
- **AND** the editor rows reflect the new order
- **AND** the preview row reflects the new order

#### Scenario: Reorder is undoable
- **WHEN** the user reorders a slot and then triggers undo
- **THEN** the telemetry list returns to its previous order
- **AND** the preview returns to its previous order

### Requirement: Reorder method on DesignerState

`DesignerState` SHALL expose a `reorderTelemetrySlot(int oldIndex, int newIndex)` method.

#### Scenario: Method reorders the list
- **WHEN** `reorderTelemetrySlot(0, 2)` is called on a 3-slot list
- **THEN** the item at index 0 moves to index 2
- **AND** items at indices 1 and 2 shift left

#### Scenario: Method calls pushUndo
- **WHEN** `reorderTelemetrySlot(0, 1)` is called
- **THEN** `_pushUndo()` is called before the list mutation
