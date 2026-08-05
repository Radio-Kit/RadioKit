import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/designer_element.dart';
import '../../models/inspector_property_schema.dart';
import '../../models/widget_definition.dart';
import '../../theme/rk_theme.dart';
import '../../utils/auto_center_helpers.dart';
import '../../utils/icon_registry.dart';
import '../rk_rotated_wrapper.dart';
import '../slider/rk_linear_slider.dart';
import '../knob/rk_knob.dart';
import '../knob/rk_steering_wheel.dart';
import '../slider/rk_gas_pedal.dart';

class SliderWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'slider';

  @override
  DesignerElementType get type => DesignerElementType.slider;

  @override
  String get displayName => 'Slider';

  @override
  IconData get icon => Icons.tune;

  @override
  (int, int) get defaultSize => (30, 10);

  @override
  Map<String, dynamic> get defaultProperties => {
        'min': 0.0,
        'max': 100.0,
        'divisions': null,
        'autoCenter': [null, 'smooth', 300],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'min', label: 'Minimum'),
        NumPropertySchema(key: 'max', label: 'Maximum'),
        NumPropertySchema(key: 'divisions', label: 'Divisions'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final vertical = ctx.height > ctx.width;
    final pixelW = ctx.width.toDouble() * ctx.cellSize;
    final pixelH = ctx.height.toDouble() * ctx.cellSize;
    final acList = ctx.properties['autoCenter'] as List?;

    return RKSlider(
      value: ctx.runtimeValue as double? ?? 0.0,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      min: (ctx.properties['min'] as num?)?.toDouble() ?? 0,
      max: (ctx.properties['max'] as num?)?.toDouble() ?? 100,
      orientation: vertical ? RKAxis.vertical : RKAxis.horizontal,
      thickness: vertical ? pixelW / 8 : pixelH / 8,
      length: vertical ? pixelH : pixelW,
      autoCenter: acEnabled(acList),
      center: acPosition(acList),
      springCurve: acCurve(acList),
      springDuration: Duration(milliseconds: acDuration(acList, 300)),
      divisions: ctx.properties['divisions'] as int?,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class KnobWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'knob';

  @override
  DesignerElementType get type => DesignerElementType.knob;

  @override
  String get displayName => 'Knob';

  @override
  IconData get icon => Icons.adjust;

  @override
  (int, int) get defaultSize => (20, 20);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) => 1.0;

  @override
  Map<String, dynamic> get defaultProperties => {
        'min': 0.0,
        'max': 100.0,
        'minAngle': -135.0,
        'maxAngle': 135.0,
        'divisions': null,
        'centerIcon': null,
        'autoCenter': [null, 'smooth', 500],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'min', label: 'Minimum'),
        NumPropertySchema(key: 'max', label: 'Maximum'),
        NumPropertySchema(key: 'minAngle', label: 'Min Angle'),
        NumPropertySchema(key: 'maxAngle', label: 'Max Angle'),
        NumPropertySchema(key: 'divisions', label: 'Divisions'),
        IconPropertySchema(key: 'centerIcon', label: 'Center Icon'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final acList = ctx.properties['autoCenter'] as List?;
    return RKKnob(
      centerIcon: iconFromName(ctx.properties['centerIcon'] as String?),
      value: ctx.runtimeValue as double? ?? 0.5,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      min: (ctx.properties['min'] as num?)?.toDouble() ?? 0,
      max: (ctx.properties['max'] as num?)?.toDouble() ?? 100,
      minAngle: (ctx.properties['minAngle'] as num?)?.toDouble() ?? -135,
      maxAngle: (ctx.properties['maxAngle'] as num?)?.toDouble() ?? 135,
      autoCenter: acEnabled(acList),
      center: acPosition(acList),
      springCurve: acCurve(acList),
      springDuration: Duration(milliseconds: acDuration(acList, 500)),
      divisions: ctx.properties['divisions'] as int?,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      size: math.min(ctx.width.toDouble(), ctx.height.toDouble()) * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class SteeringWheelWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'steeringWheel';

  @override
  DesignerElementType get type => DesignerElementType.steeringWheel;

  @override
  String get displayName => 'Steering Wheel';

  @override
  IconData get icon => Icons.sports_motorsports;

  @override
  (int, int) get defaultSize => (24, 24);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) => 1.0;

  @override
  Map<String, dynamic> get defaultProperties => {
        'min': 0.0,
        'max': 100.0,
        'minAngle': -135.0,
        'maxAngle': 135.0,
        'divisions': null,
        'centerIcon': null,
        'autoCenter': ['center', 'smooth', 500],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'min', label: 'Minimum'),
        NumPropertySchema(key: 'max', label: 'Maximum'),
        NumPropertySchema(key: 'minAngle', label: 'Min Angle'),
        NumPropertySchema(key: 'maxAngle', label: 'Max Angle'),
        IconPropertySchema(key: 'centerIcon', label: 'Center Icon'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final acList = ctx.properties['autoCenter'] as List?;
    return RKSteeringWheel(
      centerIcon: iconFromName(ctx.properties['centerIcon'] as String?),
      value: ctx.runtimeValue as double? ?? 0.5,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      min: (ctx.properties['min'] as num?)?.toDouble() ?? 0,
      max: (ctx.properties['max'] as num?)?.toDouble() ?? 100,
      minAngle: (ctx.properties['minAngle'] as num?)?.toDouble() ?? -135,
      maxAngle: (ctx.properties['maxAngle'] as num?)?.toDouble() ?? 135,
      autoCenter: acEnabled(acList),
      center: acPosition(acList),
      springCurve: acCurve(acList),
      springDuration: Duration(milliseconds: acDuration(acList, 500)),
      divisions: ctx.properties['divisions'] as int?,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      size: math.min(ctx.width.toDouble(), ctx.height.toDouble()) * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class GasPedalWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'gasPedal';

  @override
  DesignerElementType get type => DesignerElementType.gasPedal;

  @override
  String get displayName => 'Gas Pedal';

  @override
  IconData get icon => Icons.speed;

  @override
  (int, int) get defaultSize => (10, 30);

  @override
  Map<String, dynamic> get defaultProperties => {
        'min': 0.0,
        'max': 100.0,
        'divisions': null,
        'autoCenter': ['min', 'smooth', 300],
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        NumPropertySchema(key: 'min', label: 'Minimum'),
        NumPropertySchema(key: 'max', label: 'Maximum'),
        NumPropertySchema(key: 'divisions', label: 'Divisions'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final vertical = ctx.height > ctx.width;
    final pixelW = ctx.width.toDouble() * ctx.cellSize;
    final pixelH = ctx.height.toDouble() * ctx.cellSize;
    final acList = ctx.properties['autoCenter'] as List?;

    return RKGasPedal(
      value: ctx.runtimeValue as double? ?? 0.0,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      min: (ctx.properties['min'] as num?)?.toDouble() ?? 0,
      max: (ctx.properties['max'] as num?)?.toDouble() ?? 100,
      orientation: vertical ? RKAxis.vertical : RKAxis.horizontal,
      thickness: vertical ? pixelW / 8 : pixelH / 8,
      length: vertical ? pixelH : pixelW,
      autoCenter: acEnabled(acList),
      center: acPosition(acList),
      springCurve: acCurve(acList),
      springDuration: Duration(milliseconds: acDuration(acList, 300)),
      divisions: ctx.properties['divisions'] as int?,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}
