# RKSlideSwitch

**A stealth neon industrial slide switch for RadioKit.** Features a heavy mechanical feel with "ON/OFF" engravings, a vibrant orange neon glow, and tactile grip ridges.

## Constructor
```dart
RKSlideSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
  double width = 190.0,
  double height = 82.0,
  Color? activeColor,
  bool enableHapticFeedback = true,
  ValueChanged<bool>? onInteractionChanged,
  double rotation = 0.0,
  String onText = 'ON',
  String offText = 'OFF',
  String? label,
})
```

> [!IMPORTANT]
> `RKSlideSwitch` supports tapping, continuous horizontal swipe, and high-velocity flick gestures for a realistic mechanical feel.

| Parameter | Description |
|---|---|
| `value` | Current logical state (`true` = ON). |
| `onChanged` | Called when the switch toggles. |
| `width` / `height` | Dimensions of the switch track. Default is 190x82. |
| `activeColor` | Color of the thumb when active. Defaults to industrial orange neon. |
| `enableHapticFeedback` | Emit a medium haptic pulse on state change. |
| `onInteractionChanged` | Callback for interaction start/end. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |
| `onText` | Text label for the ON state (stenciled). Defaults to 'ON'. |
| `offText` | Text label for the OFF state (stenciled). Defaults to 'OFF'. |

## Example
```dart
bool _isOn = false;

RKSlideSwitch(
  value: _isOn,
  onChanged: (v) => setState(() => _isOn = v),
);
```

The switch features a matte black pill-shaped casing with a recessed ultra-dark inner track. The labels feature a neon stenciled effect that illuminates when active.
