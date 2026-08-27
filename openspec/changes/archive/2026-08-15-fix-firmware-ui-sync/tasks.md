## 1. Firmware widget capacity

- [x] 1.1 Raise `RADIOKIT_MAX_WIDGETS` from 16 to 32 in `rk-arduino/src/RadioKitConfig.h`
- [x] 1.2 Verify `pushUpdate`/`pushMetaUpdate` bit masks (32 bits) accept all widget IDs up to 32 in `rk-arduino/src/RadioKit.cpp`
- [x] 1.3 Verify no other code depends on the 16-widget cap (search `RADIOKIT_MAX_WIDGETS` usages)
- [x] 1.4 Sync the updated library into the vendored copy (`cp -r rk-arduino/src/* RC_brain/lib/rk-arduino/src/`)
- [x] 1.5 Build the MIKRO_V2 env and confirm both `telemetry_Battery` and `telemetry_Speed` register (boot log / CONF_DATA)

## 2. Telemetry wire-type reconstruction (app)

- [x] 2.1 Add `case kWidgetTelemetry: return 'telemetry';` to `_wireTypeToDesignerTypeName` in `radiokit-app/lib/models/widget_config.dart`
- [x] 2.2 Add unit test asserting typeId 0x0A maps to `telemetry` and `button` still maps to `button`
- [x] 2.3 Run `flutter analyze --fatal-warnings` and `flutter test` in `radiokit-app/`

## 3. Multi-page/telemetry config reconstruction (app)

- [x] 3.1 Refactor `widgetConfigsToDesignerJson` to emit top-level `pages[]` (from the already-built `pagesJson`) when `maxPageIndex > 0` or `pageNames.length > 1`, keeping flat `widgets[]` for single-page configs
- [x] 3.2 Extract telemetry widgets (reconstructed type `telemetry`) into a top-level `telemetry[]` array and exclude them from page widget lists
- [x] 3.3 Preserve `features` and `enableControlUI` in the reconstructed config when present in the source config
- [x] 3.4 Update the two call sites (`device_provider.dart` lines ~925 and ~1925) to pass through any available `features`/`enableControlUI` metadata
- [x] 3.5 Add/update unit tests for multi-page reconstruction (pages array present, telemetry extracted, flat widgets for single page)
- [x] 3.6 Run `flutter analyze --fatal-warnings` and `flutter test` in `radiokit-app/`

## 4. Designer itemCount sync

- [x] 4.1 Normalize `itemCount` to `items.length` in `DesignerElement.fromJson` (flutter-widgets designer_state) for multiButton/multiSelect elements
- [x] 4.2 Verify `_getMultiItems` and `_buildMultiItemCountField` in `designer_inspector.dart` keep `itemCount` synced on add/remove (existing `updateElementProperty` calls)
- [x] 4.3 Add unit test: loading a design with `itemCount=5` and 3 items yields `itemCount=3`; saving serializes `itemCount == items.length`
- [x] 4.4 Run `flutter analyze --fatal-warnings` and `flutter test` in `radiokit-app/`

## 5. Verification on hardware

- [x] 5.1 Reconnect the tablet app to the MIKRO_V2 board via BLE and fetch `GET /api/connection`
- [x] 5.2 Confirm live config now contains both `Battery` and `Speed` telemetry entries (type `telemetry`, not `button`)
- [x] 5.3 Confirm live config contains `pages[]` grouping Truck/Loco widgets and `telemetry[]` array
- [x] 5.4 Open the RC_UI design in the designer, confirm `truck_light`/`loco_light` `itemCount` reads 3, save and re-generate `RADIOKIT.h`