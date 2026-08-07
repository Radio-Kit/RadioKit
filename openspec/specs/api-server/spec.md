# Docs API

## Purpose

Serve firmware documentation and API reference through the app's REST API, enabling AI agents to discover and read documentation at runtime.
## Requirements
### Requirement: Docs index endpoint

The system SHALL serve a JSON index of all available documentation at `GET /api/docs`.

#### Scenario: List all available docs

- **WHEN** agent sends `GET /api/docs`
- **THEN** server responds with `{"skills": [{"name": "radiokit-firmware", "description": "...", "path": "/api/docs/radiokit-firmware"}, ...]}` listing all SKILLS files

#### Scenario: Empty index when no docs

- **WHEN** agent sends `GET /api/docs` and no SKILLS files exist
- **THEN** server responds with `{"skills": []}`

### Requirement: Individual doc retrieval

The system SHALL serve individual skill documentation at `GET /api/docs/<skill>`.

#### Scenario: Read specific skill doc

- **WHEN** agent sends `GET /api/docs/radiokit-firmware`
- **THEN** server responds with `{"name": "radiokit-firmware", "description": "...", "content": "<markdown content>", "size": 4521}`

#### Scenario: Request non-existent skill

- **WHEN** agent sends `GET /api/docs/nonexistent`
- **THEN** server responds with `{"error": "not_found", "message": "Skill not found: nonexistent"}` and HTTP 404

### Requirement: API schema endpoint

The system SHALL serve the REST API surface as JSON Schema at `GET /api/docs/api-schema`.

#### Scenario: Get API schema

- **WHEN** agent sends `GET /api/docs/api-schema`
- **THEN** server responds with a JSON object containing all registered routes with their HTTP methods, paths, parameter schemas, and descriptions

#### Scenario: Schema includes all endpoint groups

- **WHEN** agent requests the API schema
- **THEN** response includes connection, widgets, filesystem, OTA, console, NVS, transport, and flasher endpoints

### Requirement: Documentation cached at startup

The system SHALL read SKILLS/ files once at server startup and serve from memory cache.

#### Scenario: Docs available immediately after server start

- **WHEN** server starts
- **THEN** all SKILLS/ files are cached and available via `/api/docs`

#### Scenario: Large doc content preserved

- **WHEN** a SKILLS file contains 15KB of markdown
- **THEN** the full content is returned without truncation

### Requirement: LLM discovery endpoint

The system SHALL serve an `llms.txt` file at the server root (`GET /`) for LLM discovery.

#### Scenario: LLM reads root URL

- **WHEN** agent sends `GET /`
- **THEN** server responds with `text/plain` content describing the API surface and available documentation endpoints

### Requirement: Design JSON endpoint

The system SHALL serve the designer JSON config for a specific design at `GET /api/designs/<id>/json`.

#### Scenario: Get design JSON by ID

- **WHEN** agent sends `GET /api/designs/abc123/json`
- **THEN** server responds with the full designer JSON config object (version, config, canvas, widgets)

#### Scenario: Design not found

- **WHEN** agent sends `GET /api/designs/nonexistent/json`
- **THEN** server responds with `{"error": "not_found", "message": "Design not found: nonexistent"}` and HTTP 404

### Requirement: Design header file endpoint

The system SHALL generate and serve the Arduino `.h` file content for a specific design at `GET /api/designs/<id>/header`.

#### Scenario: Generate header file

- **WHEN** agent sends `GET /api/designs/abc123/header`
- **THEN** server responds with `text/plain` content containing the complete RADIOKIT.h file (JSON config comment block + widget declarations + initRadioKit function)

#### Scenario: Design not found for header

- **WHEN** agent sends `GET /api/designs/nonexistent/header`
- **THEN** server responds with HTTP 404

#### Scenario: Design has no JSON content

- **WHEN** agent sends `GET /api/designs/abc123/header` and the design has `jsonContent: null` (file-mode entry)
- **THEN** server responds with `{"error": "no_content", "message": "Design has no JSON content"}` and HTTP 400

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

### Requirement: Direct LAN accessibility over HTTP

The Remote Access API server SHALL be accessible to any device on the local network (LAN) over HTTP on port 7007 without requiring USB ADB port forwarding.

#### Scenario: LAN client accesses status endpoint directly

- **WHEN** a client on the local network sends `GET http://<android-ip>:7007/api/status`
- **THEN** server responds with `200 OK` and server status JSON containing version, uptime, port 7007, and localIp

#### Scenario: Android manifest allows cleartext HTTP

- **WHEN** Android app is compiled in release mode and starts Remote Access server
- **THEN** Android OS Network Security Policy allows incoming unencrypted HTTP traffic on port 7007

### Requirement: Native Android Wi-Fi and Multicast Lock

The system SHALL acquire high-performance Wi-Fi lock and Multicast lock on Android while the Remote Access server is active.

#### Scenario: Server start acquires Wi-Fi lock

- **WHEN** Remote Access server is started on Android
- **THEN** native MethodChannel acquires `WifiManager.WifiLock` (HIGH_PERF) and `WifiManager.MulticastLock` to prevent Wi-Fi chip power-saving sleep

#### Scenario: Server stop releases Wi-Fi lock

- **WHEN** Remote Access server is stopped on Android
- **THEN** native MethodChannel releases `WifiLock` and `MulticastLock`

