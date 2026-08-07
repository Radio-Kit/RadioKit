## Why

The `RKMultiButton` and `RKMultiSelect` widgets don't scale correctly in the designer canvas and ignore orientation changes when resized. The root cause is that `MultiButtonWidgetDefinition.buildCanvasWidget()` and `MultiSelectWidgetDefinition.buildCanvasWidget()` create the widget without passing `buttonSize`, `orientation`, or `gap` parameters — so the widget uses hardcoded defaults and computes its own intrinsic size, which often doesn't match the grid cell it's placed in. The `FittedBox` then scales it down, making it appear undersized.

## What Changes

- `MultiButtonWidgetDefinition.buildCanvasWidget()` will compute `buttonSize`, `orientation`, and `gap` from the canvas context (`ctx.width`, `ctx.height`, `ctx.cellSize`) and pass them to `RKMultiButton`
- `MultiSelectWidgetDefinition.buildCanvasWidget()` will do the same for `RKMultiSelect`
- The widget will then fill its grid cell correctly and respect orientation changes when resized

## Capabilities

### New Capabilities

### Modified Capabilities

- `widget-registry`: The `buildCanvasWidget` method for multiButton/multiSelect widget definitions will now receive and use sizing parameters from the canvas context

## Impact

- **Files modified**: `flutter-widgets/lib/src/widgets/definitions/display_definitions.dart` (two methods)
- **No API changes**: The `RKMultiButton` / `RKMultiSelect` widget APIs already accept these parameters — they just weren't being passed
- **No breaking changes**: Existing behavior is preserved; the fix makes the canvas rendering match the old `_buildMultiButton` path in `canvas_element.dart`
