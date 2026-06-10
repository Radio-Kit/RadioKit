# RKLed

**LED indicator widget for RadioKit** – features multiple shapes (circle, square, diamond, star) and operating states including solid, blink, and breathe effects.

## Constructor
```dart
RKLed({
  RKLEDState state = RKLEDState.off,
  RKLEDShape shape = RKLEDShape.circle,
  double size = 24.0,
  Color? color,
  int timing = 500,
  double rotation = 0.0,
  String? label,
})
```

| Parameter | Description |
|---|---|
| `state` | Operating state: `off`, `on`, `blink`, or `breathe`. |
| `shape` | Visual shape: `circle`, `square`, `diamond`, or `star`. |
| `size` | Diameter/size of the LED. |
| `color` | Optional colour for the active state; defaults to theme primary. |
| `timing` | Animation speed in milliseconds for blink/breathe effects. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |

## Example
```dart
RKLed(
  state: RKLEDState.blink,
  color: Colors.green,
  shape: RKLEDShape.diamond,
);
```
