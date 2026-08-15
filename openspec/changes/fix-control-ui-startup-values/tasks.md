# Tasks

## Firmware boot-time rest values

- [x] Set `RK_GasPedal` constructor initial `rk.value = -100` (rest at min).
- [x] Verify `RK_Slider` (NONE → 0), `RK_Knob` (NONE/CENTER → 0), `RK_Joystick` (center 0,0) already rest correctly; add assertions/comments only if needed.

## App value sync

- [x] Remove the `if (widgetId == 0) continue;` guard in `DeviceDesignerBridge._syncValues` so the first widget (steering wheel) receives wire values.

## Wire reconstruction autoCenter

- [x] In `WidgetConfig.toDesignerJsonMap`, always emit `autoCenter` (including disabled `[null, 'smooth', 300]`) instead of removing the key when position is null.

## Knob/steering center default

- [x] Change knob and steering-wheel definition default value from `0.5` to `(min + max) / 2`.

## Tests

- [x] Add widget test: steering wheel renders centered before any runtime value (default = domain center).
- [x] Add reconstruction test: disabled autoCenter (`[null, ...]`) survives the wire round-trip (key present, position null).
- [x] Run `flutter analyze --fatal-warnings` and `flutter test` in `flutter-widgets` and `radiokit-app`.

## Hardware verification

- [x] Rebuild + flash MIKRO_V2 with NVS erase, re-upload FS bundle (`build_fs.py --board MIKRO_V2 --vehicle ScaniaV8 --hardware truck`).
- [ ] Connect tablet, open control UI: pedals rest at min, steering centered at startup.
- [ ] Verify steering with autoCenter none stays where released (no auto-centering).
