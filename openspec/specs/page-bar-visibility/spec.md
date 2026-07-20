# page-bar-visibility

## Purpose

Toggle show/hide for the designer page bar.

## Requirements

### Requirement: Toggle page bar visibility
The designer SHALL include a toggle button to show or hide the page bar. The toggle button SHALL be located in the page bar area itself (right side).

#### Scenario: Toggle button present
- **WHEN** the page bar is visible
- **THEN** a toggle button (panelTopOpen icon) is shown in the page bar

#### Scenario: Hide page bar
- **WHEN** user taps the toggle button while the page bar is visible
- **THEN** the page bar collapses to 0 height with an animated transition
- **AND** a small restore button appears at the top-center of the canvas

#### Scenario: Show page bar
- **WHEN** user taps the restore button while the page bar is hidden
- **THEN** the page bar expands back to its full height with an animated transition

### Requirement: Persist page bar visibility in config
The page bar visibility state SHALL be stored in the JSON config under `canvas.showPageBar`. The default value SHALL be `true` when the field is missing.

#### Scenario: Save visibility state
- **WHEN** user hides the page bar
- **THEN** the JSON config contains `"showPageBar": false` in the canvas object

#### Scenario: Load visibility state
- **WHEN** a design config with `"showPageBar": false` is loaded
- **THEN** the page bar starts hidden

#### Scenario: Backward compatibility
- **WHEN** a design config without `showPageBar` field is loaded
- **THEN** the page bar defaults to visible

### Requirement: Single toggle button
The toggle SHALL use a single button that changes icon based on state:
- `LucideIcons.panelTopOpen` when page bar is visible (tap to hide)
- `LucideIcons.panelTopClose` when page bar is hidden (tap to show, shown in restore button)

#### Scenario: Toggle icon changes
- **WHEN** page bar is visible
- **THEN** toggle shows panelTopOpen icon
- **WHEN** page bar is hidden
- **THEN** restore button shows panelTopClose icon
