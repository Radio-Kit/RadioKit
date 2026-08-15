## Context

The control UI (and designer canvas) renders buttons through `RKButton` (`flutter-widgets/lib/src/widgets/button/rk_button.dart`) built by `ButtonWidgetDefinition.buildCanvasWidget` (`flutter-widgets/lib/src/widgets/definitions/button_definitions.dart`).

A parity check of the RC_UI surface showed two deviations from the design:

1. `start_button` (toggle, START/STOP text, no icons) renders the built-in `Icons.power_settings_new_rounded` fallback icon because `_buildContent` falls back to it when `currentIcon` is null.
2. `left_indicator` / `right_indicator` / `horn_button` (icons with empty text) render default "ON"/"OFF" labels because `buildCanvasWidget` defaults `onText`/`offText` with `?? 'ON'` / `?? 'OFF'`.

The multi-button/multi-select widgets already implement the desired OFF-override semantics per item (`RKToggleItem.isOffEmpty` falls back to the on-state icon/label), so the fix is scoped to single buttons.

## Goals / Non-Goals

**Goals:**
- Buttons render only defined content: text-only, icon-only, or both.
- OFF state fields act as an override; when OFF icon and text are both undefined, ON icon and text are shown in the OFF state.
- Empty text stays empty (no injected "ON"/"OFF" defaults); absent icon stays absent (no power-icon default).
- Cover the behavior with widget tests.

**Non-Goals:**
- No wire/protocol changes — the wire already omits empty strings and carries a single icon string.
- No changes to slide switch / rocker switch label behavior (different widget paradigm; labels are inherent to the thumb/track).
- No changes to the designer's default button properties (new buttons still default to ON/OFF).

## Decisions

### D1: Remove the default icon fallback in `_buildContent`
**Decision:** Delete `?? Icons.power_settings_new_rounded`; render the `Icon` widget only when the effective icon for the current state is non-null.
**Rationale:** A text-only button should show text only. The default power icon is never part of the design data.
**Alternative considered:** Keep the fallback but only for buttons with neither text nor icon — rejected; an empty button is invalid upstream (designer defaults ensure content), so the renderer should simply show nothing rather than a misleading icon.

### D2: Keep the all-or-nothing OFF override, per-field effective values
**Decision:** Preserve the existing rule — when BOTH `offIcon` and `offText` are undefined (null/empty), use `onIcon`/`onText` for the OFF state; otherwise each defined OFF field overrides its ON counterpart and undefined OFF fields stay absent. Compute `effectiveOffIcon`/`effectiveOffText` from the current state value and derive the rendered icon/text from those.
**Rationale:** This matches the stated behavior: "OFF definitions are an override; if OFF icon or text is defined it is displayed, else the ON icon/text/both is displayed in OFF too." It also mirrors `RKToggleItem` semantics used by multi-buttons, keeping single and multi buttons consistent.
**Note:** An explicit empty `offText` (`''`) is treated as "not defined" and therefore falls back to the ON text — consistent with how the wire omits empty strings.

### D3: Button definition passes text through unchanged
**Decision:** Change `buildCanvasWidget` to `onText: ctx.properties['onText'] ?? ''` and `offText: ctx.properties['offText'] ?? ''`.
**Rationale:** The design's empty labels must stay empty (icon-only buttons). New buttons still get ON/OFF from `defaultProperties`.
**Alternative considered:** Keep `?? 'ON'`/`?? 'OFF'` and blank them in the renderer — rejected; the definition is the wrong layer to inject display defaults that fight the design data.

### D4: Body layout mirrors `_ToggleButton`
**Decision:** Rebuild the button body as a conditional stack: icon only → centered icon; text only → centered text; both → icon above text. Size the icon slightly smaller when text is present.
**Rationale:** Matches the multi-button item layout and produces consistent visuals across button types.

## Risks / Trade-offs

- **[Risk] Buttons with no icon and no text render empty** → Mitigation: the designer's `defaultProperties` (ON/OFF text) ensure new buttons have content; the wire only produces text-less/icon-less states when the design explicitly emptied them, which is a design-time concern. Optionally add a designer validation warning later.
- **[Risk] Empty `offText` now falls back to ON text where a design intended a blank OFF label** → Mitigation: explicit in D2 and covered by a spec scenario; adjust the design data if a blank OFF label is desired (e.g. `offText` non-empty is the only wire-carryable signal).
- **[Risk] Push buttons show ON content at rest when OFF is fully undefined** → Accepted: this is the defined override semantics (OFF defaults to ON). The RC_UI horn button is affected; the design can define `offText`/`offIcon` to get a distinct resting state.

## Migration Plan

No data or protocol migration. Purely a rendering/definition fix in flutter-widgets; re-run the flutter-widgets and radiokit-app test suites. The control UI picks up the change without a firmware change (app-side rendering), though a new APK build is required to see it.

## Open Questions

- Should the designer inspector warn when a button ends up with no text and no icon in both states? (Deferred — see Risks.)
