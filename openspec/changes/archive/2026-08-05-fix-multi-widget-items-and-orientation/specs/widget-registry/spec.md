## MODIFIED Requirements

### Requirement: Plugin-based Widget Registration
The system SHALL provide a central `WidgetRegistry` where widgets register their metadata, default sizing, default properties, canvas rendering callback, and inspector schema using a `WidgetDefinition` interface.

#### Scenario: Multi widget itemCount rendering
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` builds a canvas widget
- **THEN** it SHALL read `itemCount` from properties (defaulting to 3)
- **AND** it SHALL generate or pad items up to `itemCount` (clamped between 2 and 8) so that the exact number of buttons specified by `itemCount` is rendered.

#### Scenario: Multi widget orientation flipping
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` is resized on the canvas
- **THEN** it SHALL evaluate `orientation` as horizontal when `width >= height` and vertical when `height > width`
- **AND** it SHALL allow free-form resizing without enforcing a rigid aspect ratio lock that blocks orientation flipping.
