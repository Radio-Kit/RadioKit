## Why

A live-vs-design check of the RC_UI control surface found that buttons render content that was never specified in the design: text-only buttons (e.g. `start_button` with START/STOP labels) show a generic power icon, and icon-only buttons (e.g. `left_indicator`/`right_indicator`/`horn_button`) show a default "ON"/"OFF" text label. The button OFF state must be an optional override — when the OFF icon/text is not defined, the ON icon/text (or whatever subset is defined) is shown in the OFF state too, and a button may be text-only, icon-only, or both — never a default icon.

## What Changes

- **RKButton rendering** (`flutter-widgets/lib/src/widgets/button/rk_button.dart`):
  - Remove the `Icons.power_settings_new_rounded` default fallback — a button renders an icon only when an icon is actually defined for the current state.
  - Render the button body from whatever combination is defined: icon-only, text-only, or icon + text (icon stacked above text). No content only occurs when neither text nor icon exists in either state.
  - Keep (and clarify) the OFF-override semantics: when both the OFF icon and OFF text are undefined, the ON state icon and text are used for the OFF state; when either OFF field is defined it overrides that field.
- **Button definition defaults** (`flutter-widgets/lib/src/widgets/definitions/button_definitions.dart`):
  - Stop defaulting `onText`/`offText` to `'ON'`/`'OFF'` when the property is absent or empty — pass through the actual value so empty text stays empty (icon-only buttons).
- **Multi-button / multi-select**: verify `RKToggleItem` (already implements per-item OFF override semantics) is covered by tests; no behavior change expected.
- **Tests**: widget tests for RKButton covering text-only, icon-only, both, empty OFF text, and the OFF→ON fallback.

## Capabilities

### New Capabilities
- `button-state-rendering`: how a button widget derives its ON/OFF icon and text from the defined properties — OFF fields act as optional overrides, fall back to ON fields when undefined, and the button body renders icon-only/text-only/both without injecting default icons or labels.

### Modified Capabilities

## Impact

- `flutter-widgets/lib/src/widgets/button/rk_button.dart` — content builder (`_buildContent`)
- `flutter-widgets/lib/src/widgets/definitions/button_definitions.dart` — button `buildCanvasWidget` defaults
- `flutter-widgets/test/` — RKButton widget tests
- Rendered by both the designer canvas and the control UI (shared `WidgetDefinition`)
