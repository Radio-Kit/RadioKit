## Context

In RadioKit, `RK_Telemetry` is a display-only output widget designed to render live sensor and vehicle telemetry (such as battery voltage/percentage and estimated speed) in the top active model summary card of the app rather than on the interactive control canvas.

On the firmware side (`RC_brain` / `VehicleController`), telemetry values are formatted into strings every 1000ms and assigned to `telemetry_Battery.rk.content` and `telemetry_Speed.rk.content`. `RadioKitClass.update()` detects output shadow buffer differences and transmits `VAR_UPDATE` (`0x08`) packets over BLE.

In the Flutter app, `DeviceProvider._handleVarUpdate()` decodes `kWidgetTelemetry` values and updates `_telemetryValues[widgetId]`. However, in `models_tab.dart`, `_buildActiveLinkTelemetry()` attempts to retrieve telemetry widget configurations from `configJson['widgets']`. In multi-page vehicles (and in reconstructed designer configs where telemetry is separated into `configJson['telemetry']`), this list is empty, resulting in `_buildActiveLinkTelemetry()` always rendering `--`.

## Goals / Non-Goals

**Goals:**
- Fix active link telemetry rendering in `models_tab.dart` so battery percentage and speed display live values from `dp.telemetryValues[widgetId]`.
- Persist `id` (`widgetId`) within `configJson['telemetry']` in `widgetConfigsToDesignerJson()`.
- Ensure `RadioKitClass` on firmware includes `RK_TYPE_TELEMETRY` widgets across all active pages during `CONF_DATA`, `VAR_DATA`, and `META_DATA` building.
- Infer or preserve standard telemetry units (`%`, `km/h`, etc.) in the UI when not provided over wire.

**Non-Goals:**
- Modifying interactive control canvas widget rendering.
- Modifying binary BLE packet framing or changing the `0x08 VAR_UPDATE` wire format.

## Decisions

### Decision 1: Direct Telemetry Widget Extraction in `_buildActiveLinkTelemetry`
Rather than traversing `configJson['widgets']`, `_buildActiveLinkTelemetry` will inspect `configJson['telemetry']` (which includes `id`, `label`, `icon`, and optional `unit`), falling back to `dp.widgets.where((w) => w.typeId == kWidgetTelemetry)`.
- *Rationale*: Guarantees that whether a config is single-page, multi-page, or reconstructed from wire data, telemetry slots have their correct `widgetId` and metadata.

### Decision 2: Preserving `id` in `widgetConfigsToDesignerJson` Telemetry Items
`widgetConfigsToDesignerJson` will include `'id': w.widgetId` in each map in `result['telemetry']`.
- *Rationale*: Keeps telemetry metadata self-contained in `configJson['telemetry']` without having to cross-reference multiple structures.

### Decision 3: Firmware Page-Agnostic Filtering for Telemetry
In `RadioKitClass::_buildConfPayload`, `_buildVarPayload`, and `_buildMetaPayload`:
```cpp
if (w->typeId != RK_TYPE_TELEMETRY && w->page() != _activePage) continue;
```
- *Rationale*: Telemetry widgets are global status indicators for the vehicle and are not pinned to a single canvas screen.

## Risks / Trade-offs

- *[Risk]* Unit is not sent over wire in protocol v4/v5.
  → *Mitigation*: Fallback to standard unit heuristics based on label name (e.g. `%` for Battery, `km/h` for Speed, `V` for Voltage, `°C` for Temp) if unit is omitted from design JSON.
