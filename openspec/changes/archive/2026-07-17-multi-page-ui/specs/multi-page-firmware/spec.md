## ADDED Requirements

### Requirement: RadioKit.setActivePage() API
The Arduino library SHALL provide RadioKit.setActivePage(uint8_t page) to switch the active page, handling protocol responses automatically.

#### Scenario: Manual page switch via API
- **WHEN** the user calls RadioKit.setActivePage(2)
- **THEN** the library sets activePage to 2
- **AND** the library sends CMD_PAGE_CHANGED(2) to connected transports
- **AND** the library sends CONF_DATA for page 2
- **AND** the library sends VAR_DATA for page 2

### Requirement: RadioKit.activePage getter
The Arduino library SHALL expose RadioKit.activePage as a read-only getter returning the current active page index.

#### Scenario: Read active page
- **WHEN** the user reads RadioKit.activePage
- **THEN** it returns the current active page index (0-based)

### Requirement: Automatic SET_PAGE handling
The Arduino library SHALL automatically handle incoming CMD_SET_PAGE commands in RadioKit.update() without user intervention.

#### Scenario: App-initiated page switch
- **WHEN** the MCU receives CMD_SET_PAGE(1) from the app
- **THEN** the library sets activePage to 1
- **AND** the library sends CMD_PAGE_CHANGED(1) back
- **AND** the library sends CONF_DATA and VAR_DATA for page 1

### Requirement: Page index gating for widget communication
The Arduino library SHALL only send and receive widget data for the active page.

#### Scenario: Inactive page widgets are silent
- **WHEN** activePage is 0
- **AND** page 1 has widgets with changed values
- **THEN** the library does not send VAR_UPDATE for page 1 widgets
- **AND** the library ignores SET_INPUT for page 1 widgets

### Requirement: Page names storage
The Arduino library SHALL store page names in a const char* array accessible via RadioKit.pageNames.

#### Scenario: Access page names
- **WHEN** the user reads RadioKit.pageNames[0]
- **THEN** it returns the name of the first page

### Requirement: Page count storage
The Arduino library SHALL store the total page count in RadioKit.numPages.

#### Scenario: Access page count
- **WHEN** the user reads RadioKit.numPages
- **THEN** it returns the total number of pages
