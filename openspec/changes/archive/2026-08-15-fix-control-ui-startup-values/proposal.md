# Fix Control UI Startup Values

## Why

Users reported three startup-rendering bugs in the control UI when connecting to a freshly-flashed device (verified live on the MIKRO board):

1. **Pedals stuck at the center position at startup** — the gas/brake pedals render at mid-travel until the user touches them, then snap to min. The firmware reports the protocol-neutral value `0` (center) at boot, and the app maps wire value `0` → mid of `[min..max]`.
2. **Steering stuck at the min position** — the steering wheel renders at its minimum angle at startup. Two compounding causes: `_syncValues` skips `widgetId == 0` (the steering wheel is the first widget, id 0), so the wire value is never applied and the widget falls back to the definition's default; and the definition default `?? 0.5` is near-min in the `[0..100]` value domain.
3. **Steering auto-centers despite autoCenter set to none** — the wire reconstruction in `toDesignerJsonMap` removes the `autoCenter` key when position is `null`, then `DesignerElement.fromJson` re-seeds the steering-wheel definition default `['center', 'smooth', 500]`, silently re-enabling auto-center in the control UI.

## What

Define and enforce a single, predictable startup behavior for the control UI:

- The wire-reported value is authoritative once VAR_DATA arrives; but on a fresh boot the firmware reports `0` for every input widget, which is not the natural rest position for spring widgets.
- **Firmware**: initialize each widget's value to its spring/centering rest position at construction (`RK_SPRING_MIN` → `-100`, `RK_SPRING_MAX` → `+100`, `RK_SPRING_CENTER` → `0`, none → `0`).
- **App**: stop skipping `widgetId == 0` in `_syncValues` so the first widget (steering wheel) receives wire values.
- **App**: wire reconstruction must emit `autoCenter: [null, 'smooth', 300]` (explicitly disabled) instead of dropping the key, so `DesignerElement.fromJson`'s definition-default seeding cannot re-enable auto-center.
- **App**: knob/steering default value should be the center of the value domain (`(min+max)/2`), not `0.5` which is near-min for `[0..100]`.

## Impact

- `rk-arduino/src/widgets/Slider.cpp`, `Knob.cpp`, `Joystick.cpp` — boot-time value rest positions.
- `radiokit-app/lib/widgets/device_designer_bridge.dart` — remove `widgetId == 0` skip.
- `radiokit-app/lib/models/widget_config.dart` — always emit `autoCenter` (disabled form included).
- `flutter-widgets/lib/src/widgets/definitions/slider_definitions.dart` — knob/steering default value centered.
- Tests: widget tests + reconstruction round-trip tests.

## Success criteria

- After a fresh flash + connect, gas/brake pedals rest at min (released), not center.
- Steering wheel renders centered (straight ahead) at startup.
- Steering wheel with autoCenter none stays where released (no auto-centering).
- AutoCenter-disabled widgets survive the wire round-trip in the control UI.
