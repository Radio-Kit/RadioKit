## Context

The control screen (`control_screen.dart`) renders connected device widgets via `DeviceDesignerBridge`. Above the widget canvas, a `PageSwitcher` widget provides page navigation using dot indicators. The designer has a more capable `DesignerPageBar` with named tabs, but it's only used during editing.

The `DeviceProvider` already tracks `_activePage`, `_numPages`, `_pageNames`, and exposes `sendSetPage()` for protocol-level page switching. The page bar visibility in the designer is controlled by `showPageBar` in the JSON config.

## Goals / Non-Goals

**Goals:**
- Replace dot indicators with named tab buttons in the control UI page switcher
- Add `showControlPageBar` config option to toggle page bar visibility in the control UI
- Reuse the existing `_TabButton` visual style from the designer page bar
- Keep the same protocol flow (`sendSetPage` / `PAGE_CHANGED` / `PAGE_SWITCH`)

**Non-Goals:**
- No long-press context menus (rename/duplicate/delete) — control UI is read-only
- No add/delete/reorder page actions — those stay in the designer only
- No orientation override badge — that's a designer concern
- No changes to the protocol or `DeviceProvider` state management

## Decisions

### D1: Rewrite `PageSwitcher` in-place vs create new widget

**Decision**: Rewrite `PageSwitcher` in-place.

**Rationale**: The existing `PageSwitcher` already has the correct visibility logic (`numPages > 1`, no OTA), provider integration, and `sendSetPage` wiring. Rewriting its build method from dots to tabs is simpler than creating a separate widget and conditionally swapping.

### D2: Reuse `_TabButton` style vs create new tab widget

**Decision**: Inline the tab styling directly in `PageSwitcher`, matching the `_TabButton` visual style from `designer_page_bar.dart` (animated container, primary/surface colors, bold active text).

**Rationale**: The designer's `_TabButton` has context menu logic and orientation badge that don't apply here. Copying just the visual style keeps the control UI widget self-contained without a shared dependency on designer internals.

### D3: Config field name and location

**Decision**: Add `showControlPageBar` to `DesignerState`, serialized in `canvas.showControlPageBar`. Default `true`.

**Rationale**: Follows the existing `showPageBar` pattern. Placed in the `canvas` object alongside the designer page bar toggle. The designer inspector's CONTROL UI section gets a new toggle.

### D4: Page bar height and layout

**Decision**: 40px height container (same as designer page bar), horizontally scrollable tabs, centered.

**Rationale**: Consistent visual language between designer and control UI. Horizontal scroll handles 5+ pages gracefully.

## Risks / Trade-offs

- **[Risk] Tab labels too long for narrow screens** → Mitigation: `SingleChildScrollView` with `scrollDirection: Axis.horizontal)` and `mainAxisSize: MainAxisSize.min` on the tab row. Tabs shrink to fit.
- **[Risk] Page switch latency during pending state** → Mitigation: Same as current — tabs are tappable immediately, but the UI reflects the pending page from `_handlePageChanged` response. No new UX issues introduced.
- **[Trade-off] No orientation badge in control UI** → Acceptable — orientation is a designer concern; the control UI just needs page names.
