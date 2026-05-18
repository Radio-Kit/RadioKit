import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../models/designer_element.dart';
import '../models/designer_state.dart';

class CanvasElement extends StatelessWidget {
  final DesignerElement element;
  final bool isSelected;
  final bool isPlayMode;
  final DesignerState? designerState;

  const CanvasElement({
    super.key,
    required this.element,
    required this.isSelected,
    required this.isPlayMode,
    this.designerState,
  });

  double get _cellSize {
    if (designerState == null) return 3.0;
    return 600.0 / designerState!.canvasWidth;
  }

  @override
  Widget build(BuildContext context) {
    final cs = _cellSize;

    if (isPlayMode) {
      return _buildWidget(context);
    }

    final w = element.width.toDouble() * cs;
    final h = element.height.toDouble() * cs;
    final rotationRad = element.rotation * math.pi / 180;

    Widget child = IgnorePointer(
      child: _buildWidget(context),
    );

    if (isSelected) {
      child = SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            RKDebugOverlay(
              show: true,
              rotation: rotationRad,
            ),
          ],
        ),
      );
    } else {
      child = SizedBox(
        width: w,
        height: h,
        child: child,
      );
    }

    return child;
  }

  Widget _buildWidget(BuildContext context) {
    final cs = _cellSize;
    final rotationRad = element.rotation * math.pi / 180;
    final isPlay = isPlayMode && designerState != null;
    final id = element.id;

    switch (element.type) {
      case DesignerElementType.button:
        return RKButton(
          mode: element.properties['mode'] == 'toggle'
              ? RKButtonMode.toggle
              : RKButtonMode.push,
          onText: element.properties['onText'] ?? 'ON',
          offText: element.properties['offText'] ?? 'OFF',
          enableHapticFeedback: element.properties['enableHapticFeedback'] ?? true,
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
        );

      case DesignerElementType.slideSwitch:
        return RKSlideSwitch(
          value: isPlay
              ? (designerState!.getRuntimeWidgetValue(id, false) as bool)
              : false,
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          onText: element.properties['onText'] ?? 'ON',
          offText: element.properties['offText'] ?? 'OFF',
          enableHapticFeedback: element.properties['enableHapticFeedback'] ?? true,
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
        );

      case DesignerElementType.rockerSwitch:
        return RKRockerSwitch(
          value: isPlay
              ? (designerState!.getRuntimeWidgetValue(id, false) as bool)
              : false,
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          enableHapticFeedback: element.properties['enableHapticFeedback'] ?? true,
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
        );

      case DesignerElementType.slider:
        return _buildSlider(id, isPlay, cs, rotationRad);

      case DesignerElementType.steeringWheel:
        return RKSteeringWheel(
            value: isPlay
                ? (designerState!.getRuntimeWidgetValue(id, 0.5) as double)
                : 0.5,
            onChanged: isPlay
                ? (v) => designerState!.setRuntimeWidgetValue(id, v)
                : (_) {},
            min: (element.properties['min'] as num?)?.toDouble() ?? 0,
            max: (element.properties['max'] as num?)?.toDouble() ?? 100,
            minAngle: (element.properties['minAngle'] as num?)?.toDouble() ?? -135,
            maxAngle: (element.properties['maxAngle'] as num?)?.toDouble() ?? 135,
            autoCenter: element.properties['autoCenter'] ?? false,
            center: (element.properties['center'] as num?)?.toDouble() ?? 0.5,
            springCurve: _getCurve(element.properties['springBehavior'] as String?),
            springDuration: Duration(
              milliseconds: (element.properties['springDuration'] as num?)?.toInt() ?? 500,
            ),
            divisions: element.properties['divisions'] as int?,
            rotation: rotationRad,
            label: element.label.isNotEmpty ? element.label : null,
            size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
          );

      case DesignerElementType.knob:
        return RKKnob(
          value: isPlay
              ? (designerState!.getRuntimeWidgetValue(id, 0.5) as double)
              : 0.5,
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          min: (element.properties['min'] as num?)?.toDouble() ?? 0,
          max: (element.properties['max'] as num?)?.toDouble() ?? 100,
          minAngle: (element.properties['minAngle'] as num?)?.toDouble() ?? -135,
          maxAngle: (element.properties['maxAngle'] as num?)?.toDouble() ?? 135,
          autoCenter: element.properties['autoCenter'] ?? false,
          center: (element.properties['center'] as num?)?.toDouble() ?? 0.5,
          springCurve: _getCurve(element.properties['springBehavior'] as String?),
          springDuration: Duration(
            milliseconds: (element.properties['springDuration'] as num?)?.toInt() ?? 500,
          ),
          divisions: element.properties['divisions'] as int?,
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
        );

      case DesignerElementType.joystick:
        return RKJoystick(
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          autoCenter: element.properties['autoCenter'] ?? true,
          center: RKJoystickValue(
            x: (element.properties['centerX'] as num?)?.toDouble() ?? 0,
            y: (element.properties['centerY'] as num?)?.toDouble() ?? 0,
          ),
          springCurve: _getCurve(element.properties['springBehavior'] as String?),
          springDuration: Duration(
            milliseconds: (element.properties['springDuration'] as num?)?.toInt() ?? 300,
          ),
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
        );

      case DesignerElementType.multiButton:
        final mbCount = (element.properties['itemCount'] as num?)?.toInt() ?? 3;
        return _buildMultiButton(id, mbCount, isPlay, cs, rotationRad);

      case DesignerElementType.multiSelect:
        final msCount = (element.properties['itemCount'] as num?)?.toInt() ?? 3;
        return _buildMultiSelect(id, msCount, isPlay, cs, rotationRad);

      case DesignerElementType.gasPedal:
        return _buildGasPedal(id, isPlay, cs, rotationRad);

      case DesignerElementType.led:
        return RKLed(
          state: _getLEDState(element.properties['state'] as String?),
          shape: _getLEDShape(element.properties['shape'] as String?),
          color: element.properties['color'] != null
              ? Color(element.properties['color'] as int)
              : null,
          timing: (element.properties['timing'] as num?)?.toInt() ?? 500,
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
        );

      case DesignerElementType.text:
        return RKDisplay(
          text: element.properties['text'] ?? 'Display',
          fontSize: (element.properties['fontSize'] as num?)?.toDouble() ?? 14,
          fontFamily: element.properties['fontFamily'] ?? 'monospace',
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
        );

      case DesignerElementType.serialMonitor:
        return RKSerialMonitor(
          messages: const ['> Serial Monitor'],
          fontSize: (element.properties['fontSize'] as num?)?.toDouble() ?? 12,
          fontFamily: element.properties['fontFamily'] ?? 'monospace',
          rotation: rotationRad,
          label: element.label.isNotEmpty ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
        );
    }
  }

  Widget _buildSlider(String id, bool isPlay, double cs, double rotationRad) {
    final horizontal = element.width >= element.height;
    final pixelW = element.width.toDouble() * cs;
    final pixelH = element.height.toDouble() * cs;
    return RKSlider(
      value: isPlay
          ? (designerState!.getRuntimeWidgetValue(id, 0.5) as double)
          : 0.5,
      onChanged: isPlay
          ? (v) => designerState!.setRuntimeWidgetValue(id, v)
          : (_) {},
      min: (element.properties['min'] as num?)?.toDouble() ?? 0,
      max: (element.properties['max'] as num?)?.toDouble() ?? 100,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      thickness: horizontal ? pixelH / 8 : pixelW / 8,
      length: horizontal ? pixelW : pixelH,
      autoCenter: element.properties['autoCenter'] ?? false,
      center: (element.properties['center'] as num?)?.toDouble() ?? 0.5,
      springCurve: _getCurve(element.properties['springBehavior'] as String?),
      springDuration: Duration(
        milliseconds: (element.properties['springDuration'] as num?)?.toInt() ?? 300,
      ),
      divisions: element.properties['divisions'] as int?,
      rotation: rotationRad,
      label: element.label.isNotEmpty ? element.label : null,
    );
  }

  Widget _buildMultiButton(String id, int count, bool isPlay, double cs, double rotationRad) {
    final horizontal = element.width >= element.height;
    final pixelW = element.width.toDouble() * cs;
    final pixelH = element.height.toDouble() * cs;
    final spacing = 6.0;
    final padding = 8.0;
    final buttonSize = horizontal
        ? ((pixelW - padding * 2 - spacing * (count - 1)) / count)
            .clamp(10.0, pixelH - padding * 2)
        : ((pixelH - padding * 2 - spacing * (count - 1)) / count)
            .clamp(10.0, pixelW - padding * 2);
    return RKMultiButton(
      items: List.generate(count, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
      selected: isPlay ? (designerState!.getRuntimeWidgetValue(id, 0) as int?) ?? 0 : 0,
      onChanged: isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      buttonSize: buttonSize,
      enableHapticFeedback: element.properties['enableHapticFeedback'] ?? true,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      rotation: rotationRad,
      label: element.label.isNotEmpty ? element.label : null,
    );
  }

  Widget _buildMultiSelect(String id, int count, bool isPlay, double cs, double rotationRad) {
    final horizontal = element.width >= element.height;
    final pixelW = element.width.toDouble() * cs;
    final pixelH = element.height.toDouble() * cs;
    final spacing = 6.0;
    final padding = 8.0;
    final buttonSize = horizontal
        ? ((pixelW - padding * 2 - spacing * (count - 1)) / count)
            .clamp(10.0, pixelH - padding * 2)
        : ((pixelH - padding * 2 - spacing * (count - 1)) / count)
            .clamp(10.0, pixelW - padding * 2);
    return RKMultiSelect(
      items: List.generate(count, (i) => RKToggleItem(onLabel: String.fromCharCode(65 + i))),
      bitmask: isPlay ? (designerState!.getRuntimeWidgetValue(id, 0) as int?) ?? 0 : 0,
      onChanged: isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      buttonSize: buttonSize,
      enableHapticFeedback: element.properties['enableHapticFeedback'] ?? true,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      rotation: rotationRad,
      label: element.label.isNotEmpty ? element.label : null,
    );
  }

  Widget _buildGasPedal(String id, bool isPlay, double cs, double rotationRad) {
    final vertical = element.height > element.width;
    final pixelW = element.width.toDouble() * cs;
    final pixelH = element.height.toDouble() * cs;
    return RKGasPedal(
      value: isPlay ? (designerState!.getRuntimeWidgetValue(id, 0.0) as double) : 0.0,
      onChanged: isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      min: (element.properties['min'] as num?)?.toDouble() ?? 0,
      max: (element.properties['max'] as num?)?.toDouble() ?? 100,
      orientation: vertical ? RKAxis.vertical : RKAxis.horizontal,
      thickness: vertical ? pixelW / 8 : pixelH / 8,
      length: vertical ? pixelH : pixelW,
      autoCenter: element.properties['autoCenter'] ?? false,
      center: (element.properties['center'] as num?)?.toDouble() ?? 0.5,
      springCurve: _getCurve(element.properties['springBehavior'] as String?),
      springDuration: Duration(
        milliseconds: (element.properties['springDuration'] as num?)?.toInt() ?? 300,
      ),
      divisions: element.properties['divisions'] as int?,
      rotation: rotationRad,
      label: element.label.isNotEmpty ? element.label : null,
    );
  }

  Curve _getCurve(String? behavior) {
    switch (behavior) {
      case 'linear': return Curves.linear;
      case 'elastic': return Curves.elasticOut;
      default: return Curves.easeOutCubic;
    }
  }

  RKLEDState _getLEDState(String? state) {
    switch (state) {
      case 'on': return RKLEDState.on;
      case 'blink': return RKLEDState.blink;
      case 'breathe': return RKLEDState.breathe;
      default: return RKLEDState.off;
    }
  }

  RKLEDShape _getLEDShape(String? shape) {
    switch (shape) {
      case 'square': return RKLEDShape.square;
      case 'diamond': return RKLEDShape.diamond;
      case 'star': return RKLEDShape.star;
      default: return RKLEDShape.circle;
    }
  }
}


