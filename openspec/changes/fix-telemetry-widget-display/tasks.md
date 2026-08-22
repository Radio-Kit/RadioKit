## 1. App Telemetry Serialization & Resolution

- [x] 1.1 Update `widgetConfigsToDesignerJson` in `radiokit-app/lib/models/widget_config.dart` to include integer `id` (`w.widgetId`) in each element of `result['telemetry']`.
- [x] 1.2 Update `_buildActiveLinkTelemetry` in `radiokit-app/lib/screens/home/models_tab.dart` to resolve telemetry widgets using `configJson['telemetry']` with embedded IDs or direct `dp.widgets` matching `kWidgetTelemetry`, and query `dp.telemetryValues[widgetId]`.
- [x] 1.3 Add standard fallback unit resolution (e.g. `%` for battery, `km/h` for speed) when `unit` is not provided in metadata.

## 2. Firmware Page-Agnostic Telemetry

- [x] 2.1 Update `RadioKitClass::_buildConfPayload`, `_buildVarPayload`, and `_buildMetaPayload` in `rk-arduino/src/RadioKit.cpp` to include `RK_TYPE_TELEMETRY` widgets regardless of `_activePage`.

## 3. Verification & Testing

- [x] 3.1 Run Flutter tests to verify `widgetConfigsToDesignerJson` and telemetry serialization.
- [x] 3.2 Build and install the updated APK onto the connected Android tablet (`HA26JZ08`).
- [x] 3.3 Connect to the live Mikro board over BLE and verify live Battery and Speed values render on the active model card.
