# Page Settings

Purpose: TBD

## Requirements

### Requirement: Page Settings section in inspector
The designer inspector SHALL display a PAGE SETTINGS section when no element is selected and the design has more than one page. The section SHALL contain a page name field and an orientation selector.

#### Scenario: Section visible for multi-page designs
- **WHEN** the designer has 2+ pages and no element is selected
- **THEN** the inspector shows a "PAGE SETTINGS" section above the MODEL section

#### Scenario: Section hidden for single-page designs
- **WHEN** the designer has only 1 page
- **THEN** the PAGE SETTINGS section is not shown

### Requirement: Page name text field
The PAGE SETTINGS section SHALL include a live-editing text field for the current page's name. Changes SHALL apply immediately on each keystroke.

#### Scenario: Edit page name
- **WHEN** user types in the page name field
- **THEN** the page name updates in real-time in the page bar tab and JSON config

#### Scenario: Empty name allowed
- **WHEN** user clears the page name field
- **THEN** the page name is empty (no validation error)

### Requirement: Orientation 3-way selector
The PAGE SETTINGS section SHALL include a 3-way segmented selector for orientation with options: "Global", "Landscape", "Portrait". The default SHALL be "Global".

#### Scenario: Select Global orientation
- **WHEN** user selects "Global" in the orientation selector
- **THEN** the page inherits its orientation from the CONTROL UI global setting

#### Scenario: Select Landscape orientation
- **WHEN** user selects "Landscape" in the orientation selector
- **THEN** the page is forced to landscape orientation regardless of global setting

#### Scenario: Select Portrait orientation
- **WHEN** user selects "Portrait" in the orientation selector
- **THEN** the page is forced to portrait orientation regardless of global setting

### Requirement: Section updates on page switch
The PAGE SETTINGS section SHALL reflect the currently active page's name and orientation at all times.

#### Scenario: Switching pages updates section
- **WHEN** user switches to a different page via the tab bar
- **THEN** the page name field shows the new page's name
- **AND** the orientation selector shows the new page's orientation setting
