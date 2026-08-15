## MODIFIED Requirements

### Requirement: Multi widget itemCount rendering
The system SHALL keep the `itemCount` property of multi-widget types (`multiButton`/`multiSelect`) in sync with the actual `items` array length whenever items are loaded, added, or removed. `itemCount` SHALL always equal the number of serialized items, matching codegen behavior that emits `items.length`.

#### Scenario: Multi widget itemCount rendering
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` builds a canvas widget
- **THEN** it SHALL read `itemCount` from properties (defaulting to 3)
- **AND** it SHALL generate or pad items up to `itemCount` (clamped between 2 and 8) so that the exact number of buttons specified by `itemCount` is rendered.

#### Scenario: Multi widget orientation flipping
- **WHEN** `MultiButtonWidgetDefinition` or `MultiSelectWidgetDefinition` is resized on the canvas
- **THEN** it SHALL evaluate `orientation` as horizontal when `width >= height` and vertical when `height > width`
- **AND** it SHALL allow free-form resizing without enforcing a rigid aspect ratio lock that blocks orientation flipping.

#### Scenario: Loaded design normalizes stale itemCount
- **WHEN** a design is loaded with `itemCount` set higher than its `items` array length (e.g., `itemCount=5` with 3 items)
- **THEN** the designer normalizes `itemCount` to the `items` array length (3)
- **AND** subsequent saves serialize `itemCount` equal to the `items` length

#### Scenario: Item add or remove keeps itemCount in sync
- **WHEN** the user adds or removes an item in the multi-item editor
- **THEN** `itemCount` updates to match the new `items` array length