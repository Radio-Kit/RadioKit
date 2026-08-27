## ADDED Requirements

### Requirement: Declarative Property Inspector Generation
The inspector panel SHALL automatically generate property control fields by iterating over a `WidgetDefinition`'s `propertiesSchema`.

#### Scenario: Selecting an element on designer canvas
- **WHEN** an element is selected in the designer canvas
- **THEN** the inspector panel reads the widget's `propertiesSchema` and renders corresponding numerical, boolean, option, and icon fields.

#### Scenario: Updating a property value in inspector
- **WHEN** a user modifies a property field in the inspector panel
- **THEN** the inspector updates the element's property map and triggers state notification to redraw the canvas element.
