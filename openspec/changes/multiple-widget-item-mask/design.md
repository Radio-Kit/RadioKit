## Context

In complex embedded systems (such as `RC_brain`), control surfaces often define up to 8 functions in a multi-button / multi-select widget (e.g. `truck_light`: Head Light, Full Beam, Fog Lamp, Hazard, Beacon, Cab, Work, Aux). However, varying hardware configurations only wire a subset of these outputs. Without dynamic item masking, users are presented with non-functional dummy buttons on the mobile screen.

## Goals / Non-Goals

**Goals:**
- Enable ESP32 firmware to set an 8-bit visibility mask (`itemMask`) on `RadioKit_Multiple` (base class for `RK_MultipleButton` and `RK_MultipleSelect`).
- Transmit `itemMask` in `CONF_DATA` using the `RK_STR_EXTRA` byte (`1 << 7` in string mask).
- Parse `itemMask` in `radiokit-app` and configure `RKMultiButton` / `RKMultiSelect` widgets.
- Dynamically filter rendered button tiles in Flutter to only visible items while strictly preserving the underlying bitmask / index values.
- Dynamically adapt widget layout dimensions (width / height) to the number of visible items.

**Non-Goals:**
- Dynamic re-ordering of items (indices remain 0 to 7).
- Hiding items beyond index 7 (an 8-bit mask supports 8 items, which matches `RADIOKIT_MAX_ITEMS` limit of 8 for multi widgets).

## Decisions

### Decision 1: 1-Byte `itemMask` in `RK_STR_EXTRA`
- **Choice**: Use the existing `RK_STR_EXTRA` mechanism in `CONF_DATA` descriptor to carry a 1-byte `[itemMask]` payload `[len=1][itemMask]`.
- **Rationale**: `RK_STR_EXTRA` is already the established pattern for widget-specific binary config (e.g. in `Knob`). It avoids changing string schemas or delimiters and has minimal overhead (2 bytes total: 1 length byte + 1 mask byte).
- **Alternative considered**: Appending visibility flags into pipe-delimited string payload `label:icon:mask|...`. Rejected due to string parsing overhead and potential format ambiguity.

### Decision 2: Preserve Original Index and Bit Contract
- **Choice**: In `RKMultiSelect` (checkbox mode), button at original index $i$ always toggles bit $1 \ll i$. In `RKMultiButton` (radio mode), selecting item at original index $i$ returns value $i$.
- **Rationale**: Firmware decodes commands by checking specific bits (e.g. Bit 3 for Hazard). If item 2 is hidden, item 3 must still control Bit 3.
- **Alternative considered**: Renumbering active items sequentially. Rejected because it breaks firmware pin mapping contracts.

### Decision 3: Dynamic Layout Resizing
- **Choice**: The widget container dimensions ($cw$ and $ch$) in `RKMultiButton` and `RKMultiSelect` are calculated from `visibleCount = visibleIndices.length`.
- **Rationale**: Prevents awkward gaps or blank placeholder buttons when fewer than 8 items are visible.

## Risks / Trade-offs

- **[Risk]** If all items are masked out (`itemMask == 0`), widget rendered size could become 0.
  - **Mitigation**: If `visibleIndices` is empty, fallback to rendering a minimum empty container or handling gracefully without throwing divide-by-zero errors.
- **[Risk]** Designer preview vs Play mode mismatch.
  - **Mitigation**: In Designer Canvas, all items remain visible so the designer can layout the full set of items; `itemMask` is respected in Play Mode / Live Controller Mode.
