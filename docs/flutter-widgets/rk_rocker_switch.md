# RKRockerSwitch

**A premium 3D rocker switch for RadioKit** featuring:

- Symmetrical ON/OFF rocker movement
- Mechanical snap animation
- Perspective tilt and rounded face
- Optional custom icons for the ON and OFF positions
- Active glow on the ON state
- Haptic feedback (optional)

## Constructor
```dart
RKRockerSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
  double width = 72.0,
  double height = 110.0,
  Widget? onIcon,
  Widget? offIcon,
  Color? activeColor,
  bool enableHapticFeedback = true,
  ValueChanged<bool>? onInteractionChanged,
  double rotation = 0.0,
  String? label,
})
```

> [!NOTE]
> `RKRockerSwitch` is a fixed vertical toggle switch.

| Parameter | Description |
|---|---|
| `value` | Current logical state (`true` = ON). |
| `onChanged` | Callback invoked when the switch toggles. |
| `width` / `height` | Size of the switch bezel. |
| `onIcon` / `offIcon` | Optional custom widgets displayed for each state. |
| `activeColor` | Colour of the glow when ON; defaults to theme primary. |
| `enableHapticFeedback` | Emit a medium‑impact haptic pulse on taps and drags. |
| `onInteractionChanged` | Optional callback when the user begins/ends interaction. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |

## Example
```dart
bool _isOn = false;

RKRockerSwitch(
  value: _isOn,
  onChanged: (v) => setState(() => _isOn = v),
  activeColor: Colors.redAccent,
);
```

The widget animates a 3‑D rocker with realistic shadows and a glowing rim when activated.
