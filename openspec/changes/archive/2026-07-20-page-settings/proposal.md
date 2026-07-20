## Why

The designer's CONTROL UI section has a global orientation toggle, but per-page orientation is only accessible via the page bar's long-press context menu (hidden behind a dialog). There's no dedicated place to configure per-page settings like name and orientation in the inspector. This makes multi-page design workflows clunky — users have to hunt for page-level controls.

## What Changes

- Add a **PAGE SETTINGS** section to the designer inspector (visible only for multi-page designs)
- Section contains:
  - **Page Name**: live-editing text field (updates on keystroke)
  - **Orientation**: 3-way segmented selector — Global / Landscape / Portrait
- "Global" means the page inherits the orientation from the CONTROL UI section
- "Landscape" / "Portrait" force that orientation regardless of global
- New pages default to "Same as Global"
- Page bar tabs show a small rotation indicator badge when a page has a forced orientation
- Control screen re-locks phone orientation when switching pages with different effective orientations
- JSON format: `"orientation": "global" | "landscape" | "portrait"` (omitted = global)

## Capabilities

### New Capabilities

- `page-settings`: The PAGE SETTINGS section in the designer inspector — page name editing and orientation override selector, visible only for multi-page designs
- `page-orientation-override`: Per-page orientation override system — model changes, JSON serialization, control screen behavior, and tab indicator

### Modified Capabilities

- `multi-page-designer`: The designer inspector gains a new section; existing orientation toggle in CONTROL UI remains as the global base setting

## Impact

- `flutter-widgets/lib/src/models/designer_page.dart` — new `orientationOverride` field, computed `effectiveIsLandscape`
- `flutter-widgets/lib/src/models/designer_state.dart` — new `setPageOrientationOverride()`, updated `addPage()` default
- `radiokit-app/lib/screens/designer/widgets/designer_inspector.dart` — new PAGE SETTINGS section
- `radiokit-app/lib/screens/designer/widgets/designer_page_bar.dart` — orientation badge on tabs
- `radiokit-app/lib/providers/device_provider.dart` — per-page orientation tracking
- `radiokit-app/lib/screens/control_ui/control_screen.dart` — re-lock orientation on page switch
