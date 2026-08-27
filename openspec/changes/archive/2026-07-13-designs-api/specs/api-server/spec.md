## ADDED Requirements

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
