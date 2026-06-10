# RKSerialMonitor

A serial monitor widget for RadioKit, designed to display a streaming list of text messages. It supports auto-scrolling to the latest message and customizable typography.

## Example Usage

```dart
import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class MySerialMonitorDemo extends StatelessWidget {
  final List<String> messages = [
    '> SYS: Booting...',
    '> SYS: Online',
    '> MSG: Connection established.',
  ];

  @override
  Widget build(BuildContext context) {
    return RKSerialMonitor(
      messages: messages,
      width: 300,
      height: 200,
      fontFamily: 'monospace',
      textColor: Colors.greenAccent,
      autoScroll: true,
    );
  }
}
```

## Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `messages` | `List<String>` | **Required** | The list of string messages to display in the monitor. |
| `width` | `double` | `300` | The width of the serial monitor container. |
| `height` | `double` | `200` | The height of the serial monitor container. |
| `fontSize` | `double` | `12` | The font size for the text messages. |
| `fontFamily` | `String` | `'monospace'` | The font family to use for the messages. |
| `textColor` | `Color?` | `null` | The color of the text. Defaults to the theme's primary color if not provided. |
| `onInteractionChanged` | `ValueChanged<bool>?` | `null` | Triggered when the user starts or stops touching the serial monitor. |
| `rotation` | `double` | `0.0` | Visual rotation of the widget in radians. |
| `label` | `String?` | `null` | Optional text label displayed above the widget. |
