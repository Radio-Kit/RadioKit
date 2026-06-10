# RadioKit Widgets

A Flutter widget library providing hardware‑control UI components designed for use with the [RadioKit](https://github.com/rambros3d/RadioKit) Arduino framework.

## Installation

Add the package to your **pubspec.yaml**:

```yaml
dependencies:
  radiokit_widgets:
    path: ../flutter-library  # or published version when available
```

Import the public library entry point:

```dart
import 'package:radiokit_widgets/radiokit_widgets.dart';
```

## Widgets Overview

| Widget | Description |
|--------|-------------|
| [RKButton](rk_button.md) | Momentary or toggle push button with haptic feedback |
| [RKSwitch](rk_switch.md) | Material-style toggle switch |
| [RKSlideSwitch](rk_slide_switch.md) | iOS-style slide toggle |
| [RKRockerSwitch](rk_rocker_switch.md) | Rocker-style on/off switch |
| [RKSlider](rk_slider.md) | Linear slider with value display |
| [RKKnob](rk_knob.md) | Rotary knob with spring physics |
| [RKJoystick](rk_joystick.md) | 2-axis joystick control |
| [RKLed](rk_led.md) | LED indicator with colour control |
| [RKMultiButton](rk_multi_button.md) | Radio-style button group |
| [RKMultiSelect](rk_multi_select.md) | Checkbox-style multi-select |
| [RKDisplay](rk_display.md) | Read-only text display |
| [RKSerialMonitor](rk_serial_monitor.md) | Serial console widget |

Each widget follows the RadioKit visual language – industrial‑grade, 3‑D depth, and optional haptic feedback.

## Getting Started

```dart
import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  bool _buttonOn = false;
  double _sliderValue = 0.5;
  double _knobValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return RKTheme(
      tokens: RKTokens.defaultTokens(),
      child: Scaffold(
        backgroundColor: RKTheme.of(context).surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle button with haptic feedback
              RKButton(
                mode: RKButtonMode.toggle,
                label: 'Power',
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _buttonOn = v),
              ),
              const SizedBox(height: 24),
              
              // Slider with value display
              RKSlider(
                value: _sliderValue,
                min: 0,
                max: 100,
                divisions: 10,
                label: 'Throttle',
                onChanged: (v) => setState(() => _sliderValue = v),
              ),
              const SizedBox(height: 24),
              
              // Rotary knob
              RKKnob(
                value: _knobValue,
                onChanged: (v) => setState(() => _knobValue = v),
                label: 'Steer',
              ),
              
              // LED indicator
              const SizedBox(height: 24),
              RKLed(
                state: _buttonOn,
                color: _buttonOn ? Colors.green : Colors.red,
                label: 'Status',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Theming

All widgets use `RKTheme` for consistent styling:

```dart
RKTheme(
  tokens: RKTokens.defaultTokens().copyWith(
    primary: Colors.cyan,
    surface: const Color(0xFF1A1A2E),
    background: const Color(0xFF16213E),
  ),
  child: MyApp(),
)
```

## Widget Features

- **Haptic Feedback**: Optional vibration on interaction (enabled by default)
- **Spring Physics**: Smooth, physical-feeling animations
- **Rotation Support**: All widgets support `rotation` parameter
- **Label Support**: Optional text labels above widgets
- **Accessibility**: Full semantics support
- **Responsive**: Adapts to available space

## Integration with RadioKit Arduino Library

This widget library pairs perfectly with the [RadioKit Arduino library](../../arduino-library):

```dart
// In your Flutter app, use radiokit_widgets for UI
// and connect to Arduino via BLE or Serial

RKSlider(
  value: _throttleValue,
  onChanged: (v) {
    setState(() => _throttleValue = v);
    // Send to Arduino via BLE
    _bleService.sendSliderValue('throttle', v);
  },
)
```

See the [example app](../../flutter-app) for a complete BLE-connected implementation.

## Learn More

- [RKButton API](rk_button.md) — Full button documentation
- [RKSlider API](rk_slider.md) — Slider with value display
- [RKKnob API](rk_knob.md) — Rotary control
- [RKJoystick API](rk_joystick.md) — 2-axis control
- [RKLed API](rk_led.md) — LED indicator

## License

MIT — see [LICENSE](../../LICENSE).