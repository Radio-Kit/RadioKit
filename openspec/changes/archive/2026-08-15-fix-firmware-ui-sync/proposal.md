## Why

A live-vs-design comparison of the RC_UI config (MIKRO_V2 truck board over BLE) found that the UI the firmware reports does not faithfully match the saved design. The firmware silently drops `telemetry_Speed` because `RADIOKIT_MAX_WIDGETS` (16) is smaller than the design's 17 registrations, the app reconstructs telemetry widgets (typeId 0x0A) as plain `button` widgets, and the live config is flattened to a v1-style structure that loses `pages`, `telemetry`, `features`, and `enableControlUI`. The design file also contains stale `itemCount` values (`truck_light`=5, `loco_light`=8) that disagree with their item lists.

## What Changes

- **Firmware**: raise or restructure the widget registration limit so telemetry widgets are not silently dropped when the design uses many widgets. Registered widget count must equal declared count. **BREAKING** if the wire protocol relies on the 16-widget cap for anything else (none found).
- **App wire reconstruction**: map wire typeId `0x0A` (`kWidgetTelemetry`) to a proper `telemetry` type instead of falling through to `button` in `_wireTypeToDesignerTypeName`.
- **App config reconstruction**: `widgetConfigsToDesignerJson` must emit the full v2 schema for multi-page/telemetry-capable devices: top-level `pages[]` (grouped by `pageIndex`), `telemetry[]` (from telemetry widgets), and `features`/`enableControlUI` when present, instead of the current flat `widgets[]` reconstruction.
- **Designer itemCount sync**: multi-widget editors must keep `itemCount` consistent with the actual `items` array length on load and edit (fixing stale `itemCount=5`/`itemCount=8` with only 3 items).

## Capabilities

### New Capabilities
- `telemetry-config`: covers how telemetry widgets are declared in the design, registered on the firmware without being dropped by the widget cap, serialized on the wire, and reconstructed by the app as telemetry (not button) in the live config JSON.

### Modified Capabilities
- `multi-page-app`: page-aware wire-to-JSON conversion must produce a top-level `pages[]` array (not a flat `widgets[]` list) when the device reports multiple pages, preserving page grouping, names, and page indices in the reconstructed config.
- `widget-registry`: multi-widget `itemCount` handling must keep the property in sync with the `items` array length (no stale counts where itemCount > items length), matching the codegen behavior that already emits `items.length`.

## Impact

- `rk-arduino/src/RadioKitConfig.h` — `RADIOKIT_MAX_WIDGETS` value or removal.
- `rk-arduino/src/RadioKit.cpp` — widget registration / CONF_DATA emission if restructured.
- `radiokit-app/lib/models/widget_config.dart` — `_wireTypeToDesignerTypeName` telemetry case; `widgetConfigsToDesignerJson` multi-page/telemetry reconstruction.
- `radiokit-app/lib/models/protocol.dart` — `kWidgetTelemetry` const already present (0x0A).
- `radiokit-app/lib/screens/designer/designer_inspector.dart` — multi-item editor `itemCount` sync on load and on item add/remove.
- `radiokit-app/lib/screens/designer/` — designer state (`loadFromJson`) itemCount normalization.
- Vendored library sync: `RC_brain/lib/rk-arduino/` mirrors `rk-arduino/`.
- Existing design file for RC_UI (`design_rcui.json`) carries stale `itemCount`; will normalize on next save.
