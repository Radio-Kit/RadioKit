## ADDED Requirements

### Requirement: Default Aspect Ratio Preview Scaling
The "Add Widget" bottom sheet grid SHALL display widget preview instances scaled to their canonical default aspect ratio `(defW : defH)` derived from `DesignerElement.defaultSize(type)`.

#### Scenario: User opens Add Widget bottom sheet
- **WHEN** the user opens the Add Widget bottom sheet in the designer
- **THEN** every widget item in the grid cell renders inside a `FittedBox` maintaining its default grid aspect ratio `(defW : defH)` without hardcoded pixel distortion

#### Scenario: Rendering varied widget shapes in sheet preview grid
- **WHEN** non-square widgets (such as 3:1 linear sliders, 1:2 gas pedals, 2:1 multi-buttons, or 3:1 text displays) render in the preview grid
- **THEN** each preview widget preserves its proportional shape scaled cleanly within the cell bounds
