# RKDisplay

**A text display output widget for RadioKit** – shows a single line of text inside a styled container.

## Constructor
```dart
RKDisplay({
  required String text,
  double width = 180.0,
  double height = 40.0,
  double fontSize = 14.0,
  String fontFamily = 'monospace',
  Color? textColor,
  RKAxis orientation = RKAxis.horizontal,
  ValueChanged<bool>? onInteractionChanged,
  double rotation = 0.0,
  String? label,
})
```

| Parameter | Description |
|---|---|
| `text` | The string to display. |
| `width` / `height` | Size of the display container. |
| `fontSize` | Font size of the text. |
| `fontFamily` | Font family of the text (default is 'monospace'). |
| `textColor` | Custom text color. If null, uses the theme's primary color. |
| `orientation` | Horizontal or vertical layout (`RKAxis`). |
| `onInteractionChanged` | Triggered when the user starts or stops touching the widget. |
| `rotation` | Visual rotation of the widget in radians. |
| `label` | Optional text label displayed above the widget. |

The widget uses the theme's `surface` colour as background and a border using `trackColor`.

## Example
```dart
RKDisplay(
  text: '12.34 V',
  width: 120,
  height: 40,
  fontSize: 20,
  orientation: RKAxis.horizontal,
);
```
