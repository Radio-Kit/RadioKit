## ADDED Requirements

### Requirement: Telemetry preview row displays all configured slots

The designer inspector telemetry section SHALL display a preview row between the section header and the editor rows, showing all configured telemetry slots rendered as they appear on the connected device card.

#### Scenario: Preview shows configured slots
- **WHEN** the telemetry section has 2 slots with labels "Speed" and "Battery"
- **THEN** the preview row renders two `_TelemetryItem`-style widgets side by side with label, icon (if set), sample value "120", and unit (if set)

#### Scenario: Preview skips empty slots
- **WHEN** a telemetry slot has an empty label
- **THEN** the slot is not rendered in the preview row

#### Scenario: Preview updates on label change
- **WHEN** the user types "RPM" into the label field of slot 0
- **THEN** the preview row immediately shows "RPM" as the label for that slot

#### Scenario: Preview updates on icon change
- **WHEN** the user selects the "gauge" icon for slot 0
- **THEN** the preview row immediately shows the gauge icon for that slot

#### Scenario: Preview updates on unit change
- **WHEN** the user types "km/h" into the unit field of slot 0
- **THEN** the preview row immediately shows "km/h" as the unit for that slot

#### Scenario: Empty preview when no slots configured
- **WHEN** the telemetry list is empty
- **THEN** no preview row is rendered

### Requirement: Preview styling matches connected device card

The preview row SHALL use identical styling to the `_TelemetryItem` widget on the connected device card.

#### Scenario: Label styling
- **WHEN** a slot with label "Speed" is rendered in the preview
- **THEN** the label is rendered with fontSize 9, fontWeight bold, and color onSurface at 38% opacity

#### Scenario: Value styling
- **WHEN** a slot is rendered in the preview
- **THEN** the sample value "120" is rendered with Google Fonts Exo2, fontSize 22, fontWeight w900, and tokens.primary color

#### Scenario: Icon styling
- **WHEN** a slot has icon "gauge" set
- **THEN** the icon is rendered with tokens.primary color at size 16

#### Scenario: Unit styling
- **WHEN** a slot has unit "km/h" set
- **THEN** the unit is rendered with fontSize 10, fontWeight bold, and color onSurface at 38% opacity

### Requirement: Preview uses horizontal layout

The preview row SHALL render all configured slots in a single horizontal row with even spacing.

#### Scenario: Multiple slots layout
- **WHEN** 3 slots are configured
- **THEN** the preview row renders as a `Row` with `MainAxisAlignment.spaceEvenly` and each item wrapped in `Flexible`

#### Scenario: Single slot layout
- **WHEN** 1 slot is configured
- **THEN** the preview row renders that single item centered in the row
