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
    final rotationRad = element.rotation * math.pi / 180;

    if (isPlayMode) {
      Widget w = _buildWidget(context);
      if (rotationRad != 0) {
        w = Transform.rotate(angle: rotationRad, child: w);
      }
      return w;
    }

    // Use the rendered size so the bounding box matches the debug overlay.
    // For fixed-aspect-ratio widgets (button, knob, etc.) this is square:
    // min(width, height) × min(width, height).
    final (rw, rh) = element.renderedGridSize;
    final rWpx = rw.toDouble() * cs;
    final rHpx = rh.toDouble() * cs;

    Widget child = IgnorePointer(
      child: _buildWidget(context),
    );

    child = SizedBox(
      width: rWpx,
      height: rHpx,
      child: child,
    );

    // Rotate the entire widget together. Rotation is applied here so individual
    // widgets don't need to handle it, avoiding double-rotation.
    // The pivot is Alignment.center to match the handle position calculation
    // in designer_canvas.dart, which rotates debug-box corners around the
    // element centre.
    if (rotationRad != 0) {
      child = Transform.rotate(
        angle: rotationRad,
        alignment: Alignment.center,
        child: child,
      );
    }

    return child;
  }

  Widget _buildWidget(BuildContext context) {
    final cs = _cellSize;
    final isPlay = isPlayMode && designerState != null;
    final id = element.id;
    // In play mode the global RKDebugOverlay.enabled is false, so showDebug
    // is irrelevant; pass false for clarity. In designer mode only the
    // selected element shows the debug border.
    final showDebug = isPlayMode ? false : isSelected;

    switch (element.type) {
      case DesignerElementType.button:
        return RKButton(
          mode: element.properties['variant'] == 'toggle'
              ? RKButtonMode.toggle
              : RKButtonMode.push,
          onText: element.properties['onText'] ?? 'ON',
          offText: element.properties['offText'] ?? 'OFF',
          onIcon: iconFromName(element.properties['onIcon'] as String?),
          offIcon: iconFromName(element.properties['offIcon'] as String?),
          enableHapticFeedback: element.properties['haptic'] ?? true,
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
          showDebug: showDebug,
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
          enableHapticFeedback: element.properties['haptic'] ?? true,
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
          showDebug: showDebug,
        );

      case DesignerElementType.rockerSwitch:
        return RKRockerSwitch(
          value: isPlay
              ? (designerState!.getRuntimeWidgetValue(id, false) as bool)
              : false,
          onChanged: isPlay
              ? (v) => designerState!.setRuntimeWidgetValue(id, v)
              : (_) {},
          onIcon: iconFromName(element.properties['onIcon'] as String?),
          offIcon: iconFromName(element.properties['offIcon'] as String?),
          enableHapticFeedback: element.properties['haptic'] ?? true,
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
          showDebug: showDebug,
        );

      case DesignerElementType.slider:
        return _buildSlider(id, isPlay, cs, showDebug);

      case DesignerElementType.steeringWheel:
        return RKSteeringWheel(
            centerIcon: iconFromName(element.properties['centerIcon'] as String?),
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
            label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
            size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
            showDebug: showDebug,
          );

      case DesignerElementType.knob:
        return RKKnob(
          centerIcon: iconFromName(element.properties['centerIcon'] as String?),
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
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
          showDebug: showDebug,
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
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
          showDebug: showDebug,
        );

      case DesignerElementType.multiButton:
        final mbCount = (element.properties['itemCount'] as num?)?.toInt() ?? 3;
        return _buildMultiButton(id, mbCount, isPlay, cs, showDebug);

      case DesignerElementType.multiSelect:
        final msCount = (element.properties['itemCount'] as num?)?.toInt() ?? 3;
        return _buildMultiSelect(id, msCount, isPlay, cs, showDebug);

      case DesignerElementType.gasPedal:
        return _buildGasPedal(id, isPlay, cs, showDebug);

      case DesignerElementType.led:
        return RKLed(
          showDebug: showDebug,
          state: _getLEDState(element.properties['state'] as String?),
          shape: _getLEDShape(element.properties['shape'] as String?),
          color: element.properties['color'] != null
              ? Color(element.properties['color'] as int)
              : null,
          timing: (element.properties['timing'] as num?)?.toInt() ?? 500,
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          size: math.min(element.width.toDouble(), element.height.toDouble()) * cs,
        );

      case DesignerElementType.text:
        return RKDisplay(
          text: element.properties['text'] ?? 'Display',
          fontSize: (element.properties['fontSize'] as num?)?.toDouble() ?? 14,
          fontFamily: element.properties['fontFamily'] ?? 'monospace',
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
          showDebug: showDebug,
        );

      case DesignerElementType.serialMonitor:
        return RKSerialMonitor(
          messages: const ['> Serial Monitor'],
          fontSize: (element.properties['fontSize'] as num?)?.toDouble() ?? 12,
          fontFamily: element.properties['fontFamily'] ?? 'monospace',
          label: (!element.labelHidden && element.label.isNotEmpty) ? element.label : null,
          width: element.width.toDouble() * cs,
          height: element.height.toDouble() * cs,
          showDebug: showDebug,
        );
    }
  }

  Widget _buildSlider(String id, bool isPlay, double cs, bool showDebug) {
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
      label: element.label.isNotEmpty ? element.label : null,
      showDebug: showDebug,
    );
  }

  Widget _buildMultiButton(String id, int count, bool isPlay, double cs, bool showDebug) {
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
      enableHapticFeedback: element.properties['haptic'] ?? true,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      label: element.label.isNotEmpty ? element.label : null,
      showDebug: showDebug,
    );
  }

  Widget _buildMultiSelect(String id, int count, bool isPlay, double cs, bool showDebug) {
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
      enableHapticFeedback: element.properties['haptic'] ?? true,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      label: element.label.isNotEmpty ? element.label : null,
      showDebug: showDebug,
    );
  }

  Widget _buildGasPedal(String id, bool isPlay, double cs, bool showDebug) {
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
      label: element.label.isNotEmpty ? element.label : null,
      showDebug: showDebug,
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

