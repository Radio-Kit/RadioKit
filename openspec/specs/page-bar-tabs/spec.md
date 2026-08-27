# page-bar-tabs

## Purpose

Tab-based page navigation for the designer page bar.

## Requirements

### Requirement: Tab-based page navigation
The designer page bar SHALL display pages as named tab buttons instead of dot indicators. Each tab SHALL show the page name as text. The active page tab SHALL be visually distinct from inactive tabs.

#### Scenario: Tabs display page names
- **WHEN** the designer has pages named "Control" and "Settings"
- **THEN** the page bar shows tab buttons labeled "Control" and "Settings"

#### Scenario: Active tab visual distinction
- **WHEN** page "Control" is active
- **THEN** the "Control" tab uses filled background with primary color
- **AND** the "Settings" tab uses outlined style with surface background

### Requirement: Tab tap switches page
The user SHALL be able to switch pages by tapping a tab. Tapping an inactive tab SHALL make it the active page.

#### Scenario: Tap inactive tab
- **WHEN** user taps the "Settings" tab while "Control" is active
- **THEN** "Settings" becomes the active page
- **AND** the tab bar updates to show "Settings" as the active tab

### Requirement: Tab long-press context menu
The user SHALL be able to long-press a tab to open a context menu with rename, duplicate, and delete options. This replaces the previous long-press behavior on dot indicators.

#### Scenario: Long-press opens context menu
- **WHEN** user long-presses a tab
- **THEN** a bottom sheet appears with "Rename Page", "Duplicate Page", and "Delete Page" options

### Requirement: Add page button
The page bar SHALL include a "+" button to add a new page. A new tab SHALL appear after clicking it.

#### Scenario: Add new page
- **WHEN** user taps the "+" button
- **THEN** a new page is added after the current page
- **AND** a new tab appears with an auto-generated name

### Requirement: Tab overflow scrolling
When there are too many pages to fit in the bar, the tabs SHALL be horizontally scrollable using SingleChildScrollView.

#### Scenario: Many pages overflow
- **WHEN** there are more than 5 pages
- **THEN** the tabs row is horizontally scrollable
- **AND** the active tab is scrolled into view

### Requirement: Chevron navigation
Left and right chevron buttons SHALL remain for navigating between pages. The left chevron SHALL be disabled on the first page, and the right chevron SHALL be disabled on the last page.

#### Scenario: Chevron navigation
- **WHEN** user taps the right chevron
- **THEN** the next page becomes active
- **AND** the corresponding tab scrolls into view
