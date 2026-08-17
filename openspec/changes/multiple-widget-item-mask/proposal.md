## Why

In vehicle and robotics firmware (e.g. `RC_brain`), control panels like `truck_light` or `loco_light` are designed with a full palette of up to 8 functions in the visual designer template. However, specific hardware boards or vehicle models only wire a subset of those light channels. Currently, all 8 button tiles appear in the mobile UI, resulting in dummy buttons that clutter the display.

Adding runtime item visibility masking via a 1-byte bitmap (`itemMask`) allows the ESP32 firmware to dynamically show only configured items while hiding unconfigured ones, collapsing the widget cleanly in the app.

## What Changes

- **Firmware C++ Library (`rk-arduino`)**:
  - `RK_MultipleFields` struct gains `uint8_t itemMask = 0xFF;` (all 8 items visible by default).
  - Add `setItemMask(uint8_t mask)`, `setItemVisible(uint8_t index, bool visible)`, `setItemHidden(uint8_t index, bool hidden)`, and query methods to `RadioKit_Multiple`.
  - Calling `setItemMask()` or `setItemVisible()` marks the configuration dirty (`RadioKitClass::markConfDirty()`), triggering a proactive `CONF_DATA` push.
  - `RadioKit_Multiple::serializeStrings()` sets `RK_STR_EXTRA` (`1 << 7`) and appends a 1-byte `[itemMask]` in the EXTRA block.

- **Companion App & Protocol Parsing (`radiokit-app`)**:
  - `WidgetConfig` parses `itemMask` from `CONF_DATA` when `typeId == kWidgetMultiple` and `RK_STR_EXTRA` is present (defaulting to `0xFF`).
  - `toDesignerJsonMap()` passes `properties['itemMask'] = itemMask`.

- **Flutter Widget Rendering (`flutter-widgets`)**:
  - `RKMultiButton` and `RKMultiSelect` support `itemMask` (default `0xFF`).
  - In live/play mode, only items whose corresponding bit in `itemMask` is set (`(itemMask & (1 << index)) != 0`) are rendered.
  - Value and bitmask bindings preserve original item indices (e.g. tapping item 3 toggles bit 3 `0x08`, even if items 0 and 2 are hidden).
  - The widget geometry and aspect ratio automatically adapt to the count of visible items.
  - In static designer mode, all items remain available for layout configuration.

## Capabilities

### New Capabilities
- `multiple-widget-item-mask`: Dynamic item-level visibility masking for `MultipleButton` and `MultipleSelect` widgets using an 8-bit bitmap over `CONF_DATA` and Flutter runtime rendering.

### Modified Capabilities
<!-- None -->

## Impact

- `rk-arduino/src/widgets/Multiple.h` & `Multiple.cpp`
- `radiokit-app/lib/models/widget_config.dart`
- `flutter-widgets/lib/src/widgets/multiple/rk_multi_button.dart`
- `flutter-widgets/lib/src/canvas/canvas_element.dart` & `display_definitions.dart`
- Tests across `rk-arduino`, `flutter-widgets`, and `radiokit-app`
