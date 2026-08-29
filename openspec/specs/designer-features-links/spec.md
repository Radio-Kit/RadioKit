# designer-features-links Specification

## Purpose
TBD - created by archiving change fix-ble-features-tabs. Update Purpose after archive.
## Requirements
### Requirement: FS URL Field Shown Under Filesystem Toggle
The designer inspector SHALL display the FS URL text field directly below the "Enable Filesystem" toggle in the FEATURES section, only when the filesystem feature is enabled. The field SHALL NOT be visible when filesystem is disabled.

#### Scenario: Filesystem enabled
- **WHEN** the user toggles "Enable Filesystem" to true in the FEATURES section
- **THEN** an FS URL text field appears below the toggle with label "FS URL" and helper text "GitHub repository or subfolder for LittleFS assets"

#### Scenario: Filesystem disabled
- **WHEN** the user toggles "Enable Filesystem" to false in the FEATURES section
- **THEN** the FS URL text field is hidden

#### Scenario: FS URL retains value when toggled off
- **WHEN** the user sets an FS URL, then toggles "Enable Filesystem" off, then back on
- **THEN** the FS URL field reappears with the previously entered value preserved

### Requirement: OTA URL Field Shown Under OTA Toggle
The designer inspector SHALL display the OTA URL text field directly below the "Enable OTA" toggle in the FEATURES section, only when the OTA feature is enabled. The field SHALL NOT be visible when OTA is disabled.

#### Scenario: OTA enabled
- **WHEN** the user toggles "Enable OTA" to true in the FEATURES section
- **THEN** an OTA URL text field appears below the toggle with label "OTA URL" and helper text "OTA firmware update URL (placeholder)"

#### Scenario: OTA disabled
- **WHEN** the user toggles "Enable OTA" to false in the FEATURES section
- **THEN** the OTA URL text field is hidden

#### Scenario: OTA URL retains value when toggled off
- **WHEN** the user sets an OTA URL, then toggles "Enable OTA" off, then back on
- **THEN** the OTA URL field reappears with the previously entered value preserved

### Requirement: Remote Links Section Removed
The standalone "REMOTE LINKS" section in the designer inspector SHALL be removed. The FS URL and OTA URL fields are now part of the FEATURES section.

#### Scenario: No separate remote links section
- **WHEN** the user opens the designer inspector
- **THEN** there is no standalone "REMOTE LINKS" section — the FS URL and OTA URL fields appear within the FEATURES section under their respective toggles

