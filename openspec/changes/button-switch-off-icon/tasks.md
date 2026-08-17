## 1. Firmware Implementation (rk-arduino)

- [x] 1.1 Update `Button.h` and `SlideSwitch.h` to add `const char* offIcon = nullptr;` to `RK_ButtonFields` and `RK_SlideSwitchFields`.
- [x] 1.2 Update `Button.cpp` and `SlideSwitch.cpp` to serialize `offIcon` into `RK_STR_EXTRA` when present.

## 2. App Protocol & Codegen (radiokit-app)

- [x] 2.1 Update `WidgetConfig` in `radiokit-app/lib/models/widget_config.dart` to store `offIcon` and emit `'offIcon'` in `_buildDesignerProps()`.
- [x] 2.2 Update `ProtocolService` in `radiokit-app/lib/services/protocol_service.dart` to parse `offIcon` from `EXTRA` block for buttons and switches.
- [x] 2.3 Update `JsonArduinoGenerator` and `WidgetTemplates` to emit `rk.offIcon` for button and switch widgets when non-empty.

## 3. Verification & Sideload

- [x] 3.1 Run Flutter tests across `radiokit-app` and `flutter-widgets`.
- [x] 3.2 Update `RC_brain/src/RADIOKIT.h` with `offIcon` for `horn_button` and `dir_switch`.
- [x] 3.3 Build and sideload updated app to connected Android device.
