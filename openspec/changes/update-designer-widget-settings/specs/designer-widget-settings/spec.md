## ADDED Requirements

### Requirement: Slider AutoCenter Position Control
The designer inspector SHALL allow users to select between `none`, `min`, `center`, and `max` auto-center positions for slider-based widgets.

#### Scenario: User selects none for slider autoCenter
- **WHEN** the user selects "none" in the AutoCenter position inspector dropdown for a slider
- **THEN** the widget's `autoCenter` property array has `null` as its first element, disabling spring centering

#### Scenario: User selects min, center, or max for slider autoCenter
- **WHEN** the user selects "min", "center", or "max" in the AutoCenter position inspector dropdown for a slider
- **THEN** the widget's `autoCenter` property array is updated with the selected position string as its first element

### Requirement: MultiButton Item Text and Icon Configuration
The designer inspector SHALL render ON and OFF text inputs and icon picker fields for all items in a MultiButton or MultiSelect widget.

#### Scenario: User edits label or icon of a MultiButton item
- **WHEN** the user selects a MultiButton or MultiSelect widget in the designer and modifies an item's text or icon field
- **THEN** the corresponding `onLabel`, `offLabel`, `onIcon`, or `offIcon` entry in the element's `items` array is updated and reflected in the canvas preview

### Requirement: MultiButton Variant Mode
The MultiButton and MultiSelect widget definitions and designer inspector SHALL support a `variant` property with options `push` (momentary) and `toggle` (latching).

#### Scenario: User toggles button mode variant for MultiButton
- **WHEN** the user changes the Button Mode setting for a MultiButton widget between "push" and "toggle"
- **THEN** the element's top-level `variant` property is updated, and the generated Arduino C++ code emits the corresponding `setMode(RK_BUTTON_PUSH)` or `setMode(RK_BUTTON_TOGGLE)` initialization call
