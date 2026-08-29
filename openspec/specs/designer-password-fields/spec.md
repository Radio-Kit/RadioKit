# designer-password-fields Specification

## Purpose
TBD - created by archiving change fix-ble-features-tabs. Update Purpose after archive.
## Requirements
### Requirement: Designer Inspector Shows Device Password Field in MODEL Section
The designer inspector SHALL display a device password text field in the MODEL section, below the Type selector. The field SHALL always be visible regardless of whether a password is currently set. The field SHALL be labeled "Password" and include a visibility toggle icon.

#### Scenario: Device has no password set
- **WHEN** the user opens the designer inspector on a config with no device password
- **THEN** the password text field is visible and empty, with placeholder text "leave empty for no password"

#### Scenario: Device has a password set
- **WHEN** the user opens the designer inspector on a config with a device password set
- **THEN** the password text field is visible and pre-filled with the current password value (obscured by default)

#### Scenario: User clears the password
- **WHEN** the user clears the password field and saves
- **THEN** the config is saved with an empty password, removing device-level authentication

### Requirement: Designer Inspector Shows User Password Field Conditionally
The designer inspector SHALL display a user password text field in the MODEL section, below the device password field, ONLY when the device password field is non-empty. The field SHALL be labeled "User Password" and include a visibility toggle icon.

#### Scenario: Device password is empty
- **WHEN** the user opens the designer inspector on a config with no device password set
- **THEN** the user password field is NOT visible

#### Scenario: Device password is set, no user password
- **WHEN** the user sets a device password (non-empty) on a config with no user password
- **THEN** the user password text field appears below the device password field, empty, with placeholder text "Widget-only access password"

#### Scenario: Device password and user password both set
- **WHEN** the user opens the designer inspector on a config with both passwords set
- **THEN** both password fields are visible, each pre-filled with their current values (obscured by default)

#### Scenario: User clears device password
- **WHEN** the user clears the device password field (sets to empty)
- **THEN** the user password field is hidden, regardless of whether a user password was previously set

### Requirement: Designer Codegen Generates User Password
The Arduino codegen SHALL generate `RadioKit.config.user_password = "<value>"` when the user password field is non-empty.

#### Scenario: User password is set
- **WHEN** the designer config has a non-empty user password
- **THEN** the generated `RADIOKIT.h` file contains `RadioKit.config.user_password = "<value>";`

#### Scenario: User password is empty
- **WHEN** the designer config has an empty user password
- **THEN** the generated `RADIOKIT.h` file does NOT contain a `user_password` line

### Requirement: Designer State Serializes User Password
The designer state SHALL include a `userPassword` field that is serialized to and deserialized from the designer JSON config format under `config.user_password`.

#### Scenario: Save includes user password
- **WHEN** the designer saves a config with a user password set
- **THEN** the JSON output includes `"config": { "user_password": "<value>" }`

#### Scenario: Load reads user password
- **WHEN** the designer loads a JSON config containing `"config": { "user_password": "<value>" }`
- **THEN** the `userPassword` state field is populated with the value

### Requirement: Designer Header Parser Reads User Password
The header file parser SHALL read the `userPassword` field from the designer JSON config when importing existing firmware configs.

#### Scenario: Import config with user password
- **WHEN** the user imports a config JSON containing `"config": { "user_password": "<value>" }`
- **THEN** the designer state's `userPassword` field is set to the value

#### Scenario: Import config without user password
- **WHEN** the user imports a config JSON without a `user_password` key
- **THEN** the designer state's `userPassword` field defaults to empty string

