## MODIFIED Requirements

### Requirement: Page-aware widget rendering
The Flutter app SHALL convert wire widget configurations into version 2 JSON format with top-level `pages[]` array and render only the active page's widgets in control mode. When the reconstructed config is multi-page, `widgetConfigsToDesignerJson` SHALL emit the top-level `pages[]` array grouped by `pageIndex` with page names, instead of a flat `widgets[]` list.

#### Scenario: Active page widgets visible without overlap
- **WHEN** the active page is page 0
- **THEN** only page 0's widgets are rendered on the control canvas
- **AND** page 1's widgets are not visible and do not overlap with page 0 widgets

#### Scenario: Page switch updates active page widgets
- **WHEN** the active page is switched to page 1
- **THEN** only page 1's widgets are rendered on the control canvas
- **AND** page 0's widgets are not visible

#### Scenario: Multi-page config reconstructed with pages array
- **WHEN** the device reports 2 pages and the app reconstructs the config via `widgetConfigsToDesignerJson`
- **THEN** the output contains a top-level `pages[]` array with one entry per page
- **AND** each page entry contains its `name` and its widgets grouped by `pageIndex`
- **AND** the output does not emit a flat `widgets[]` list

#### Scenario: Single-page config retains flat widgets
- **WHEN** the device reports a single page
- **THEN** the output emits the flat `widgets[]` list for backward compatibility

### Requirement: Reconstructed config preserves device features
The Flutter app SHALL preserve top-level device metadata (`features` and `enableControlUI`) in the reconstructed designer JSON when the connected device reports them.

#### Scenario: Features preserved in reconstruction
- **WHEN** the device reports `features: {"ota": true, "filesystem": true}` and `enableControlUI: true`
- **THEN** the reconstructed config includes `features` and `enableControlUI`