## ADDED Requirements

### Requirement: Starter templates displayed when no paired models exist
The Models tab SHALL display a `STARTER_TEMPLATES` section containing starter templates whenever the user has no paired models.

#### Scenario: No paired models in history
- **WHEN** the user opens the Models tab and `pairedDevices` is empty
- **THEN** the `STARTER_TEMPLATES` section is rendered displaying the available starter template cards

#### Scenario: User has paired models
- **WHEN** the user opens the Models tab and has one or more paired models in history
- **THEN** the paired models list is displayed and the starter templates section on the Models tab is hidden

### Requirement: Tapping starter template opens UI preview
Tapping a starter template card from the Models tab SHALL navigate to the Designer preview for that template in interactive play mode.

#### Scenario: User taps starter template card
- **WHEN** user taps a starter template card
- **THEN** the app navigates to `/designer` with the template JSON and model name preloaded

### Requirement: Removal of legacy demo settings and section
The application SHALL NOT display the legacy `INTERACTIVE_DEMO` section or the `ENABLE_DEMO` setting toggle.

#### Scenario: System settings inspection
- **WHEN** user navigates to the System tab
- **THEN** no `ENABLE_DEMO` toggle switch is present
