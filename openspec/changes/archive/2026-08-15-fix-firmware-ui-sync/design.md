## Context

The RC_UI design (2 pages: Truck 10 widgets, Loco 5 widgets, plus 2 telemetry) is generated into firmware `RADIOKIT.h`, flashed to the MIKRO_V2 board, and reported back to the Flutter app over BLE via CONF_DATA. Comparing the live config (`GET /api/connection` → `configJson`) against the saved design revealed four defects:

1. `telemetry_Speed` is dropped at firmware registration. `RADIOKIT_MAX_WIDGETS` = 16 (RadioKitConfig.h:141), but the design registers 17 widgets (15 UI + 2 telemetry). The `_registerWidget` guard (`_widgetCount >= RADIOKIT_MAX_WIDGETS`, RadioKit.cpp:101) silently rejects the 17th (widgetId 16 = `telemetry_Speed`).
2. Telemetry typeId `0x0A` (`kWidgetTelemetry`) has no case in `_wireTypeToDesignerTypeName` (widget_config.dart:251-263), so it falls through to `default: 'button'`. Live config shows `{"type":"button","name":"Battery",...}`.
3. `widgetConfigsToDesignerJson` (widget_config.dart:394) builds a `pagesJson` array internally but returns a flat v1-style `widgets[]` object (lines 432-452). The live config has no `pages`, `telemetry`, `features`, or `enableControlUI` keys.
4. The saved design has stale `itemCount` (`truck_light`=5 with 3 items, `loco_light`=8 with 3 items). Codegen correctly emits `items.length` (json_arduino_generator.dart:605), so the firmware agrees with the items, not with `itemCount`.

`kWidgetTelemetry` already exists in protocol.dart (0x0A). The wire wire-format v5 header carries ACTIVE_PAGE + NUM_PAGES when multi-page.

## Goals / Non-Goals

**Goals:**
- No telemetry widget is silently dropped at firmware registration; registered widget count equals declared count.
- The app reconstructs telemetry widgets as `telemetry` type (with label/icon/unit) rather than `button`.
- The reconstructed live config JSON uses the v2 schema: top-level `pages[]`, `telemetry[]`, and preserved `features`/`enableControlUI` when the device reports them.
- Multi-widget `itemCount` stays consistent with the `items` array length during designer load and edits.

**Non-Goals:**
- No change to the CONF_DATA wire protocol format (still v5 header).
- No change to page-gating behavior (only active-page widgets sent over the wire; Loco page absence is expected and out of scope).
- No re-serialization/round-trip of `centerIcon`, `min`/`max`, or button icons that are not carried on the wire (accepted wire limitations).
- No change to the Rust relay, transports, or cloud.

## Decisions

### D1: Raise `RADIOKIT_MAX_WIDGETS` to 32
Increase `RADIOKIT_MAX_WIDGETS` from 16 to 32 in RadioKitConfig.h. Rationale: 16 is an arbitrary legacy cap; CONF_DATA and the `_pendingUpdatesMask`/`_pendingMetaMask` (32-bit masks, RadioKit.cpp:219,225) already support up to 32 widget IDs, and the widget-Id-to-`page` gating logic is unaffected. This is the lowest-risk fix and keeps the codebase simple. Alternative considered (segregating telemetry into a separate registry) was rejected as over-engineering for the current 17-widget design.

### D2: Add `kWidgetTelemetry` case to wire-type mapping
In `_wireTypeToDesignerTypeName`, add `case kWidgetTelemetry: return 'telemetry';`. The `WidgetConfig` for telemetry widgets carries the label; unit/icon may be reconstructed from the label or left empty since the wire doesn't carry them. The type string must also be recognized by `widgetConfigsToDesignerJson` grouping (see D3) and by any consumer that renders the live config.

### D3: Emit the v2 schema from `widgetConfigsToDesignerJson`
The function already computes `pagesJson` (widget_config.dart:417-430) but returns the flat `widgets[]`. Change the return to:
- emit `pages` (the already-built `pagesJson`) when `maxPageIndex > 0` or `pageNames.length > 1` (keep flat `widgets` for single-page compatibility if needed);
- extract telemetry widgets into a top-level `telemetry[]` array (`label`, optional `icon`/`unit`) when any widget's reconstructed type is `telemetry`;
- preserve `features` and `enableControlUI` from the source config when present (pass them through from the device config parse path).

The `pageNames` parameter already flows in from `DeviceProvider._pageNames` (device_provider.dart:931), and `pageIndex` is already parsed on `WidgetConfig` (widget_config.dart:84). This is a localized change to the reconstruction function plus its two call sites (device_provider.dart:925, 1925).

### D4: Normalize multi-widget `itemCount` to `items.length`
In the designer state `loadFromJson` and in the multi-item editor (designer_inspector.dart), set `itemCount = items.length` whenever items are loaded/added/removed. This matches codegen, which already emits `items.length`. The stale `itemCount=5`/`itemCount=8` values in the existing RC_UI design will be normalized on next save; no backfill migration is needed.

## Risks / Trade-offs

- Raising `RADIOKIT_MAX_WIDGETS` to 32 adds RAM/ROM for the `_widgets` array (32 pointers). → Mitigation: only 8 additional pointers (32B) over 24; negligible on ESP32-S3.
- Emitting `pages` instead of flat `widgets` changes the reconstructed JSON shape. → Mitigation: `DeviceProvider.deviceConfigJson` consumers that expect flat `widgets` are limited; the designer JSON path already prefers v2 `pages`. Verify call sites during implementation.
- Telemetry reconstructed as `telemetry` type may not render identically to `button` in existing control UI. → Mitigation: confirm rendering path handles `telemetry` type or falls back gracefully; the firmware itself emits telemetry data via the telemetry protocol (0x0D/0x0E), independent of widget type.
- `itemCount` normalization could collide with a user deliberately leaving empty slots. → Mitigation: the wire/designer only ever serializes actual items; codegen uses `items.length`, so normalization is safe and matches the wire.

## Migration Plan

1. Land firmware fix (D1) and rebuild/verify: connect to MIKRO_V2, confirm both `Battery` and `Speed` appear in live config.
2. Land app reconstruction fixes (D2+D3): verify `GET /api/connection` returns `pages`, `telemetry`, and correct widget types.
3. Land designer fix (D4): open the RC_UI design, confirm `itemCount` reads 3 for `truck_light`/`loco_light`, save, and re-generate.
4. Sync the vendored library into `RC_brain/lib/rk-arduino/` after the firmware change.
5. Rollback is trivial (revert commits); no data migration required.

## Open Questions

- Does the live control-mode rendering path have a dedicated `telemetry` widget renderer, or should reconstructed telemetry widgets still render via the button path? (Decided to type them `telemetry` per D2; rendering fallback verified during implementation.)
- Should `widgetConfigsToDesignerJson` drop the flat `widgets` key entirely for v2, or keep it for backward compat? (Default: emit `pages` when multi-page, keep flat `widgets` for single-page.)
