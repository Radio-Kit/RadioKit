# button-state-rendering Specification

## Purpose

The button widget renders exactly the icon and/or text defined for the current state — no default icon or default label is ever injected. OFF state fields are optional overrides that fall back to the ON state when both are undefined.

## Requirements

### Requirement: Button content derives from defined icon and text only

The button widget SHALL render exactly the icon and/or text defined for the current state and SHALL NOT inject default content. A button may be text-only, icon-only, or both; a default icon (such as a power icon) SHALL NOT be shown when no icon is defined, and a default label (such as "ON"/"OFF") SHALL NOT be shown when no text is defined.

#### Scenario: Text-only button renders no icon
- **WHEN** a button defines ON/OFF text but no icon in either state
- **THEN** the button renders the text only
- **AND** no default icon is displayed in either the ON or OFF state

#### Scenario: Icon-only button renders no text
- **WHEN** a button defines an icon but empty text in both states
- **THEN** the button renders the icon only
- **AND** no default "ON"/"OFF" label is displayed

#### Scenario: Button with icon and text renders both
- **WHEN** a button defines both an icon and text for a state
- **THEN** the button renders the icon above the text

### Requirement: OFF state fields act as an override with ON-state fallback

The OFF state icon and text SHALL be treated as optional overrides. When both the OFF icon and OFF text are undefined (absent or empty), the ON state icon and text SHALL be displayed in the OFF state. When either OFF field is defined, it SHALL override the corresponding ON field for the OFF state.

#### Scenario: OFF state fully undefined falls back to ON state
- **WHEN** a button has no OFF icon and no OFF text defined
- **THEN** the OFF state displays the ON state icon and ON state text

#### Scenario: OFF icon defined overrides icon only
- **WHEN** a button defines an OFF icon but no OFF text
- **THEN** the OFF state displays the OFF icon
- **AND** the OFF state does not fall back to the ON text unless defined

#### Scenario: OFF text defined overrides text only
- **WHEN** a button defines OFF text but no OFF icon
- **THEN** the OFF state displays the OFF text
- **AND** no default icon is displayed for the OFF state

### Requirement: Button definition passes empty text through

The button widget definition SHALL pass the configured `onText`/`offText` values through unchanged, defaulting to empty string when absent, so that empty labels remain empty instead of being replaced by built-in defaults.

#### Scenario: Empty labels stay empty
- **WHEN** a design specifies empty `onText`/`offText` for a button
- **THEN** the rendered button shows no text label

#### Scenario: New buttons keep default labels
- **WHEN** a new button is created in the designer
- **THEN** its default properties (`onText: "ON"`, `offText: "OFF"`) render as labels
