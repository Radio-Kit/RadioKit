## ADDED Requirements

### Requirement: Multi-pack icon resolution
The system SHALL resolve icon name strings to `IconData` through a single shared registry (`kDesignerIcons` in `flutter-widgets/lib/src/utils/icon_registry.dart`) that aggregates icons from two packs — Phosphor (fill weight) for general-purpose glyphs and SimpleIcons for brand/auto logos. The registry SHALL expose `iconFromName(String?)` returning `IconData?`.

#### Scenario: Resolving a Phosphor fill icon by name
- **WHEN** `iconFromName('steering-wheel')` is called
- **THEN** it returns the Phosphor fill glyph `PhosphorIconsFill.steeringWheel`

#### Scenario: Former Lucide keys resolve to Phosphor fill equivalents
- **WHEN** `iconFromName('zap')` is called
- **THEN** it returns the Phosphor fill glyph `PhosphorIconsFill.lightning` (keys are unchanged; only the glyph source changed)
- **AND** the same applies to all other former Lucide keys (e.g. `settings` → `gearSix`, `home` → `house`, `search` → `magnifyingGlass`)

#### Scenario: Unknown icon name falls back safely
- **WHEN** `iconFromName` is called with a name that is not a key in `kDesignerIcons` (or with `null`)
- **THEN** it returns `null`
- **AND** callers render their default fallback icon without error

### Requirement: Phosphor fill icon set
The registry SHALL include the 26 Phosphor fill icons requested for designer widgets, keyed by their kebab-case names: `caret-left`, `caret-right`, `siren`, `headlights`, `arrow-fat-left`, `arrow-fat-right`, `warning`, `fallout-shelter`, `biohazard`, `radioactive`, `lightbulb-filament`, `lighthouse`, `lightning`, `fire`, `subway`, `cable-car`, `ghost`, `car-simple`, `megaphone`, `steering-wheel`, `rewind`, `fast-forward`, `bell`, `bell-ringing`, `cat`, `charging-station`. Each key SHALL resolve to the corresponding `PhosphorIconsFill` constant.

#### Scenario: All requested Phosphor icons resolve to fill glyphs
- **WHEN** each of the 26 kebab-case names listed above is looked up in `kDesignerIcons`
- **THEN** each resolves to the corresponding `PhosphorIconsFill` constant

### Requirement: Lucide replacement set
The registry SHALL contain no Lucide entries. Every key formerly mapped to a Lucide glyph SHALL resolve to a Phosphor fill equivalent under the same key name, so stored icon-name strings continue to resolve without schema or config changes.

#### Scenario: No Lucide glyphs remain in the registry
- **WHEN** a key formerly mapped to Lucide (e.g. `zap`, `battery-charging`, `play`, `trash-2`) is looked up
- **THEN** it resolves to a `PhosphorIconsFill` glyph, not a Lucide glyph
- **AND** `flutter-widgets` no longer depends on `lucide_icons_flutter`

### Requirement: Icon picker discovers registry entries automatically
The designer icon picker SHALL derive its icon list from `kDesignerIcons` at runtime (iterating its keys with case-insensitive substring search), so that icons added to the registry appear in the picker without UI changes.

#### Scenario: New Phosphor icons appear in the picker
- **WHEN** a user opens the designer icon picker and searches for `steering-wheel`
- **THEN** the Phosphor fill steering-wheel icon is listed and selectable
- **AND** selecting it stores the name string `steering-wheel` for serialization
