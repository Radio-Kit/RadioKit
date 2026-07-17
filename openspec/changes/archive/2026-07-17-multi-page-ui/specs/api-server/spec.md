## ADDED Requirements

### Requirement: GET /api/page endpoint
The Remote Access API SHALL provide a GET /api/page endpoint returning the current active page index and page list.

#### Scenario: Get current page
- **WHEN** the app sends GET /api/page
- **THEN** the response contains { "page": N, "pages": [...] }

### Requirement: POST /api/page endpoint
The Remote Access API SHALL provide a POST /api/page endpoint to switch the active page.

#### Scenario: Switch page via API
- **WHEN** the app sends POST /api/page with { "page": N }
- **THEN** the device switches to page N
- **AND** the response contains { "page": N }

### Requirement: GET /api/pages endpoint
The Remote Access API SHALL provide a GET /api/pages endpoint returning the list of all page names.

#### Scenario: Get page list
- **WHEN** the app sends GET /api/pages
- **THEN** the response contains [{ "index": 0, "name": "Controls" }, ...]

### Requirement: Follow mode page route
The Remote Access follow mode SHALL map page-switch API paths to the control screen route.

#### Scenario: Page switch follows in remote app
- **WHEN** a remote app sends POST /api/page
- **THEN** the follow mode navigates the local app to /control with the correct page
