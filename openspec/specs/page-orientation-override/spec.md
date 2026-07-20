# Page Orientation Override

Purpose: TBD

## Requirements

### Requirement: Per-page orientation override
Each page in a multi-page design SHALL have an orientation override field that can be "global" (inherit from CONTROL UI), "landscape" (force), or "portrait" (force). The default for new pages SHALL be "global".

#### Scenario: Effective orientation from override
- **WHEN** a page has orientation override "global"
- **THEN** the effective orientation matches the CONTROL UI global orientation setting

#### Scenario: Force landscape override
- **WHEN** a page has orientation override "landscape"
- **THEN** the effective orientation is landscape regardless of global setting

#### Scenario: Force portrait override
- **WHEN** a page has orientation override "portrait"
- **THEN** the effective orientation is portrait regardless of global setting

### Requirement: Orientation override serialization
The orientation override SHALL be serialized in the JSON config as `"orientation": "global" | "landscape" | "portrait"`. When the field is omitted, it defaults to "global".

#### Scenario: Save override to JSON
- **WHEN** a page has orientation override set to "portrait"
- **THEN** the JSON contains `"orientation": "portrait"` for that page

#### Scenario: Load override from JSON
- **WHEN** a JSON config has `"orientation": "global"` for a page
- **THEN** the page's orientation override is set to "global"

#### Scenario: Missing field defaults to global
- **WHEN** a JSON config omits the "orientation" field for a page
- **THEN** the page's orientation override defaults to "global"

### Requirement: Canvas size from effective orientation
The designer canvas dimensions SHALL be determined by the effective orientation: landscape = 200x100, portrait = 100x200.

#### Scenario: Landscape canvas dimensions
- **WHEN** a page's effective orientation is landscape
- **THEN** the canvas is 200 units wide and 100 units tall

#### Scenario: Portrait canvas dimensions
- **WHEN** a page's effective orientation is portrait
- **THEN** the canvas is 100 units wide and 200 units tall

### Requirement: Tab indicator for overridden pages
Page bar tabs SHALL display a small rotation indicator badge when the page has a non-global orientation override.

#### Scenario: Badge shown for forced orientation
- **WHEN** a page has orientation override "landscape" or "portrait"
- **THEN** the tab shows a rotation indicator badge

#### Scenario: Badge hidden for global orientation
- **WHEN** a page has orientation override "global" or null
- **THEN** the tab does not show a rotation indicator badge

### Requirement: Control screen orientation re-lock
When the user switches pages in the control screen, the phone's system orientation SHALL be re-locked to match the new page's effective orientation.

#### Scenario: Page switch updates phone orientation
- **WHEN** user switches from a landscape page to a portrait page in the control screen
- **THEN** the phone's system orientation is locked to portrait

#### Scenario: Same orientation no-op
- **WHEN** user switches between two pages with the same effective orientation
- **THEN** the phone's system orientation remains unchanged
