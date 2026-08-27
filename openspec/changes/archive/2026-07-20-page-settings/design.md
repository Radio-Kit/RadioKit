## Context

The designer has a per-page orientation model (`DesignerPage.isLandscape`) but it's only toggleable via the CONTROL UI section (which acts as both global and per-page). The page bar tabs show page names but no orientation indicator. The control screen has a single `_orientation` field that doesn't track per-page overrides.

Current state:
- `DesignerPage.isLandscape: bool` — absolute, set directly
- `toggleOrientation()` — flips the bool, rescales elements
- CONTROL UI section — has Landscape/Portrait toggle (reads `activePage.isLandscape`)
- Control screen — single `_orientation` int, locked on mount
- JSON: `"orientation": "landscape" | "portrait"` per page

## Goals / Non-Goals

**Goals:**
- Add PAGE SETTINGS section to inspector (multi-page only)
- Per-page orientation override: Global / Force Landscape / Force Portrait
- Page bar tab indicator for overridden pages
- Control screen re-locks orientation on page switch
- New pages default to "Same as Global"

**Non-Goals:**
- Changing the CONTROL UI global orientation toggle (it stays)
- Per-widget orientation (only per-page)
- Changing the binary protocol or codegen output
- Backward compatibility with old JSON (no compat needed per user)

## Decisions

### 1. Orientation override model on DesignerPage

Add `orientationOverride` field:
```dart
String? orientationOverride; // null | 'global' | 'landscape' | 'portrait'
```

Computed property:
```dart
bool effectiveIsLandscape(bool globalIsLandscape) {
  switch (orientationOverride) {
    case 'landscape': return true;
    case 'portrait': return false;
    case 'global':
    default: return globalIsLandscape;
  }
}
```

**Why not an enum?** String matches JSON directly, no conversion layer needed.

**Why nullable default?** `null` means "not set yet" — defaults to `'global'` behavior. Clean for existing pages that don't have the field.

### 2. JSON serialization

```json
{ "orientation": "global" }     // same as global
{ "orientation": "landscape" }  // force landscape
{ "orientation": "portrait" }   // force portrait
(no key or omitted)             // defaults to "global"
```

**Why a sentinel instead of omitting?** Explicit is better. `"global"` is self-documenting in the JSON.

### 3. DesignerState changes

- `setPageOrientationOverride(String? value)` — sets override on active page
- `toggleOrientation()` — now sets override to opposite of global (not flip `isLandscape`)
- `addPage()` — defaults `orientationOverride` to `'global'`
- Canvas width/height getters use `effectiveIsLandscape(globalIsLandscape)`

**Why keep `isLandscape` on DesignerPage?** It's used by `toJson()` for backward compat and by the canvas size getters. The override is a layer on top.

### 4. Inspector layout

```
PAGE SETTINGS (only when numPages > 1)
  Page Name      [________]        ← live text field
  Orientation    [Global|Landscape|Portrait]  ← 3-way segmented

MODEL
  Name, Description, Type, Password
...
CONTROL UI
  Enable UI, Orientation (GLOBAL), Grid, Size
...
```

The PAGE SETTINGS section sits above MODEL. Uses `InspectorFieldBuilders.buildSection()` and `buildCenterPinnedSelector()` for consistency.

### 5. Tab indicator

Small rotation icon (LucideIcons.rotateCw or similar) shown as a badge on tabs where `orientationOverride != 'global' && orientationOverride != null`. Positioned at top-right of the tab pill.

### 6. Control screen orientation re-lock

When page switches in control mode:
1. `DeviceProvider` computes effective orientation for the new page
2. Updates `_orientation` field
3. `ControlScreen` listens and re-applies `SystemChrome.setPreferredOrientations()`

This requires `ControlScreen` to listen to page changes (already does via `DeviceProvider` listener).

## Risks / Trade-offs

- **Phone rotation on page switch** — could be jarring. Mitigated by the fact that pages with different orientations are intentional design choices.
- **`toggleOrientation()` behavior change** — existing code flips `isLandscape` directly. Now it sets an override. Existing designs with explicit orientations will need the override field to be set correctly on load. Mitigated by `fromJson()` mapping old `"landscape"`/`"portrait"` to explicit overrides.
- **Inspector height** — adding a section increases inspector content. Already scrollable, so minimal impact.
