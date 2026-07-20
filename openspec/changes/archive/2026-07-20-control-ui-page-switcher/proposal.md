## Why

The current control UI uses dot indicators for page switching, which don't show page names and require swiping or tapping small dots. Users need a clearer, more accessible way to switch between pages — especially with 3+ pages where dot indicators become hard to distinguish. A tab-style page switcher (like the designer's page bar) provides named tabs that are immediately readable and tappable.

## What Changes

- Replace the dot-indicator `PageSwitcher` in the control screen with a tab-style page bar showing page names
- Add a designer config option (`showControlPageBar`) to enable/disable the page bar in the control UI
- The page bar is hidden when `numPages <= 1` (same as current behavior)
- The page bar respects the `showControlPageBar` toggle from the designer config
- Page names come from `_pageNames` (device-provided) with fallback to "Page N"

## Capabilities

### New Capabilities
- `control-page-switcher`: Tab-style page switcher in the control UI with configurable visibility

### Modified Capabilities

## Impact

- `radiokit-app/lib/screens/control_ui/page_switcher.dart` — rewrite from dots to tabs
- `radiokit-app/lib/screens/control_ui/control_screen.dart` — pass showControlPageBar config
- `flutter-widgets/lib/src/models/designer_state.dart` — add `showControlPageBar` field + serialization
- `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` — add toggle in CONTROL UI section
- JSON config schema — new `canvas.showControlPageBar` field
- Codegen — emit `showControlPageBar` in config comment block
