## Context

The designer page bar (`DesignerPageBar`) currently shows dot indicators for page navigation. While functional, dots don't communicate page names and are hard to distinguish when there are many pages. The user requested:

1. **Tab-style page bar** — Replace dots with named tabs (like Material `TabBar`) so users can see and tap page names directly
2. **Visibility toggle** — Allow hiding the page bar entirely for a cleaner canvas view

Current state:
- `DesignerPageBar` in `radiokit-app/lib/screens/designer/widgets/designer_page_bar.dart` — dot-based with chevrons, rename, context menu
- `DesignerState` in `flutter-widgets/lib/src/models/designer_state.dart` — manages pages, no visibility flag
- `designer_screen.dart` — conditionally shows page bar with `if (!_state.isPlayMode)`

## Goals / Non-Goals

**Goals:**
- Replace dot indicators with named tab buttons in the page bar
- Add a toggle button to show/hide the page bar
- Persist `showPageBar` in JSON config for design session persistence
- Maintain all existing features (add, rename, delete, duplicate, reorder)

**Non-Goals:**
- Changing the `PageSwitcher` in control/play mode (separate widget, untouched)
- Drag-to-reorder on tabs (retain on dots — tabs use long-press context menu instead)
- Animation or transition effects on tab switch

## Decisions

### 1. Tab design: Pill-shaped buttons with page name

Each page becomes a compact pill button showing the page name. Active tab uses `tokens.primary` background; inactive tabs use `tokens.surface` with `tokens.effectiveOutline` border.

```
[< ] [Control] [Settings] [+]  >  [toggle icon]
```

- Active tab: filled pill with `tokens.primary` bg, `tokens.onPrimary` text
- Inactive tab: outlined pill with `tokens.surface` bg, `tokens.onSurface` text
- Tab width: auto-sized to text content (min 48px, max 120px)
- Height: 28px (compact, fits in the 40px bar)

**Alternative considered:** Material `TabBar` — rejected because it requires a `TabController` and doesn't support the add/rename/delete operations we need inline.

### 2. Long-press for context menu on tabs

Since dots had drag-to-reorder and long-press for context menu, tabs will use:
- **Tap** → switch to page
- **Long-press** → context menu (rename, duplicate, delete)
- Drag-to-reorder is removed from tabs (not practical with text buttons)

**Alternative considered:** Keep drag-to-reorder with `LongPressDraggable` — rejected as too complex for text tabs and poor UX on touch devices.

### 3. Visibility toggle button

A small icon button in the page bar (right side, before the add button) toggles `showPageBar`:

- `LucideIcons.panelTopOpen` (visible) / `LucideIcons.panelTopClose` (hidden)
- When hidden, the page bar collapses to 0 height with an `AnimatedSize` transition
- A small floating restore button appears at the top-center of the canvas when the bar is hidden

### 4. State: `showPageBar` in DesignerState

- Add `bool _showPageBar = true` to `DesignerState`
- Getter: `bool get showPageBar => _showPageBar`
- Setter: `void togglePageBar()` — flips the value and calls `notifyListeners()`
- Serialized in `toJson()` under `canvas.showPageBar` (default: `true`)
- Loaded in `loadFromJson()` with fallback to `true`

### 5. JSON config location

```json
{
  "version": 2,
  "canvas": {
    "size": [200, 100],
    "showPageBar": true
  },
  "pages": [...]
}
```

Backward compatible — missing field defaults to `true`.

## Risks / Trade-offs

- **Tab overflow with many pages** — Mitigated by `SingleChildScrollView` wrapping the tab row (same pattern as current dots)
- **Tab text truncation** — Long page names truncated with ellipsis (maxWidth: 120px per tab)
- **Removed drag-to-reorder** — Users can still reorder via context menu or keyboard shortcuts if we add them later. This is acceptable for the initial implementation.
