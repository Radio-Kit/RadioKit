## Why

The RadioKit visual Designer UI is currently missing critical settings for several key interactive widgets:
1. **Slider Centering Control**: Slider-based controls currently lack an explicit multi-option centering position control (`none`, `min`, `center`, `max`) in the inspector UI.
2. **MultiButton Item Text & Icon Configuration**: MultiButton/MultiSelect item state fields (ON/OFF labels and icon pickers) fail to display or enable per-item configuration when default/empty items exist.
3. **MultiButton Button Mode (`push` vs `toggle`)**: MultiButton and MultiSelect widgets lack a `variant` / button mode setting (momentary `push` vs latching `toggle`), making all multi-button groups default to latching toggle behavior without flexibility.

Adding these settings restores feature parity with standalone button/slider widgets and empowers users to build richer hardware control layouts.

## What Changes

- Add explicit `AutoCenter` position selection (`none`, `min`, `center`, `max`) to `SliderWidgetDefinition` and `GasPedalWidgetDefinition` in `radiokit_widgets`.
- Add `variant` (`push` vs `toggle`) selection to `MultiButtonWidgetDefinition` and `MultiSelectWidgetDefinition` schemas and UI.
- Update `_DesignerMultiItemEditor` in `designer_inspector.dart` so ON/OFF text inputs and icon pickers are reliably rendered and editable for every button item in a multi-button or multi-select widget.
- Update C++ code generator (`json_arduino_generator.dart`) to emit appropriate button mode configuration (`RK_BUTTON_PUSH` / `RK_BUTTON_TOGGLE`) for multi-button instances.

## Capabilities

### New Capabilities
- `designer-widget-settings`: Defines requirements for slider auto-centering controls, multi-button item text/icon editing, and multi-button push/toggle mode settings in the designer and codegen engine.

### Modified Capabilities
<!-- None -->

## Impact

- **Flutter Widget Library (`flutter-widgets`)**: `SliderWidgetDefinition`, `GasPedalWidgetDefinition`, `MultiButtonWidgetDefinition`, `MultiSelectWidgetDefinition`.
- **RadioKit App (`radiokit-app`)**: `designer_inspector.dart`, `json_arduino_generator.dart`.
- **JSON Schema**: Backward compatible addition of `variant` field for `multiButton` / `multiSelect` and explicit `autoCenter` position handling.
