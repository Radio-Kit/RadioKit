## 1. Firmware Implementation (rk-arduino)

- [x] 1.1 Update `Multiple.h` to add `uint8_t itemMask = 0xFF;` to `RK_MultipleFields` and add `setItemMask()`, `setItemVisible()`, `setItemHidden()`, `isItemVisible()`, `itemMask()` methods to `RadioKit_Multiple`.
- [x] 1.2 Update `Multiple.cpp` to initialize `rk.itemMask = 0xFF` and serialize `RK_STR_EXTRA` with `[len=1][itemMask]` in `serializeStrings()`.
- [x] 1.3 Add C++ unit test in `rk-arduino/test/` to verify `setItemMask` serialization and markConfDirty behavior.

## 2. App Protocol Deserialization (radiokit-app)

- [x] 2.1 Update `WidgetConfig` in `radiokit-app/lib/models/widget_config.dart` to parse 1-byte `itemMask` when `kStrMaskExtra` is set for `kWidgetMultiple`.
- [x] 2.2 Update `WidgetConfig.toDesignerJsonMap()` to include `'itemMask': itemMask` in `properties`.
- [x] 2.3 Add unit tests in `radiokit-app/test/` for `WidgetConfig` parsing of `itemMask`.

## 3. Flutter UI Rendering (flutter-widgets)

- [x] 3.1 Update `RKMultiButton` and `RKMultiSelect` in `flutter-widgets/lib/src/widgets/multiple/rk_multi_button.dart` to accept `itemMask` (default `0xFF`), filter rendered buttons to visible indices, and dynamically scale container width/height.
- [x] 3.2 Update `display_definitions.dart` and `canvas_element.dart` to forward `itemMask` from `DesignerElement.properties['itemMask']` to `RKMultiButton` / `RKMultiSelect` in play mode.
- [x] 3.3 Add widget tests in `flutter-widgets/test/` verifying dynamic filtering and bitmask / value preservation for `itemMask`.

## 4. Full Stack Verification

- [x] 4.1 Run Flutter tests across `flutter-widgets` and `radiokit-app`.
- [x] 4.2 Verify documentation and agents guidelines are up to date.
