## 1. Fix MultiButtonWidgetDefinition

- [x] 1.1 Update `MultiButtonWidgetDefinition.buildCanvasWidget()` in `display_definitions.dart` to compute `buttonSize`, `orientation`, and `gap` from `ctx.width`, `ctx.height`, `ctx.cellSize` and pass them to `RKMultiButton`

## 2. Fix MultiSelectWidgetDefinition

- [x] 2.1 Update `MultiSelectWidgetDefinition.buildCanvasWidget()` in `display_definitions.dart` with the same sizing logic

## 3. Verification

- [x] 3.1 Run `flutter analyze --fatal-warnings` — no new warnings
- [x] 3.2 Manual test: add a multiButton to the designer canvas, verify it fills its grid cell
- [x] 3.3 Manual test: resize a multiButton from horizontal to vertical, verify orientation flips
