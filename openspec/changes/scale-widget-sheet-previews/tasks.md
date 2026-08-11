## 1. Widget Preview Scaling Implementation

- [x] 1.1 Update `_buildPreview()` in `radiokit-app/lib/screens/designer/widgets/designer_widget_dialog.dart` to compute `(defW, defH) = DesignerElement.defaultSize(variant.type)`.
- [x] 1.2 Wrap preview widget instances in `FittedBox(fit: BoxFit.contain)` with a `SizedBox` dimensioned proportionally to `(defW, defH)`.
- [x] 1.3 Update individual widget preview cases to use proportional sizes without hardcoded distortions.

## 2. Verification

- [x] 2.1 Run `flutter test` in `radiokit-app` and `flutter-widgets` to verify UI and widget tests pass.
- [x] 2.2 Rebuild debug APK and flash via ADB stream install to device `HA26JZ08`.
