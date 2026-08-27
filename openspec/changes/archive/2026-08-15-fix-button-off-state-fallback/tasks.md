## 1. RKButton rendering

- [x] 1.1 Remove the `Icons.power_settings_new_rounded` default fallback in `_buildContent` so a button renders an icon only when the current state has one
- [x] 1.2 Rebuild the button body layout to support text-only, icon-only, and icon+text (icon stacked above text) based on the effective state values
- [x] 1.3 Keep the OFF-override fallback: when both `offIcon` and `offText` are undefined, use the ON icon/text for the OFF state; when defined, override per-field

## 2. Button definition

- [x] 2.1 Change `ButtonWidgetDefinition.buildCanvasWidget` to pass `onText`/`offText` through unchanged (`?? ''` instead of `?? 'ON'`/`?? 'OFF'`)
- [x] 2.2 Verify `defaultProperties` still defaults new buttons to `onText: 'ON'` / `offText: 'OFF'`

## 3. Tests

- [x] 3.1 Add RKButton widget tests: text-only renders no icon, icon-only renders no text, both render stacked, empty `offText` behavior, and OFF→ON fallback when OFF is fully undefined
- [x] 3.2 Run `flutter test` in `flutter-widgets/` and `radiokit-app/`; run `flutter analyze --fatal-warnings`

## 4. Verification on hardware

- [x] 4.1 Rebuild the APK, install on the tablet, reconnect to RC_UI, and confirm `start_button` shows START/STOP text with no default icon and indicators/horn show icons with no "OFF" label
