## ADDED Requirements

### Requirement: Connection card displays configured telemetry
The connection card SHALL display telemetry widgets configured in the designer with live values from the device.

#### Scenario: Configured telemetry with live values
- **WHEN** the device has 2 telemetry widgets configured ("Speed" and "Battery")
- **AND** the device sends VAR_DATA with values for those widgets
- **THEN** the connection card shows a single compact row with both telemetry items
- **AND** each item shows its icon, value, and unit

#### Scenario: No telemetry configured
- **WHEN** the device has 0 telemetry widgets configured
- **THEN** the telemetry section is not shown in the connection card

#### Scenario: Telemetry with no live value yet
- **WHEN** a telemetry widget is configured but no VAR_DATA value has been received
- **THEN** the item shows "--" as the value placeholder

### Requirement: Telemetry data flow from device
The DeviceProvider SHALL store telemetry values received via VAR_DATA and expose them for the connection card.

#### Scenario: VAR_DATA telemetry value received
- **WHEN** the device sends a VAR_DATA packet for a telemetry widget
- **THEN** the DeviceProvider stores the value mapped to the telemetry widget index
- **AND** the connection card updates to show the new value

#### Scenario: Multiple telemetry values
- **WHEN** the device sends VAR_DATA for multiple telemetry widgets
- **THEN** each widget's value is stored independently
- **AND** the connection card shows all values simultaneously

### Requirement: Telemetry display layout
The connection card telemetry SHALL render as a single compact horizontal row.

#### Scenario: Single telemetry item
- **WHEN** 1 telemetry widget is configured
- **THEN** the connection card shows one item centered in the row

#### Scenario: Multiple telemetry items
- **WHEN** 2 or more telemetry widgets are configured
- **THEN** the connection card shows all items evenly spaced in a single row

### Requirement: Telemetry display styling
Each telemetry item in the connection card SHALL show icon, value, and unit in a compact format.

#### Scenario: Item with icon
- **WHEN** a telemetry widget has an icon configured
- **THEN** the item displays the icon to the left of the value

#### Scenario: Item without icon
- **WHEN** a telemetry widget has no icon configured
- **THEN** the item displays only the value and unit without an icon
