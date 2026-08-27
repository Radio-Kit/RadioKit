## Why

The current page bar in the designer uses dot indicators that are hard to read and don't clearly communicate which page is active. Users need a more recognizable tab-based navigation pattern similar to Material tabs. Additionally, some users prefer a cleaner canvas without the page bar visible, so we need a toggle to show/hide it.

## What Changes

- Replace dot indicators in `DesignerPageBar` with tab-style buttons showing page names directly
- Add a toggle button in the designer toolbar to show/hide the page bar
- Store the page bar visibility preference in `DesignerState`
- Persist the visibility setting in the JSON config

## Capabilities

### New Capabilities

- `page-bar-tabs`: Tab-based page navigation in the designer with page names displayed as clickable tabs instead of numbered dots
- `page-bar-visibility`: Toggle to show/hide the page bar in the designer UI, persisted in design config

### Modified Capabilities

<!-- None — this is purely new UI behavior -->

## Impact

- **Flutter App (Designer)**: `DesignerPageBar` widget rewrite, `DesignerState` additions, `designer_screen.dart` toolbar update
- **JSON Config**: New `showPageBar` field in canvas config (backward compatible — defaults to `true`)
- **Control Screen**: `PageSwitcher` in play mode unaffected (separate widget)
