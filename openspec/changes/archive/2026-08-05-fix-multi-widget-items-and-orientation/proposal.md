## Why

`RKMultiButton` and `RKMultiSelect` widgets in the designer UI have two issues:
1. They render only 3 buttons regardless of `itemCount` because `buildCanvasWidget()` only maps `ctx.properties['items']` without padding missing items up to `itemCount`.
2. Resizing to vertical/horizontal orientation does not flip automatically like `Slider` because `aspectRatio` returns a rigid multiplier (`count * 0.67`), which locks the resize handle calculations in `_handleResize()`.

## What Changes

- `MultiButtonWidgetDefinition` & `MultiSelectWidgetDefinition` in `display_definitions.dart` will generate/pad items up to `itemCount` (clamped 2..8) so exact number of buttons render on canvas.
- Remove rigid `aspectRatio` constraints from `MultiButtonWidgetDefinition` and `MultiSelectWidgetDefinition` (or return `null`) so canvas resizing is free-form.
- `buildCanvasWidget()` will automatically calculate orientation dynamically (`width >= height ? horizontal : vertical`), allowing smooth orientation flipping when dragged.

## Capabilities

### New Capabilities

### Modified Capabilities

- `widget-registry`: `buildCanvasWidget()` pads `toggleItems` up to `itemCount` and evaluates dynamic orientation without rigid aspect-ratio locks.

## Impact

- **Files modified**:
  - `flutter-widgets/lib/src/widgets/definitions/display_definitions.dart`
  - `flutter-widgets/lib/src/models/designer_element.dart`
- **No API changes**: Internal canvas rendering and sizing logic fix.
