# telemetry-config Specification

## Purpose

Telemetry widgets are display-only widgets that do not occupy canvas positions. They must survive the firmware widget cap alongside UI widgets, round-trip through the wire protocol as their own type, and be reconstructed into the designer JSON as a top-level `telemetry[]` array rather than falling through to `button`.

## Requirements

### Requirement: Telemetry widgets not dropped by firmware widget cap

The Arduino library SHALL register every declared widget, including telemetry widgets, up to a capacity that accommodates both UI and telemetry widgets in a single design.

#### Scenario: Telemetry widget registered within capacity
- **WHEN** a design declares 15 UI widgets and 2 telemetry widgets (17 registrations)
- **THEN** all 17 widgets are registered with sequential widget IDs
- **AND** no widget is silently rejected by the registration limit

#### Scenario: No widget exceeds the widget ID mask
- **WHEN** a design registers widgets
- **THEN** every registered widget has a widget ID less than the pending-update bit mask width (32)
- **AND** `pushUpdate`/`pushMetaUpdate` accept all registered widget IDs

### Requirement: Telemetry wire type reconstruction

The Flutter app SHALL map wire typeId `0x0A` (`kWidgetTelemetry`) to a `telemetry` designer type instead of falling through to `button`.

#### Scenario: Telemetry widget parsed from CONF_DATA
- **WHEN** the app receives a CONF_DATA widget with typeId `0x0A` and label "Battery"
- **THEN** the reconstructed widget type is `telemetry`
- **AND** the label is preserved as "Battery"

#### Scenario: Telemetry extracted into config telemetry array
- **WHEN** `widgetConfigsToDesignerJson` processes a config containing telemetry widgets
- **THEN** the output contains a top-level `telemetry[]` array
- **AND** each entry carries the telemetry widget's label
- **AND** telemetry widgets do not appear in the page widget lists
