import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/designer_element.dart';
import '../../models/inspector_property_schema.dart';
import '../../models/widget_definition.dart';
import '../../utils/auto_center_helpers.dart';
import '../../utils/icon_registry.dart';
import '../joystick/rk_joystick.dart';
import '../multiple/rk_multi_button.dart';
import '../led/rk_led.dart';
import '../display/rk_display.dart';
import '../display/rk_serial_monitor.dart';

class JoystickWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'joystick';

  @override
  DesignerElementType get type => DesignerElementType.joystick;

  @override
  String get displayName => 'Joystick';

  @override
  IconData get icon => Icons.gamepad;

  @override
  (int, int) get defaultSize => (30, 30);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) => 1.0;

  @override
  Map<String, dynamic> get defaultProperties => {
        'centerX': 0.0,
        'centerY': 0.0,
        'autoCenter': ['center', 'smooth', 300],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'centerX', label: 'Center X'),
        NumPropertySchema(key: 'centerY', label: 'Center Y'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final acList = ctx.properties['autoCenter'] as List?;
    return RKJoystick(
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      autoCenter: acEnabled(acList),
      center: RKJoystickValue(
        x: (ctx.properties['centerX'] as num?)?.toDouble() ?? 0,
        y: (ctx.properties['centerY'] as num?)?.toDouble() ?? 0,
      ),
      springCurve: acCurve(acList),
      springDuration: Duration(milliseconds: acDuration(acList, 300)),
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      size: math.min(ctx.width.toDouble(), ctx.height.toDouble()) * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class MultiButtonWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'multiButton';

  @override
  DesignerElementType get type => DesignerElementType.multiButton;

  @override
  String get displayName => 'Multi Button';

  @override
  IconData get icon => Icons.grid_view;

  @override
  (int, int) get defaultSize => (30, 15);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) {
    final count = (properties['itemCount'] as num?)?.toInt() ?? 3;
    final baseAr = (count * 0.67).clamp(0.5, 10.0);
    return width >= height ? baseAr : -baseAr;
  }

  @override
  Map<String, dynamic> get defaultProperties => {
        'itemCount': 3,
        'items': [
          {'onLabel': 'A', 'onIcon': null, 'offLabel': null, 'offIcon': null},
          {'onLabel': 'B', 'onIcon': null, 'offLabel': null, 'offIcon': null},
          {'onLabel': 'C', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        ],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'itemCount', label: 'Button Count', min: 2, max: 8),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final rawItems = (ctx.properties['items'] as List?) ?? [];
    final toggleItems = rawItems.map((e) {
      final map = e is Map ? e : {};
      return RKToggleItem(
        onLabel: map['onLabel'] as String?,
        offLabel: map['offLabel'] as String?,
        onIcon: iconFromName(map['onIcon'] as String?),
        offIcon: iconFromName(map['offIcon'] as String?),
      );
    }).toList();

    return RKMultiButton(
      items: toggleItems,
      selected: ctx.isPlayMode ? (ctx.runtimeValue as int? ?? -1) : -1,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class MultiSelectWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'multiSelect';

  @override
  DesignerElementType get type => DesignerElementType.multiSelect;

  @override
  String get displayName => 'Multi Select';

  @override
  IconData get icon => Icons.view_headline;

  @override
  (int, int) get defaultSize => (30, 15);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) {
    final count = (properties['itemCount'] as num?)?.toInt() ?? 3;
    final baseAr = (count * 0.67).clamp(0.5, 10.0);
    return width >= height ? baseAr : -baseAr;
  }

  @override
  Map<String, dynamic> get defaultProperties => {
        'itemCount': 3,
        'items': [
          {'onLabel': 'A', 'onIcon': null, 'offLabel': null, 'offIcon': null},
          {'onLabel': 'B', 'onIcon': null, 'offLabel': null, 'offIcon': null},
          {'onLabel': 'C', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        ],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'itemCount', label: 'Item Count', min: 2, max: 8),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final rawItems = (ctx.properties['items'] as List?) ?? [];
    final toggleItems = rawItems.map((e) {
      final map = e is Map ? e : {};
      return RKToggleItem(
        onLabel: map['onLabel'] as String?,
        offLabel: map['offLabel'] as String?,
        onIcon: iconFromName(map['onIcon'] as String?),
        offIcon: iconFromName(map['offIcon'] as String?),
      );
    }).toList();

    return RKMultiSelect(
      items: toggleItems,
      bitmask: ctx.isPlayMode ? (ctx.runtimeValue as int? ?? 0) : 0,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class LedWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'led';

  @override
  DesignerElementType get type => DesignerElementType.led;

  @override
  String get displayName => 'LED';

  @override
  IconData get icon => Icons.lightbulb;

  @override
  (int, int) get defaultSize => (15, 15);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) => 1.0;

  @override
  Map<String, dynamic> get defaultProperties => {
        'state': 'off',
        'shape': 'circle',
        'color': null,
        'timing': 500,
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        OptionPropertySchema(
          key: 'state',
          label: 'State',
          options: ['off', 'on', 'blink', 'breathe'],
        ),
        OptionPropertySchema(
          key: 'shape',
          label: 'Shape',
          options: ['circle', 'square', 'diamond', 'star'],
        ),
        NumPropertySchema(key: 'timing', label: 'Timing (ms)'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    RKLEDState getLEDState(String? state) {
      switch (state) {
        case 'on': return RKLEDState.on;
        case 'blink': return RKLEDState.blink;
        case 'breathe': return RKLEDState.breathe;
        default: return RKLEDState.off;
      }
    }

    RKLEDShape getLEDShape(String? shape) {
      switch (shape) {
        case 'square': return RKLEDShape.square;
        case 'diamond': return RKLEDShape.diamond;
        case 'star': return RKLEDShape.star;
        default: return RKLEDShape.circle;
      }
    }

    return RKLed(
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
      state: getLEDState(ctx.properties['state'] as String?),
      shape: getLEDShape(ctx.properties['shape'] as String?),
      color: ctx.properties['color'] != null
          ? Color(ctx.properties['color'] as int)
          : null,
      timing: (ctx.properties['timing'] as num?)?.toInt() ?? 500,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      size: math.min(ctx.width.toDouble(), ctx.height.toDouble()) * ctx.cellSize,
    );
  }
}

class TextWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'text';

  @override
  DesignerElementType get type => DesignerElementType.text;

  @override
  String get displayName => 'Display';

  @override
  IconData get icon => Icons.text_fields;

  @override
  (int, int) get defaultSize => (30, 10);

  @override
  Map<String, dynamic> get defaultProperties => {
        'text': 'Display',
        'fontSize': 14.0,
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        TextPropertySchema(key: 'text', label: 'Text'),
        NumPropertySchema(key: 'fontSize', label: 'Font Size'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    return RKDisplay(
      text: ctx.properties['text'] ?? 'Display',
      fontSize: (ctx.properties['fontSize'] as num?)?.toDouble() ?? 14,
      width: ctx.width.toDouble() * ctx.cellSize,
      height: ctx.height.toDouble() * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class SerialMonitorWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'serialMonitor';

  @override
  DesignerElementType get type => DesignerElementType.serialMonitor;

  @override
  String get displayName => 'Serial Monitor';

  @override
  IconData get icon => Icons.terminal;

  @override
  (int, int) get defaultSize => (40, 20);

  @override
  Map<String, dynamic> get defaultProperties => {
        'autoscroll': true,
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        BoolPropertySchema(key: 'autoscroll', label: 'Auto Scroll'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final smLogs = ctx.runtimeValue as List<String>? ?? [];
    return RKSerialMonitor(
      messages: smLogs,
      width: ctx.width.toDouble() * ctx.cellSize,
      height: ctx.height.toDouble() * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}
