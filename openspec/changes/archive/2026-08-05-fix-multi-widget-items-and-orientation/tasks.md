## 1. Fix Item Count Padding

- [x] 1.1 Update `MultiButtonWidgetDefinition.buildCanvasWidget()` in `display_definitions.dart` to read `itemCount` and pad/generate items up to `itemCount`
- [x] 1.2 Update `MultiSelectWidgetDefinition.buildCanvasWidget()` in `display_definitions.dart` to read `itemCount` and pad/generate items up to `itemCount`

## 2. Fix Automatic Orientation Flipping

- [x] 2.1 Update `aspectRatio` in `MultiButtonWidgetDefinition` and `MultiSelectWidgetDefinition` to return `null` for free-form resizing
- [x] 2.2 Update `DesignerElement.aspectRatio` in `designer_element.dart` for `multiButton` and `multiSelect` to return `null`

## 3. Verification

- [x] 3.1 Run `flutter test` across `flutter-widgets` and `radiokit-app` — all unit tests pass
- [x] 3.2 Verify changing `itemCount` to 4, 5, 6 in inspector updates canvas to render 4, 5, 6 buttons
- [x] 3.3 Verify dragging resize handle to make `height > width` flips orientation to vertical automatically
