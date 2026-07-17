## ADDED Requirements

### Requirement: CMD_SET_PAGE command
The protocol SHALL support a CMD_SET_PAGE (0x20) command for app-to-MCU page switching with payload [PAGE_INDEX(1)].

#### Scenario: App sends SET_PAGE
- **WHEN** the app sends CMD_SET_PAGE with page index N
- **AND** N is within the valid page range
- **THEN** the MCU sets activePage to N
- **AND** the MCU responds with CMD_PAGE_CHANGED(N)
- **AND** the MCU sends CONF_DATA for page N
- **AND** the MCU sends VAR_DATA for page N

#### Scenario: App sends SET_PAGE with invalid index
- **WHEN** the app sends CMD_SET_PAGE with page index N
- **AND** N is outside the valid page range
- **THEN** the MCU sends CMD_PAGE_CHANGED with the current active page index

### Requirement: CMD_PAGE_CHANGED command
The protocol SHALL support a CMD_PAGE_CHANGED (0x21) command for MCU-to-App page switch acknowledgment with payload [PAGE_INDEX(1)].

#### Scenario: MCU acknowledges page switch
- **WHEN** the MCU receives CMD_SET_PAGE or the user calls setActivePage()
- **THEN** the MCU sends CMD_PAGE_CHANGED with the new active page index

### Requirement: CMD_GET_PAGES command
The protocol SHALL support a CMD_GET_PAGES (0x22) command for app-to-MCU page metadata request.

#### Scenario: App requests page list
- **WHEN** the app sends CMD_GET_PAGES
- **THEN** the MCU responds with CMD_PAGES_DATA containing all page names

### Requirement: CMD_PAGES_DATA command
The protocol SHALL support a CMD_PAGES_DATA (0x23) command for MCU-to-App page metadata with payload [NUM_PAGES(1)] followed by per-page [NAME_LEN(1)][NAME(NAME_LEN)].

#### Scenario: MCU returns page metadata
- **WHEN** the MCU receives CMD_GET_PAGES
- **THEN** the MCU sends CMD_PAGES_DATA with the number of pages and each page's name

### Requirement: CMD_PAGE_SWITCH command
The protocol SHALL support a CMD_PAGE_SWITCH (0x24) command for MCU-to-App device-initiated page switch with payload [PAGE_INDEX(1)].

#### Scenario: Device switches page via hardware
- **WHEN** the MCU switches pages due to a physical button press or serial command
- **THEN** the MCU sends CMD_PAGE_SWITCH with the new page index
- **AND** the MCU sends CONF_DATA for the new page
- **AND** the MCU sends VAR_DATA for the new page

### Requirement: Page prefix in VAR_UPDATE
The protocol SHALL include a page index prefix byte in CMD_VAR_UPDATE (0x08) packets: [PAGE_INDEX(1)] [WIDGET_ID(1)] [SEQ(1)] [VALUES...].

#### Scenario: VAR_UPDATE includes page context
- **WHEN** the MCU sends a VAR_UPDATE for widget 1 on page 2
- **THEN** the packet contains [0x02][0x01][SEQ][VALUES]

#### Scenario: App ignores stale VAR_UPDATE
- **WHEN** the app is in PAGE_PENDING state (after sending SET_PAGE)
- **AND** a VAR_UPDATE arrives for the old page
- **THEN** the app discards the VAR_UPDATE

### Requirement: Page prefix in SET_INPUT
The protocol SHALL include a page index prefix byte in CMD_SET_INPUT (0x0C) packets: [PAGE_INDEX(1)] [WIDGET_ID(1)] [VALUES...].

#### Scenario: SET_INPUT includes page context
- **WHEN** the app sends a SET_INPUT for widget 1 on page 2
- **THEN** the packet contains [0x02][0x01][VALUES]

### Requirement: ACTIVE_PAGE in CONF_DATA header
The protocol SHALL include ACTIVE_PAGE and NUM_PAGES in the CONF_DATA global header: [ORIENTATION(1)] [NUM_WIDGETS(1)] [ACTIVE_PAGE(1)] [NUM_PAGES(1)] [THEME_LEN(1)] [THEME...].

#### Scenario: CONF_DATA includes page context
- **WHEN** the MCU sends CONF_DATA for page 2 of a 5-page config
- **THEN** the header contains ACTIVE_PAGE=2 and NUM_PAGES=5

#### Scenario: App syncs page on reconnect
- **WHEN** the app reconnects and receives CONF_DATA
- **THEN** the app reads ACTIVE_PAGE from the header
- **AND** the app sets its active page to match the MCU

### Requirement: Page switch state machine
The app SHALL maintain a page switch state machine with states IDLE and PAGE_PENDING.

#### Scenario: Enter PAGE_PENDING on SET_PAGE
- **WHEN** the app sends CMD_SET_PAGE
- **THEN** the app enters PAGE_PENDING state
- **AND** the app discards any VAR_UPDATE or CONF_DATA until PAGE_CHANGED

#### Scenario: Return to IDLE on PAGE_CHANGED
- **WHEN** the app receives CMD_PAGE_CHANGED
- **THEN** the app returns to IDLE state
- **AND** the app applies the new CONF_DATA and VAR_DATA
