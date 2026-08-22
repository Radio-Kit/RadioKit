## Why

Telemetry widgets for Battery and Speed continuously display `'--'` in the Flutter app's active link card on the Models tab, even though the ESP32 firmware calculates real-time values (e.g. "63"%, "0" km/h) and transmits `VAR_UPDATE` packets over BLE.

This occurs because `_buildActiveLinkTelemetry()` in `models_tab.dart` queries `configJson['widgets']` to find telemetry widgets, but multi-page designs store widgets under `configJson['pages'][p]['widgets']`, and `widgetConfigsToDesignerJson()` strips telemetry widgets from page widget lists into a top-level `configJson['telemetry']` array without preserving widget IDs. Furthermore, firmware page gating in `RadioKit.cpp` excludes telemetry widgets when `_activePage != 0`.

## What Changes

- **App UI Telemetry Resolution**: Update `_buildActiveLinkTelemetry()` in `models_tab.dart` to directly resolve telemetry widgets and values from `dp.widgets` (or embedded `id` fields in `configJson['telemetry']`) and `dp.telemetryValues[widgetId]`.
- **Telemetry Serialization with Widget IDs**: Update `widgetConfigsToDesignerJson()` in `widget_config.dart` so each entry in `configJson['telemetry']` contains the integer `id` (`widgetId`), `label`, and optional `icon`.
- **Firmware Global Telemetry Inclusion**: Update `_buildConfPayload()`, `_buildVarPayload()`, and `_buildMetaPayload()` in `RadioKit.cpp` so `RK_TYPE_TELEMETRY` widgets are always included regardless of the active page index.

## Capabilities

### New Capabilities
<!-- No new capability specs needed -->

### Modified Capabilities
- `app-telemetry-output-sync`: Extend requirements to mandate widget ID retention in `configJson['telemetry']` and reliable UI binding for telemetry widgets across single-page and multi-page configurations.

## Impact

- `radiokit-app/lib/screens/home/models_tab.dart`: `_buildActiveLinkTelemetry()` correctly resolves live values.
- `radiokit-app/lib/models/widget_config.dart`: `widgetConfigsToDesignerJson()` includes `id` in `telemetry` list.
- `rk-arduino/src/RadioKit.cpp`: Firmware includes telemetry widgets across all pages.
