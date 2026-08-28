# multi-widget-item-reorder Specification

## Purpose
TBD - created by archiving change reorderable-multi-widget-items. Update Purpose after archive.
## Requirements
### Requirement: Drag and Drop Reordering of Multi-Widget Items
The designer inspector SHALL allow users to reorder items in multi-button and multi-select widgets by dragging item rows.

#### Scenario: Reordering an item
- **WHEN** the user drags an item from index 0 to index 2 using the drag handle
- **THEN** the items list order in the element properties is updated to reflect the new position and recorded in undo history

### Requirement: Inline Deletion of Multi-Widget Items
The designer inspector SHALL allow deleting an item at any position from the items list.

#### Scenario: Deleting a middle item
- **WHEN** the user clicks the delete trash icon on item 2 of a 4-item widget
- **THEN** item 2 is removed, `itemCount` is decremented to 3, element dimensions are recalculated to maintain aspect ratio, and the action is recorded in undo history

#### Scenario: Deleting the last remaining item
- **WHEN** only 1 item exists in the widget
- **THEN** the delete action is disabled or hidden so the item count cannot fall below 1

### Requirement: Inline Addition of Multi-Widget Items
The designer inspector SHALL allow appending new items up to the maximum limit of 8 items.

#### Scenario: Adding a new item
- **WHEN** the user clicks the "+ Add Item" button in the inspector items header when count is 3
- **THEN** a new item with a default auto-generated label (e.g. "D") is appended, `itemCount` becomes 4, element dimensions are recalculated, and the action is recorded in undo history

#### Scenario: Maximum item limit reached
- **WHEN** the item count reaches 8
- **THEN** the "+ Add Item" button is disabled or hidden

