# RKMultiSelect

**Bitmask multi‑select group for RadioKit** – displays a grid or wrap of "Tactical" buttons where multiple items can be active simultaneously, represented by a bitmask.

## Constructor
```dart
RKMultiSelect({
  required List<RKToggleItem> items,
  required int bitmask,
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
| `bitmask` | An integer where the $i$-th bit represents the state of `items[i]`. |
| `onChanged` | Called with the updated bitmask when an item is toggled. |
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
int _bitmask = 0; // No items selected

RKMultiSelect(
  items: const [
    RKToggleItem(onLabel: 'Radar', onIcon: Icons.radar),
    RKToggleItem(onLabel: 'GPS', onIcon: Icons.gps_fixed),
    RKToggleItem(onLabel: 'Comms', onIcon: Icons.settings_input_antenna),
  ],
  bitmask: _bitmask,
  orientation: RKAxis.horizontal,
  onChanged: (int newBitmask) => setState(() => _bitmask = newBitmask),
);
```

The active buttons use the theme's `primaryGradient` and `glows`, while inactive buttons use a translucent `surface` style.
