## MODIFIED Requirements

### Requirement: Page-aware widget rendering
The Flutter app SHALL convert wire widget configurations into version 2 JSON format with top-level `pages[]` array and render only the active page's widgets in control mode.

#### Scenario: Active page widgets visible without overlap
- **WHEN** the active page is page 0
- **THEN** only page 0's widgets are rendered on the control canvas
- **AND** page 1's widgets are not visible and do not overlap with page 0 widgets

#### Scenario: Page switch updates active page widgets
- **WHEN** the active page is switched to page 1
- **THEN** only page 1's widgets are rendered on the control canvas
- **AND** page 0's widgets are not visible
