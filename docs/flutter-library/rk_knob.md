# RKKnob

**A premium rotary knob widget for RadioKit** with configurable angle range, optional centre‑spring and division snapping.

## Constructor
```dart
RKKnob({
  required double value,
  required ValueChanged<double> onChanged,
  double min = 0.0,
  double max = 1.0,
  double size = 100.0,
  String? label,
  int? divisions,
  ValueChanged<bool>? onInteractionChanged,
  double minAngle = -135.0,
  double maxAngle = 135.0,
  bool autoCenter = false,
  double center = 0.5,
  Curve springCurve = Curves.easeOutCubic,
  Duration springDuration = const Duration(milliseconds: 500),
  RKKnobVariant variant = RKKnobVariant.standard,
  RKAxis orientation = RKAxis.vertical,
  double rotation = 0.0,
  IconData? centerIcon,
})
```

| Parameter | Description |
|---|---|
| `value` | Normalised knob position (between `min` and `max`). |
| `onChanged` | Called with the new value when the user drags. |
| `size` | Diameter of the knob widget. |
| `label` | Optional text label displayed above the widget. |
| `divisions` | If set, the knob snaps to the specified number of steps. |
| `onInteractionChanged` | Triggered when the user starts or stops touching the widget. |
| `minAngle` / `maxAngle` | Angular range in degrees (default –135° to +135°). |
| `autoCenter` | When true, the knob springs back to `center` after interaction. |
| `center` | Normalised centre position used for auto‑centering. |
| `springCurve` / `springDuration` | Controls the spring‑back animation. |
| `variant` | The visual style: `standard` or `steeringWheel`. |
| `orientation` | Orientation of the knob layout: `vertical` (default) or `horizontal`. |
| `rotation` | Visual rotation of the widget in radians. |
| `centerIcon` | Optional icon to display in the middle of the knob. |


## Example
```dart
double _volume = 0.7;

RKKnob(
  value: _volume,
  onChanged: (v) => setState(() => _volume = v),
  divisions: 10,
  label: 'Vol',
);
```

The knob supports multiple visual styles:
- **Standard**: A 3‑D industrial rotary encoder with an animated thumb.
- **Steering Wheel**: A premium automotive-inspired wheel with dynamic rim glow and a central hub featuring a Renault-style logo.

