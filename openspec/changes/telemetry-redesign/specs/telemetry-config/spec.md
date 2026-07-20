## ADDED Requirements

### Requirement: Variable-length telemetry widget list
The designer SHALL support 0 to 4 telemetry widgets in a variable-length list.

#### Scenario: Add telemetry widget
- **WHEN** the user taps "+ Add" in the TELEMETRY section
- **AND** the current telemetry count is less than 4
- **THEN** a new empty telemetry slot is appended to the list
- **AND** the new slot shows icon picker, label field, and unit field

#### Scenario: Remove telemetry widget
- **WHEN** the user taps the remove button on a telemetry slot
- **THEN** that slot is removed from the list
- **AND** remaining slots shift to fill the gap

#### Scenario: Maximum 4 widgets
- **WHEN** the user has 4 telemetry widgets configured
- **THEN** the "+ Add" button is not displayed

#### Scenario: Telemetry disabled when empty
- **WHEN** the telemetry list has 0 widgets
- **THEN** no telemetry section is rendered in the connection card

### Requirement: Telemetry slot UI
Each telemetry widget slot SHALL display an icon picker, label text field, and unit text field in a compact inline layout.

#### Scenario: Configured slot
- **WHEN** a telemetry slot has a label set
- **THEN** the slot shows the selected icon, the label text, and the unit text

#### Scenario: Empty slot
- **WHEN** a telemetry slot has no label set
- **THEN** the slot shows a placeholder icon and empty text fields

### Requirement: Telemetry undo support
All telemetry mutations SHALL be undoable via the undo system.

#### Scenario: Undo add widget
- **WHEN** the user adds a telemetry widget and then undoes
- **THEN** the added widget is removed

#### Scenario: Undo remove widget
- **WHEN** the user removes a telemetry widget and then undoes
- **THEN** the removed widget is restored at its original position

#### Scenario: Undo label change
- **WHEN** the user changes a telemetry label and then undoes
- **THEN** the label reverts to its previous value

### Requirement: Telemetry serialization
The telemetry list SHALL be serialized as a variable-length JSON array.

#### Scenario: Save with configured widgets
- **WHEN** the user has 2 telemetry widgets configured
- **THEN** the JSON contains `"telemetry": [{...}, {...}]`

#### Scenario: Save with no widgets
- **WHEN** the user has 0 telemetry widgets
- **THEN** the JSON contains `"telemetry": []`

#### Scenario: Load legacy 4-element array
- **WHEN** a JSON config has `"telemetry"` with exactly 4 elements where some are empty
- **THEN** trailing empty slots are stripped on load
- **AND** the telemetry list contains only the non-empty slots

### Requirement: Telemetry code generation
The codegen SHALL generate `RK_Telemetry` widgets only for non-empty telemetry slots.

#### Scenario: Generate for configured widgets
- **WHEN** the config has 2 telemetry widgets with labels "Speed" and "Battery"
- **THEN** the generated C++ code contains `RK_Telemetry telemetry_Speed` and `RK_Telemetry telemetry_Battery`

#### Scenario: Skip empty slots
- **WHEN** the config has an empty telemetry slot between configured slots
- **THEN** no C++ code is generated for the empty slot

### Requirement: Clean up dead telemetry code
The unused `TelemetryWidgetData` class and `kTelemetryIcons` map SHALL be removed.

#### Scenario: Dead code removed
- **WHEN** the implementation is complete
- **THEN** `radiokit-app/lib/models/telemetry_widget.dart` contains no unused telemetry model classes
- **AND** no imports reference removed code
