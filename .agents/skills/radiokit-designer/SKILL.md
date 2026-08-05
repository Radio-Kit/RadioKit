---
name: radiokit-designer
description: Guide for working with the RadioKit visual Designer and Arduino code generation. This skill should be used when modifying the designer screen, inspector panels, JSON config schema, codegen pipeline, or widget templates in the Flutter app.
---

# RadioKit Designer & Code Generation

## Overview

The RadioKit Designer is a visual UI builder that lets users drag-and-drop widgets onto a canvas, configure their properties, and generate Arduino code (`RADIOKIT.h`). It serializes to a standardized JSON format and generates complete C++ code.

## Designer Architecture

```
radiokit-app/lib/screens/designer/
  designer_screen.dart              # Main screen (canvas + inspector)
  codegen/
    json_arduino_generator.dart     # JSON → RADIOKIT.h generation
    arduino_generator.dart          # Legacy generator
    widget_templates.dart           # Per-widget C++ code templates
    header_file_parser.dart         # Parse existing RADIOKIT.h
  utils/
    file_download.dart              # Export/download helpers
  widgets/
    designer_inspector.dart         # Property inspector panel
    designer_widget_dialog.dart     # Widget type picker dialog
    inspector_field_builders.dart   # Reusable field builder methods

flutter-widgets/lib/src/
  models/
    widget_definition.dart          # Abstract WidgetDefinition contract
    widget_registry.dart            # Central WidgetRegistry singleton
    inspector_property_schema.dart  # Schema-driven inspector property fields
  widgets/
    definitions/                    # Modular widget definitions (buttons, sliders, display)
```

## Widget Registry & Schema Architecture

All designer widgets are registered in `WidgetRegistry.instance`:

```dart
// Registering a widget definition
WidgetRegistry.instance.register(ButtonWidgetDefinition());

// Looking up property schemas for dynamic inspector rendering
final def = WidgetRegistry.instance.getDefinition(widgetType);
final schemas = def?.propertySchemas ?? [];
```

## JSON Config Schema

### Top-Level Structure

```json
{
  "version": 1,
  "config": {
    "name": "DeviceName",
    "description": "Description",
    "theme": "RK_DEFAULT",
    "orientation": "landscape",
    "width": 0,
    "height": 0,
    "password": "",
    "device_icon": "zap"
  },
  "canvas": {
    "size": [200, 100]
  },
  "widgets": [...]
}
```

### Widget Entry

```json
{
  "type": "slider",
  "variant": "gasPedal",
  "name": "slider_1",
  "position": [50, 30, 0],
  "size": [null, 20],
  "label": { "text": "Speed", "show": true },
  "autoCenter": ["min", "smooth", 300],
  "haptic": true,
  "properties": {
    "min": 0,
    "max": 100,
    "detents": 0
  }
}
```

### Field Encoding Rules

| Field | Format | Example |
|-------|--------|---------|
| `canvas.size` | `[width, height]` | `[200, 100]` |
| `position` | `[x, y, rotation]` | `[93, 12, 0]` |
| `size` | `[width, height]` (null = auto) | `[null, 20]` |
| `autoCenter` | `[position, springType, duration]` | `["center", "smooth", 500]` |
| `label` | `{ "text": "...", "show": bool }` | `{ "text": "btn", "show": true }` |

### Variant Placement

Variants are promoted to top-level only for base-type derivatives:

- **Promoted** (stripped from properties): `gasPedal`, `steeringWheel`, `multiButton`, `multiSelect`, `rockerSwitch`
- **Stays in properties**: `push`/`toggle` (button mode), other type-specific variants

### AutoCenter Defaults

| Widget | Default autoCenter |
|--------|--------------------|
| Slider | `[null, 'smooth', 300]` (disabled) |
| GasPedal | `['min', 'smooth', 300]` (enabled) |
| Knob | `[null, 'smooth', 500]` (disabled) |
| SteeringWheel | `['center', 'smooth', 500]` (enabled) |
| Joystick | `['center', 'smooth', 300]` (enabled) |

## Code Generation

### JsonArduinoGenerator

The main entry point is `JsonArduinoGenerator.generate(jsonMap)`:

```dart
final json = jsonDecode(radioKitHeader);
final code = JsonArduinoGenerator.generate(json);
// Returns complete RADIOKIT.h content
```

### Generated Output Structure

```cpp
/*__RADIOKIT_Designer_Config__
{ ... JSON config ... }
RADIOKIT_Designer_Config__*/

#pragma once
#include <RadioKitLib.h>

// Widget declarations
RK_PushButton button_1(20, 60, 20);
RK_Slider slider_1(100, 50, 12, 80);
RK_LED led_1(20, 20, 15);

inline void initRadioKit() {
  // Widget configuration from designer
  button_1.rk.onText = "ON";
  button_1.rk.offText = "OFF";
  button_1.rk.icon = "power";
  slider_1.rk.centering = RK_SPRING_CENTER;
  slider_1.rk.label = "Speed";
  led_1.rk.color = 0x00FF00;
  led_1.rk.shape = RK_LED_SHAPE_CIRCLE;
}
```

### Widget Name Conventions

- Names use `snake_case`: `button_1`, `slider_2`, `joystick_1`
- Auto-generated from type + sequential number
- The `name` field is the C++ identifier (not renamed)

### Widget Templates

Each widget type has a template in `widget_templates.dart` that defines:
- Constructor call format
- rk field assignments
- Property-to-field mapping

## Inspector Panel

### Field Builders

All inspector fields use `InspectorFieldBuilders` static methods:

```dart
InspectorFieldBuilders.buildTextField(tokens, label, value, onChanged)
InspectorFieldBuilders.buildNumField(tokens, label, value, onChanged, {min, max})
InspectorFieldBuilders.buildBoolToggle(tokens, label, value, onChanged)
InspectorFieldBuilders.buildOptionSelector(tokens, label, value, options, onChanged)
InspectorFieldBuilders.buildCenterPinnedSelector(tokens, label, value, options, onChanged)
InspectorFieldBuilders.buildButtonGroup(tokens, label, value, options, onChanged, {labels})
InspectorFieldBuilders.buildRotationSlider(tokens, value, onChanged, {onReset})
InspectorFieldBuilders.buildSection(tokens, title, children)
```

### Icon Selector

```dart
IconFieldBuilder.buildIconSelectorField(context, label, currentIconName, onChanged)
```

Icon registry: `kDesignerIcons` (a `Map<String, IconData>` using Lucide icons).

### Multi-Item Editor

For `multiButton`/`multiSelect` widgets, use `_DesignerMultiItemEditor`:
- Items stored as `properties['items']` (list of maps)
- Each item: `{ onLabel, onIcon, offLabel, offIcon }`
- Sync `properties['items']` when `properties['itemCount']` changes
- Default items auto-generate `onLabel` from A, B, C...

## Skin System

Four skins: `DRAGON`, `NEON`, `MINIMAL`, `CUSTOM`.

- Built-in skins are `static const` singletons
- CUSTOM skin must be a distinct instance: `RKTokens.dragon.copyWith()`
- Only CUSTOM skin is editable (6 color fields + radius + elevation)
- Color picker: `showColorPickerDialog` from `flex_color_picker`

## State Management

`DesignerState` extends `ChangeNotifier`:
- Every mutation calls `_pushUndo()` first (undo stack)
- `updateElementProperty(id, key, value)` for single properties
- `updateElementSize(id, width:, height:)` for dimensions
- `updateElementPosition(id, x, y)` for position
- `updateElementRotation(id, rotation)` for rotation

## Canvas Rendering

- Widgets with fixed aspect ratios use `renderedGridSize` (tuple `(int, int)`)
- `aspectRatio` getter: positive = horizontal, negative = vertical
- Debug overlay: `showDebug: true` only for selected element in designer mode
- Global `RKDebugOverlay.enabled` toggled by designer screen

## Demo JSON Files

Demo configurations live in `radiokit-app/assets/demos/`:
- `widgets_demo.json` — full widget showcase
- `rc_controller.json` — RC truck controller
- `iot_dashboard.json` — IoT sensor dashboard
