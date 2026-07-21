## Context

The designer inspector's telemetry section is a form-only interface — icon picker, label input, unit input per slot with no visual representation of the output. The connected device card on the control screen renders telemetry as a horizontal row of `_TelemetryItem` widgets (label, icon, value, unit). Users currently configure telemetry blind, with no way to see how their configuration will render.

Additionally, telemetry slots are locked to insertion order with no reordering capability.

The inspector panel is 320px wide, scrollable. The telemetry section sits at the bottom of the "Model Settings" view (no widget selected). Currently each slot takes ~40px height.

## Goals / Non-Goals

**Goals:**
- Show a live preview of all configured telemetry slots rendered exactly as on the connected device card
- Allow drag-and-drop reordering of telemetry slots via grip handles
- Keep the preview in sync with editor changes in real-time
- Maintain undo support for all telemetry mutations including reorder

**Non-Goals:**
- Changing the connected device card rendering (out of scope)
- Adding/removing slots via the preview row (editor rows remain the source of truth)
- Animating preview updates during drag (preview updates on drop only)

## Decisions

### D1: Preview row placement — above editor rows

**Decision:** Place the preview row between the section header and the editor rows.

**Rationale:** The preview is a summary — it should be seen first, then the editors below. This mirrors the mental model: "here's what it looks like, here's how to configure it."

**Alternative considered:** Preview below editors — rejected because users scroll down past editors and might miss it.

### D2: Preview styling — exact mirror of `_TelemetryItem`

**Decision:** Use identical styling to the connected device card's `_TelemetryItem` widget.

**Rationale:** The preview's value is showing users exactly what they'll get. Any deviation (different fonts, sizes, spacing) would mislead.

**Styling:**
- Label: `fontSize: 9, fontWeight: bold, color: onSurface @ 0.38`
- Icon: `tokens.primary`, 16px
- Value: `GoogleFonts.exo2`, 22px, `FontWeight.w900`, `tokens.primary`
- Unit: `fontSize: 10, fontWeight: bold, color: onSurface @ 0.38`
- Layout: `Column` > `Text(label)` + `Row` > `[Icon] + Text("120") + Text(unit)`

### D3: Sample value — fixed "120"

**Decision:** Show "120" as the placeholder value for all preview items.

**Rationale:** A number demonstrates the visual weight and spacing of a real value. "120" is neutral and works for speed, battery, RPM, etc. A dash ("---") would look empty and uninformative.

### D4: Preview updates — real-time via state read

**Decision:** The preview reads directly from `widget.state.telemetryWidgets` — the same list the editor mutates via `onChanged`. No additional wiring needed.

**Rationale:** `notifyListeners()` is already called on every `setTelemetryLabel`/`setTelemetryIcon`/`setTelemetryUnit`. The `ListenableBuilder` wrapping the inspector rebuilds on every change. The preview naturally stays in sync.

### D5: Reorder mechanism — LongPressDraggable + DragTarget

**Decision:** Use Flutter's `LongPressDraggable<int>` on the grip handle and `DragTarget<int>` on the entire row.

**Rationale:** Long-press is the standard mobile reorder gesture (matches iOS/Android list reordering patterns). Placing the Draggable only on the handle avoids gesture conflicts with the row's DragTarget.

**Alternative considered:** `ReorderableListView` — rejected because the telemetry section is inside a `Column` within a `SingleChildScrollView`, and `ReorderableListView` requires a flat list layout. Wrapping it would add complexity without benefit.

**Alternative considered:** Up/down arrow buttons — rejected as less natural despite being simpler.

### D6: Drop indicator — insertion line between rows

**Decision:** Show a 2px colored line (`tokens.primary`) between rows at the insertion point.

**Rationale:** An insertion line is clearer than highlighting the entire target row. It shows exactly where the item will land — above or below the hovered row.

**Position logic:** `onMove` callback calculates cursor position within each DragTarget. If cursor is in the top half, insert above; bottom half, insert below.

### D7: List mutation — single undo entry

**Decision:** `reorderTelemetrySlot(oldIndex, newIndex)` calls `_pushUndo()` once, then removes and reinserts the item.

**Rationale:** A reorder is a single logical operation. One undo step reverts the entire reorder, not individual steps.

### D8: Preview during drag — static until drop

**Decision:** The preview row stays in its current order during drag. Updates only on drop.

**Rationale:** Animating the preview during drag would require tracking in-progress reorder state and applying it to the preview, adding complexity for minimal benefit. The drag is fast (<1s typically), so the momentary desync is negligible.

## Risks / Trade-offs

- **[Risk] LongPressDraggable gesture conflict with ScrollView** → The inspector is inside a `SingleChildScrollView`. Long-press on the handle could conflict with scroll gestures. Mitigation: The handle is a small, distinct touch target. `LongPressDraggable` uses a long-press timeout (500ms default) which is distinct from scroll gestures. If issues arise, can reduce `HapticFeedback.mediumImpact()` delay or use `DragAnchor` strategy.

- **[Risk] Preview height increase** → Each slot goes from ~40px to ~80px. With 4 slots, that's 160px extra. Mitigation: Inspector scrolls. The preview provides high value per pixel. Can consider collapsing empty slots in the preview if needed.

- **[Trade-off] Preview is static "120" not live data** → The preview can't show actual device values since there's no connection in designer mode. This is acceptable — the preview shows layout and styling, not runtime data.

- **[Trade-off] Drop indicator uses approximate row height** → The `onMove` callback calculates position based on a fixed row height estimate. If rows have variable height (unlikely but possible), the indicator could be slightly off. Mitigation: All rows are fixed-height (28px text fields + padding), so this is stable.
