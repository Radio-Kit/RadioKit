## MODIFIED Requirements

### Requirement: Page bar with navigation controls
The designer SHALL display a page bar below the top toolbar containing centered chevron buttons (< and >), tab buttons with page names for each page, and the current page name. The page bar SHALL include a toggle button to hide/show the bar, and an add page button.

#### Scenario: Page bar renders correctly
- **WHEN** the designer screen loads with a multi-page config
- **THEN** the page bar displays with left chevron, tab buttons with page names, toggle button, add button, and right chevron

#### Scenario: Left chevron disabled on first page
- **WHEN** the active page is page 0 (first page)
- **THEN** the left chevron button is disabled/hidden

#### Scenario: Right chevron disabled on last page
- **WHEN** the active page is the last page
- **THEN** the right chevron button is disabled/hidden

#### Scenario: Tab tap switches page
- **WHEN** user taps an inactive tab
- **THEN** that page becomes active

#### Scenario: Tab long-press opens context menu
- **WHEN** user long-presses a tab
- **THEN** a context menu appears with rename, duplicate, and delete options
