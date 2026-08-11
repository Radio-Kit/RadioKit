## 1. Widget Definitions & Schemas (`flutter-widgets`)

- [x] 1.1 Update `SliderWidgetDefinition` and `GasPedalWidgetDefinition` in `slider_definitions.dart` to support centering position selection (`none`, `min`, `center`, `max`)
- [x] 1.2 Update `MultiButtonWidgetDefinition` and `MultiSelectWidgetDefinition` schemas to include `variant` property (`push` vs `toggle`)

## 2. Inspector Panel UI (`radiokit-app`)

- [x] 2.1 Update slider `AutoCenter` position dropdown options in `designer_inspector.dart` to include `none`, `min`, `center`, `max`
- [x] 2.2 Add `Button Mode` selector (`push` vs `toggle`) for MultiButton and MultiSelect widgets in `designer_inspector.dart`
- [x] 2.3 Fix `_DesignerMultiItemEditorState` in `designer_inspector.dart` to reliably display text inputs and icon pickers for ON and OFF states for all items

## 3. Code Generation & Verification

- [x] 3.1 Update `JsonArduinoGenerator` in `json_arduino_generator.dart` to emit `setMode` for MultiButton instances based on the `variant` property
- [x] 3.2 Run Flutter widget & app tests to verify serialization and inspector rendering
