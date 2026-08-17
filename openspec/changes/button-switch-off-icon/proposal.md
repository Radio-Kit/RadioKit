# Proposal: Dual State offIcon Support for Button and Switch Widgets

## 1. Problem Statement

RadioKit's UI design layer supports distinct icons for active (`onIcon`) and inactive (`offIcon`) states across `Button` (push / toggle), `SlideSwitch`, and `RockerSwitch` widgets.

However, the C++ firmware (`rk-arduino`), wire protocol (`CONF_DATA`), and code generator (`JsonArduinoGenerator`) previously only supported a single `icon` field representing the `onIcon`. Consequently:
1. `offIcon` was dropped during code generation.
2. The wire protocol only transmitted the single `onIcon` string via `RK_STR_ICON`.
3. When connected to a physical device, the companion app received `offIcon: null`, causing `RKButton` and `RKSlideSwitch` to fall back to `onIcon` for both ON and OFF states (e.g., `horn_button` displaying `bell-ringing` instead of `bell` when idle).

## 2. Proposed Changes

1. **Firmware C++ Library (`rk-arduino`)**:
   - Add `const char* offIcon = nullptr;` to `RK_ButtonFields` (`Button.h`) and `RK_SlideSwitchFields` (`SlideSwitch.h`).
   - In `Button::serializeStrings()` and `SlideSwitch::serializeStrings()`, when `offIcon` is non-null and non-empty, set `RK_STR_EXTRA` (`1 << 7`) and append the binary block `[len = 1 + iconLen][iconLen][...iconBytes]`.

2. **Code Generation (`radiokit-app`)**:
   - Update `JsonArduinoGenerator` and `WidgetTemplates` to emit `$name.rk.offIcon = "$offIcon";` for `button`, `slideSwitch`, and `rockerSwitch` when `offIcon` is present.
   - Support `onIcon` as alias for `icon` across button and switch widgets.

3. **App Protocol Deserialization (`radiokit-app`)**:
   - In `ProtocolService`, parse `offIcon` from the `EXTRA` block for `kWidgetButton`, `kWidgetSwitch`, and `kWidgetSlideSwitch`.
   - In `WidgetConfig`, add `final String offIcon;` (default `""`) and populate `p['offIcon']` in `toDesignerJsonMap()`.

## 3. Impact & Verification

- Preserves full fidelity between design JSON and runtime device connections.
- Fully verified via unit and widget tests across `flutter-widgets`, `radiokit-app`, and C++ tests.
- Documentation and skills updated to reflect `offIcon`.
