# RKSlider

**A premium linear slider widget for RadioKit** with an industrial aesthetic, optional self‑centering and fill‑from‑zero support.

## Constructor
```dart
RKSlider({
  required double value,
  required ValueChanged<double> onChanged,
  double min = 0.0,
  double max = 1.0,
  RKAxis orientation = RKAxis.horizontal,
  RKSliderType type = RKSliderType.linear,
  double thickness = 11.0,
  double length = 200.0,
  ValueChanged<bool>? onInteractionChanged,
  bool autoCenter = false,
  double center = 0.5,
  Curve springCurve = Curves.easeOutCubic,
  Duration springDuration = const Duration(milliseconds: 300),
  int? divisions,
  bool showTicks = true,
  int tickCount = 20,
  double rotation = 0.0,
  String? label,
})
```

| Parameter | Description |
|---|---|
| `value` | Current slider value (normalized between `min` and `max`). |
| `onChanged` | Called with the new value when the user drags. |
| `orientation` | Horizontal or vertical orientation (`RKAxis`). |
| `type` | Variant type (`linear` or `gasPedal`). |
| `thickness` | Track thickness in logical pixels. |
| `length` | Total length of the slider (width for horizontal, height for vertical). |
| `onInteractionChanged` | Triggered when the user starts or stops touching the widget. |
| `autoCenter` | When true, the slider animates back to `center` after interaction ends. |
| `center` | Normalized centre position (0‑1) used when `autoCenter` is enabled. |
| `divisions` | If set, the slider snaps to the given number of discrete steps. |
| `showTicks` / `tickCount` | Show minor/major tick marks along the track. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |

## Gas Pedal Variant
The `RKSliderType.gasPedal` variant provides a 3D perspective-transformed pedal aesthetic. It uses the same logical parameters as the standard slider but renders a premium industrial pedal that tilts and glows based on input.

> [!NOTE]
> The Gas Pedal is best used with `autoCenter: true` and `center: 0.0` for a realistic spring-back feel.

## Example
```dart
double _val = 0.5;

RKSlider(
  value: _val,
  onChanged: (v) => setState(() => _val = v),
  min: 0,
  max: 100,
  orientation: RKAxis.horizontal,
  autoCenter: true,
  center: 0.5,
);
```

The slider features a solid primary thumb with a sharp industrial look, a faint active fill (50% opacity), and a duller tick grid for reduced visual noise.
