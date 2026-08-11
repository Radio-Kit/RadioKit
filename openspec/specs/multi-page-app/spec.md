## ADDED Requirements

### Requirement: Page switcher widget in control mode
The Flutter app SHALL display a page switcher with centered chevrons, dot indicators, and page name in play/control mode.

#### Scenario: Page switcher renders in control mode
- **WHEN** the user is in control mode with a multi-page device
- **THEN** the page switcher appears with navigation controls

#### Scenario: Tap chevron switches page
- **WHEN** the user taps the right chevron
- **THEN** the app sends CMD_SET_PAGE for the next page
- **AND** the app enters PAGE_PENDING state

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

### Requirement: Page sync on reconnect
The Flutter app SHALL sync its active page with the MCU on connection by reading ACTIVE_PAGE from CONF_DATA header.

#### Scenario: Reconnect syncs page
- **WHEN** the app reconnects to a device
- **AND** the MCU is on page 2
- **THEN** the app receives CONF_DATA with ACTIVE_PAGE=2
- **AND** the app sets its active page to 2

### Requirement: Page switch state machine
The Flutter app SHALL maintain a page switch state machine (IDLE, PAGE_PENDING) to handle timing of page transitions.

#### Scenario: Discard stale data during page switch
- **WHEN** the app sends SET_PAGE and enters PAGE_PENDING
- **AND** a VAR_UPDATE arrives for the old page
- **THEN** the app discards the stale VAR_UPDATE

#### Scenario: Apply data after PAGE_CHANGED
- **WHEN** the app receives CMD_PAGE_CHANGED
- **THEN** the app returns to IDLE state
- **AND** the app applies the new CONF_DATA and VAR_DATA

### Requirement: Canvas resize on page switch
The Flutter app SHALL instantly resize the canvas when switching between pages with different orientations.

#### Scenario: Landscape to portrait switch
- **WHEN** the user switches from a landscape page to a portrait page
- **THEN** the canvas instantly resizes from 200x100 to 100x200

### Requirement: Follow mode page sync
The Flutter app SHALL sync page switches in follow mode so remote navigation matches device state.

#### Scenario: Device page switch follows in local app
- **WHEN** the device switches pages via CMD_PAGE_SWITCH
- **THEN** the local app's page switcher updates to show the new page
