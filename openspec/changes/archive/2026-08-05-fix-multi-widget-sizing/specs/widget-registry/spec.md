## MODIFIED Requirements

### Requirement: Plugin-based Widget Registration
The system SHALL provide a central `WidgetRegistry` where widgets register their metadata, default sizing, default properties, canvas rendering callback, and inspector schema using a `WidgetDefinition` interface.

#### Scenario: Registering a new widget definition
- **WHEN** a custom `WidgetDefinition` is registered with `WidgetRegistry`
- **THEN** the widget becomes immediately available to the canvas rendering engine and designer widget palette without modifying core enum or switch statements.

#### Scenario: Rendering widget from registry
- **WHEN** `CanvasElement` builds a widget for a given widget type ID
- **THEN** it retrieves the matching `WidgetDefinition` from `WidgetRegistry` and executes its canvas builder callback.

#### Scenario: Multi widget fills its grid cell
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` builds a canvas widget
- **THEN** it SHALL compute `buttonSize` from `ctx.width`, `ctx.height`, and `ctx.cellSize` so the widget fills its grid cell
- **AND** it SHALL pass `orientation` based on `ctx.width >= ctx.height` so the widget flips between horizontal and vertical when resized
