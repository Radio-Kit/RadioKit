# RKMultiButton

**Radio‑style multi‑button group for RadioKit** – displays a grid or wrap of premium "Tactical" buttons where exactly one is selected at a time.

## Constructor
```dart
RKMultiButton({
  required List<RKToggleItem> items,
  required int selected,
  required ValueChanged<int> onChanged,
  double buttonSize = 64.0,
  double spacing = 8.0,
  double padding = 12.0,
  bool enableHapticFeedback = true,
  RKAxis orientation = RKAxis.horizontal,
  ValueChanged<bool>? onActiveChanged,
  double rotation = 0.0,
  String? label,
})
```

| Parameter | Description |
|---|---|
| `items` | List of `RKToggleItem` (labels and icons) to display. |
| `selected` | Index of the currently active button. |
| `onChanged` | Called with the new selected index when a button is tapped. |
| `buttonSize` | The size (width and height) of each individual button. |
| `spacing` | The distance between buttons in the group. |
| `padding` | Inner padding of the group container. |
| `enableHapticFeedback` | Whether to trigger haptic feedback on interaction. |
| `orientation` | Horizontal or vertical layout (`RKAxis`). |
| `onActiveChanged` | Callback when the user starts/stops touching the group. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |

## RKToggleItem
A data model for buttons with state-specific labels and icons:
```dart
const RKToggleItem({
  String? onLabel,
  String? offLabel,
  IconData? onIcon,
  IconData? offIcon,
});
```

## Example
```dart
int _selectedIndex = 0;

RKMultiButton(
  items: const [
    RKToggleItem(onLabel: 'Cyber', onIcon: Icons.bolt_rounded),
    RKToggleItem(onLabel: 'Tactical', onIcon: Icons.gps_fixed_rounded),
    RKToggleItem(onLabel: 'Minimal', onIcon: Icons.remove_rounded),
  ],
  selected: _selectedIndex,
  orientation: RKAxis.horizontal,
  onChanged: (int index) => setState(() => _selectedIndex = index),
);
```

The active button uses the theme's `primaryGradient` and `glows`, while inactive buttons use a translucent `surface` style.
