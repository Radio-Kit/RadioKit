# RKJoystick

**A premium 2‑axis joystick widget for RadioKit** offering smooth circular motion, optional auto‑centering and a labelled display.

## Constructor
```dart
RKJoystick({
  required ValueChanged<RKJoystickValue> onChanged,
  RKJoystickValue? value,
  RKJoystickValue center = const RKJoystickValue(x: 0, y: 0),
  double size = 140.0,
  bool autoCenter = true,
  String? label,
  Curve springCurve = Curves.easeOutCubic,
  Duration springDuration = const Duration(milliseconds: 300),
  double rotation = 0.0,
})
```

| Parameter | Description |
|---|---|
| `onChanged` | Callback receiving an `RKJoystickValue` with `x`, `y` (‑1 .. 1) and `isActive`. |
| `value` | Optional external value to drive the joystick position. |
| `center` | The neutral centre position (default centre). |
| `size` | Overall diameter of the joystick area. |
| `autoCenter` | When true, the knob returns to `center` after drag ends. |
| `label` | Optional text label displayed above the widget. |
| `springCurve` / `springDuration` | Controls the spring‑back animation when auto‑centering. |
| `rotation` | Visual rotation of the widget in radians. |

## Example
```dart
RKJoystickValue _pos = const RKJoystickValue();

RKJoystick(
  value: _pos,
  onChanged: (v) => setState(() => _pos = v),
  label: 'Direction',
);
```

The widget renders a 3‑D styled base with a movable thumb that follows the user's drag within the circular bounds.
