## ADDED Requirements

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
