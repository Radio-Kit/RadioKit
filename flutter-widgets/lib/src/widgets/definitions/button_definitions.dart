import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/designer_element.dart';
import '../../models/inspector_property_schema.dart';
import '../../models/widget_definition.dart';
import '../../utils/icon_registry.dart';
import '../button/rk_button.dart';
import '../switch/rk_slide_switch.dart';
import '../switch/rk_rocker_switch.dart';

class ButtonWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'button';

  @override
  DesignerElementType get type => DesignerElementType.button;

  @override
  String get displayName => 'Button';

  @override
  IconData get icon => Icons.touch_app;

  @override
  (int, int) get defaultSize => (10, 10);

  @override
  double? aspectRatio(Map<String, dynamic> properties, int width, int height) => 1.0;

  @override
  Map<String, dynamic> get defaultProperties => {
        'variant': 'push',
        'onText': 'ON',
        'offText': 'OFF',
        'onIcon': null,
        'offIcon': null,
        'haptic': true,
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        OptionPropertySchema(
          key: 'variant',
          label: 'Button Mode',
          options: ['push', 'toggle'],
        ),
        TextPropertySchema(key: 'onText', label: 'ON Label'),
        TextPropertySchema(key: 'offText', label: 'OFF Label'),
        IconPropertySchema(key: 'onIcon', label: 'ON Icon'),
        IconPropertySchema(key: 'offIcon', label: 'OFF Icon'),
        BoolPropertySchema(key: 'haptic', label: 'Haptic Feedback'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    return RKButton(
      mode: ctx.properties['variant'] == 'toggle'
          ? RKButtonMode.toggle
          : RKButtonMode.push,
      onText: ctx.properties['onText'] ?? 'ON',
      offText: ctx.properties['offText'] ?? 'OFF',
      onIcon: iconFromName(ctx.properties['onIcon'] as String?),
      offIcon: iconFromName(ctx.properties['offIcon'] as String?),
      enableHapticFeedback: ctx.properties['haptic'] ?? true,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      size: math.min(ctx.width.toDouble(), ctx.height.toDouble()) * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }

  @override
  String generateCppCode(CodegenContext ctx) => '';
}

class SlideSwitchWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'slideSwitch';

  @override
  DesignerElementType get type => DesignerElementType.slideSwitch;

  @override
  String get displayName => 'Slide Switch';

  @override
  IconData get icon => Icons.toggle_on;

  @override
  (int, int) get defaultSize => (20, 10);

  @override
  Map<String, dynamic> get defaultProperties => {
        'onText': 'ON',
        'offText': 'OFF',
        'onIcon': null,
        'offIcon': null,
        'haptic': true,
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        TextPropertySchema(key: 'onText', label: 'ON Label'),
        TextPropertySchema(key: 'offText', label: 'OFF Label'),
        IconPropertySchema(key: 'onIcon', label: 'ON Icon'),
        IconPropertySchema(key: 'offIcon', label: 'OFF Icon'),
        BoolPropertySchema(key: 'haptic', label: 'Haptic Feedback'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    final curVal = ctx.runtimeValue as bool? ?? false;
    final onIcon = iconFromName(ctx.properties['onIcon'] as String?);
    final offIcon = iconFromName(ctx.properties['offIcon'] as String?);
    Icon? switchIcon;
    if (onIcon != null || offIcon != null) {
      final iconData = curVal ? (onIcon ?? offIcon) : (offIcon ?? onIcon);
      switchIcon = Icon(iconData!);
    }

    return RKSlideSwitch(
      value: curVal,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      onText: ctx.properties['onText'] ?? 'ON',
      offText: ctx.properties['offText'] ?? 'OFF',
      icon: switchIcon,
      enableHapticFeedback: ctx.properties['haptic'] ?? true,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      width: ctx.width.toDouble() * ctx.cellSize,
      height: ctx.height.toDouble() * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}

class RockerSwitchWidgetDefinition extends WidgetDefinition {
  @override
  String get id => 'rockerSwitch';

  @override
  DesignerElementType get type => DesignerElementType.rockerSwitch;

  @override
  String get displayName => 'Rocker Switch';

  @override
  IconData get icon => Icons.power_settings_new;

  @override
  (int, int) get defaultSize => (16, 20);

  @override
  Map<String, dynamic> get defaultProperties => {
        'onIcon': null,
        'offIcon': null,
        'haptic': true,
      };

  @override
  List<InspectorPropertySchema> get propertiesSchema => const [
        IconPropertySchema(key: 'onIcon', label: 'ON Icon'),
        IconPropertySchema(key: 'offIcon', label: 'OFF Icon'),
        BoolPropertySchema(key: 'haptic', label: 'Haptic Feedback'),
      ];

  @override
  Widget buildCanvasWidget(BuildContext context, WidgetBuildContext ctx) {
    return RKRockerSwitch(
      value: ctx.runtimeValue as bool? ?? false,
      onChanged: ctx.isPlayMode && ctx.onChanged != null
          ? (v) => ctx.onChanged!(v)
          : (_) {},
      onIcon: iconFromName(ctx.properties['onIcon'] as String?),
      offIcon: iconFromName(ctx.properties['offIcon'] as String?),
      enableHapticFeedback: ctx.properties['haptic'] ?? true,
      label: (!ctx.labelHidden && ctx.label.isNotEmpty) ? ctx.label : null,
      width: ctx.width.toDouble() * ctx.cellSize,
      height: ctx.height.toDouble() * ctx.cellSize,
      showDebug: ctx.isPlayMode ? false : ctx.isSelected,
    );
  }
}
