# widget-registry Specification

## Purpose
TBD - created by archiving change refactor-modular-app. Update Purpose after archive.
## Requirements
### Requirement: Plugin-based Widget Registration
The system SHALL provide a central `WidgetRegistry` where widgets register their metadata, default sizing, default properties, canvas rendering callback, and inspector schema using a `WidgetDefinition` interface.

#### Scenario: Registering a new widget definition
- **WHEN** a custom `WidgetDefinition` is registered with `WidgetRegistry`
- **THEN** the widget becomes immediately available to the canvas rendering engine and designer widget palette without modifying core enum or switch statements.

#### Scenario: Rendering widget from registry
- **WHEN** `CanvasElement` builds a widget for a given widget type ID
- **THEN** it retrieves the matching `WidgetDefinition` from `WidgetRegistry` and executes its canvas builder callback.

#### Scenario: Multi widget itemCount rendering
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` builds a canvas widget
- **THEN** it SHALL read `itemCount` from properties (defaulting to 3)
- **AND** it SHALL generate or pad items up to `itemCount` (clamped between 2 and 8) so that the exact number of buttons specified by `itemCount` is rendered.

#### Scenario: Multi widget orientation flipping
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` is resized on the canvas
- **THEN** it SHALL evaluate `orientation` as horizontal when `width >= height` and vertical when `height > width`
- **AND** it SHALL allow free-form resizing without enforcing a rigid aspect ratio lock that blocks orientation flipping.

### Requirement: Backward Compatibility with Legacy Widget Enums
The `WidgetRegistry` SHALL map legacy string type names and enum identifiers to corresponding registered `WidgetDefinition` instances.

#### Scenario: Deserializing legacy JSON config
- **WHEN** a JSON design configuration containing legacy string type identifiers is loaded
- **THEN** `WidgetRegistry` resolves the correct `WidgetDefinition` and populates default properties without error.

