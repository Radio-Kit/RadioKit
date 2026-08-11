## Why

In the "Add Widget" bottom sheet (`designer_widget_dialog.dart`), widget previews currently use hardcoded pixel sizes and arbitrary clamp limits that do not match each widget's true default aspect ratio (`DesignerElement.defaultSize`). As a result, widget icons and previews appear distorted, clipped, or unproportional. Scaling each widget preview according to its default aspect ratio inside a `FittedBox` ensures every preview accurately represents its default canvas proportions.

## What Changes

- Update `_buildPreview()` in `designer_widget_dialog.dart` to calculate `(defW, defH)` using `DesignerElement.defaultSize(variant.type)`.
- Render widget preview instances inside a `FittedBox(fit: BoxFit.contain)` with a `SizedBox` dimensioned proportionally to `(defW, defH)`.
- Ensure all 14 control and indicator widget variants render cleanly without distortion in the bottom sheet grid cells.

## Capabilities

### New Capabilities
- `widget-sheet-preview-scaling`: Scales widget previews in the "Add Widget" sheet according to their canonical default aspect ratio.

### Modified Capabilities

## Impact

- **UI Components**: `radiokit-app/lib/screens/designer/widgets/designer_widget_dialog.dart`.
