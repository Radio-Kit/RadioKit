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

### Requirement: Backward Compatibility with Legacy Widget Enums
The `WidgetRegistry` SHALL map legacy string type names and enum identifiers to corresponding registered `WidgetDefinition` instances.

#### Scenario: Deserializing legacy JSON config
- **WHEN** a JSON design configuration containing legacy string type identifiers is loaded
- **THEN** `WidgetRegistry` resolves the correct `WidgetDefinition` and populates default properties without error.

