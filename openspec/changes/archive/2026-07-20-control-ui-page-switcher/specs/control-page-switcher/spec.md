## ADDED Requirements

### Requirement: Tab-style page switcher in control UI
The control screen SHALL display a tab-style page switcher bar above the widget canvas when multiple pages exist and the feature is enabled.

#### Scenario: Multiple pages with feature enabled
- **WHEN** the connected device has more than 1 page AND `showControlPageBar` is true
- **THEN** the control screen displays a horizontal tab bar above the widget canvas
- **AND** each tab shows the page name as a label
- **AND** the active page tab is visually highlighted (primary color background)
- **AND** inactive page tabs show a surface color background

#### Scenario: Single page
- **WHEN** the connected device has exactly 1 page
- **THEN** the page switcher bar is not rendered

#### Scenario: Feature disabled
- **WHEN** `showControlPageBar` is false
- **THEN** the page switcher bar is not rendered regardless of page count

#### Scenario: OTA in progress
- **WHEN** an OTA update is in progress
- **THEN** the page switcher bar is not rendered

### Requirement: Page tab tap triggers page switch
Tapping a page tab SHALL send the page switch command to the device and update the active page.

#### Scenario: Tap inactive tab
- **WHEN** user taps a tab for a page that is not currently active
- **THEN** the app sends `CMD_SET_PAGE` to the device with the selected page index
- **AND** haptic feedback is produced
- **AND** the tab bar updates to highlight the newly selected tab after `PAGE_CHANGED` response

#### Scenario: Tap active tab
- **WHEN** user taps the tab for the currently active page
- **THEN** no page switch command is sent

### Requirement: Page switcher shows device-provided page names
The page switcher SHALL display page names from the device with a fallback.

#### Scenario: Device provides page names
- **WHEN** the device has sent page names via `CMD_PAGES_DATA`
- **THEN** each tab displays the corresponding page name

#### Scenario: No page names available
- **WHEN** page names have not been received from the device
- **THEN** tabs display "Page 1", "Page 2", etc. as fallback labels

### Requirement: showControlPageBar designer config toggle
The designer inspector CONTROL UI section SHALL include a toggle for `showControlPageBar`.

#### Scenario: Toggle visible in designer
- **WHEN** the user opens the CONTROL UI section in the designer inspector
- **THEN** a "Show Page Bar in Control UI" boolean toggle is displayed

#### Scenario: Toggle defaults to true
- **WHEN** a new config is created
- **THEN** `showControlPageBar` defaults to true

#### Scenario: Toggle persists in JSON
- **WHEN** the user changes the toggle value
- **THEN** the value is serialized in `canvas.showControlPageBar` in the JSON config
- **AND** the value is restored when the config is reloaded

### Requirement: Page switcher visual style
The page switcher SHALL use a compact tab-button style matching the designer page bar height.

#### Scenario: Tab bar dimensions
- **WHEN** the page switcher is rendered
- **THEN** the bar height is 40px
- **AND** tabs are horizontally scrollable when they overflow
- **AND** the bar uses the device theme tokens for colors
