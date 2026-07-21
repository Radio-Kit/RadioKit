## Context

The telemetry system has two halves: a designer-side config (label, icon, unit per slot) and a device-side display (connection card showing live values). Currently both are broken:

- **Designer**: 4 fixed slots, no add/remove, no undo, flat text fields
- **Device**: Hardcoded `battery=85, speed=42, temp=23` in `_buildActiveLinkTelemetry` — configured telemetry never appears

The `DeviceProvider` receives telemetry values via `VAR_DATA` packets but doesn't store them in a structured way for the connection card. The `TelemetryWidgetData` model exists but is dead code.

## Goals / Non-Goals

**Goals:**
- Variable-length telemetry (0-4 slots) with add/remove in the inspector
- Undo support for all telemetry mutations
- Wire connection card to display configured telemetry with live values
- Telemetry auto-disables when 0 widgets configured
- Clean up dead code (`TelemetryWidgetData`, `kTelemetryIcons`)

**Non-Goals:**
- No layout configuration for the connection card (always single compact row)
- No tap-to-detail or sparklines (display-only)
- No drag-to-reorder telemetry widgets
- No telemetry history or logging

## Decisions

### D1: Variable-length list vs fixed 4 with collapse

**Decision**: Variable-length list (0-4 elements).

**Rationale**: The `length == 4` strict check in `loadFromJson` is a latent breaking change. Variable-length is cleaner and allows the [+ Add] / [x Remove] pattern. Backward compat: `loadFromJson` normalizes old 4-element arrays by stripping empty trailing slots.

### D2: Telemetry data storage in DeviceProvider

**Decision**: Add `_telemetryValues: Map<int, String>` to `DeviceProvider`, keyed by widget index. Populated from `VAR_DATA` text values.

**Rationale**: The existing `RadioWidgetState` doesn't have a clean way to expose per-telemetry-slot values. A simple map is sufficient since telemetry is display-only text.

### D3: Connection card reads from DeviceProvider

**Decision**: `_buildActiveLinkTelemetry` reads `deviceProvider.telemetryValues` and the config's `telemetryWidgets` array to build the display.

**Rationale**: The config provides labels/icons/units, the provider provides live values. Merging them at render time keeps the data flow simple.

### D4: Undo granularity

**Decision**: Each telemetry mutation (add, remove, label change, icon change, unit change) calls `_pushUndo()`.

**Rationale**: Consistent with all other state mutations. Users can undo accidental telemetry changes.

### D5: JSON schema change

**Decision**: `telemetry` array becomes 0-N elements (max 4). Empty trailing elements are stripped on save.

**Rationale**: Cleaner JSON, no wasted space. Old configs with exactly 4 elements (including empty ones) are normalized on load.

## Risks / Trade-offs

- **[Risk] Breaking change for configs with exactly 4 telemetry slots** → Mitigation: `loadFromJson` strips trailing empty slots, so old 4-element arrays with empties become shorter. Codegen handles variable length.
- **[Risk] VAR_DATA telemetry mapping** → Mitigation: Telemetry widgets are indexed 0-3 in the protocol. Map VAR_DATA widget IDs to telemetry slots by position.
- **[Trade-off] No layout config** → Acceptable — single row is the established pattern from the hardcoded version.
