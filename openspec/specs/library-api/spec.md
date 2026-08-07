## ADDED Requirements

### Requirement: Library version endpoint
The system SHALL expose `GET /api/library/version` returning the Arduino library version as JSON.

#### Scenario: Version query returns current version
- **WHEN** agent sends `GET /api/library/version`
- **THEN** system responds with `{"version": "<semver>"}` and content-type `application/json`

#### Scenario: Version is extracted from bundled library
- **WHEN** the app starts
- **THEN** `LibraryService` extracts `rk-arduino.zip` to the app documents directory (if not already extracted)
- **AND** reads `library.json` from the extracted files to populate the version

### Requirement: Library download endpoint
The system SHALL expose `GET /api/library/download` serving the full Arduino library as a ZIP archive.

#### Scenario: Download returns ZIP bytes
- **WHEN** agent sends `GET /api/library/download`
- **THEN** system responds with `application/zip` content-type
- **AND** response body contains the ZIP archive of the `rk-arduino/` library

#### Scenario: Download includes all library files
- **WHEN** agent extracts the downloaded ZIP
- **THEN** the archive contains `src/`, `library.json`, `library.properties`, and all other library files matching the `rk-arduino/` directory structure

### Requirement: Build script creates library ZIP
The system SHALL include a build script that creates `radiokit-app/assets/rk-arduino.zip` from the `rk-arduino/` directory.

#### Scenario: Build script produces valid ZIP
- **WHEN** developer runs the build script from the repo root
- **THEN** `radiokit-app/assets/rk-arduino.zip` is created or updated
- **AND** the ZIP contains the full `rk-arduino/` directory tree

### Requirement: LibraryService initialization
The system SHALL initialize `LibraryService` at app startup so version and download endpoints are available immediately.

#### Scenario: Service extracts on first access
- **WHEN** `LibraryService` is first accessed
- **THEN** it extracts `assets/rk-arduino.zip` to `getApplicationDocumentsDirectory()/rk-arduino/`
- **AND** reads version from the extracted `library.json`

#### Scenario: Service reuses existing extraction
- **WHEN** `LibraryService` is accessed and the extraction directory already exists
- **THEN** it reads version from the existing `library.json` without re-extracting
