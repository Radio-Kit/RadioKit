## ADDED Requirements

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

### Requirement: Add new page
The designer SHALL allow users to add a new page via the add button in the page bar.

#### Scenario: Add page creates new blank page
- **WHEN** user taps the add page button
- **THEN** a new empty page is appended after the current page with a default name (e.g., "Page N")
- **AND** the new page becomes the active page

### Requirement: Remove page
The designer SHALL allow users to remove a page via a long-press or context menu on the page indicator.

#### Scenario: Remove page deletes the page
- **WHEN** user confirms page deletion
- **THEN** the page and all its widgets are removed
- **AND** the adjacent page becomes active

#### Scenario: Cannot remove last page
- **WHEN** only one page exists
- **THEN** the remove page action is disabled

### Requirement: Rename page
The designer SHALL allow users to rename a page by tapping on the page name in the page bar.

#### Scenario: Rename page updates the name
- **WHEN** user taps page name and enters a new name
- **THEN** the page name is updated in the page bar and JSON config

### Requirement: Duplicate page
The designer SHALL allow users to duplicate a page with all its widgets.

#### Scenario: Duplicate page creates a copy
- **WHEN** user selects "Duplicate Page" from the page context menu
- **THEN** a new page is created with the same widgets and layout
- **AND** the new page name is "{Original Name} (Copy)"

### Requirement: Per-page canvas orientation
The designer SHALL support per-page orientation (landscape or portrait) that changes the canvas dimensions when switching pages.

#### Scenario: Switch page changes canvas size
- **WHEN** user switches from a landscape page to a portrait page
- **THEN** the canvas instantly resizes from 200x100 to 100x200
- **AND** widgets remain at their grid positions

#### Scenario: Set page orientation
- **WHEN** user changes orientation in the page settings
- **THEN** the canvas dimensions update for that page only

### Requirement: Cross-page copy and paste
The designer SHALL allow users to copy a widget from one page and paste it onto another page.

#### Scenario: Copy widget across pages
- **WHEN** user copies a widget on Page 1 and pastes it on Page 2
- **THEN** a new widget instance is created on Page 2 with the same properties
- **AND** the new widget gets a unique global name

### Requirement: Per-page undo and redo
The designer SHALL maintain separate undo/redo stacks for each page.

#### Scenario: Undo on page affects only that page
- **WHEN** user makes changes on Page 1 and switches to Page 2
- **THEN** undo on Page 2 does not affect Page 1's changes

#### Scenario: Undo stack persists across page switches
- **WHEN** user makes changes on Page 1, switches to Page 2, then switches back
- **THEN** Page 1's undo history is preserved
