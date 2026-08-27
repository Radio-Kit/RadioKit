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

    final (rw, rh) = element.renderedGridSize;
    final rWpx = rw.toDouble() * cs;
    final rHpx = rh.toDouble() * cs;

    Widget child = _buildWidget(context);

    // Hidden widgets are completely invisible in both play and designer mode.
    if (element.hidden) {
      return const SizedBox.shrink();
    }

    if (!isPlayMode) {
      child = IgnorePointer(child: child);
    }

    child = SizedBox(
      width: rWpx,
      height: rHpx,
      child: child,
    );

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

    final definition = WidgetRegistry.instance.getByType(element.type);
    if (definition != null) {
      final runtimeVal = isPlay ? designerState!.getRuntimeWidgetValue(id, null) : null;
      final buildCtx = WidgetBuildContext(
        id: id,
        type: element.type,
        properties: element.properties,
        runtimeValue: runtimeVal,
        onChanged: isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : null,
        isPlayMode: isPlay,
        isSelected: isSelected,
        cellSize: cs,
        width: element.width,
        height: element.height,
        label: element.label,
        labelHidden: element.labelHidden,
      );
      return definition.buildCanvasWidget(context, buildCtx);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSlider(String id, bool isPlay, double cs, bool showDebug) {
    final horizontal = element.width >= element.height;
    final pixelW = element.width.toDouble() * cs;
    final pixelH = element.height.toDouble() * cs;
    return RKSlider(
      value: isPlay
          ? (designerState!.getRuntimeWidgetValue(id, 0.5) as double)
          : 0.5,
      onChanged:
          isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      min: (element.properties['min'] as num?)?.toDouble() ?? 0,
      max: (element.properties['max'] as num?)?.toDouble() ?? 100,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      thickness: horizontal ? pixelH / 8 : pixelW / 8,
      length: horizontal ? pixelW : pixelH,
      autoCenter: _acEnabled(element.properties['autoCenter'] as List?),
      center: _acPosition(element.properties['autoCenter'] as List?),
      springCurve: _acCurve(element.properties['autoCenter'] as List?),
      springDuration: Duration(
        milliseconds:
            _acDuration(element.properties['autoCenter'] as List?, 300),
      ),
      divisions: element.properties['divisions'] as int?,
      label: (!element.labelHidden && element.label.isNotEmpty)
          ? element.label
          : null,
      showDebug: showDebug,
    );
  }

  Widget _buildMultiButton(
      String id, int count, bool isPlay, double cs, bool showDebug) {
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
    final rawItems = element.properties['items'] as List?;
    final items = List.generate(count, (i) {
      final raw = (rawItems != null && i < rawItems.length)
          ? rawItems[i] as Map?
          : null;
      return RKToggleItem(
        onLabel: (raw?['onLabel'] == null)
            ? null
            : (raw?['onLabel'] as String? ?? String.fromCharCode(65 + i)),
        onIcon: iconFromName(raw?['onIcon'] as String?),
        offLabel:
            (raw?['offLabel'] == null) ? null : (raw?['offLabel'] as String?),
        offIcon: iconFromName(raw?['offIcon'] as String?),
      );
    });
    final itemMask = isPlay
        ? ((element.properties['itemMask'] as num?)?.toInt() ?? 0xFF)
        : 0xFF;
    return RKMultiButton(
      items: items,
      selected: isPlay
          ? (designerState!.getRuntimeWidgetValue(id, 0) as int?) ?? 0
          : 0,
      onChanged:
          isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      itemMask: itemMask,
      buttonSize: buttonSize,
      enableHapticFeedback: element.properties['haptic'] ?? true,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      label: (!element.labelHidden && element.label.isNotEmpty)
          ? element.label
          : null,
      showDebug: showDebug,
    );
  }

  Widget _buildMultiSelect(
      String id, int count, bool isPlay, double cs, bool showDebug) {
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
    final rawItems = element.properties['items'] as List?;
    final items = List.generate(count, (i) {
      final raw = (rawItems != null && i < rawItems.length)
          ? rawItems[i] as Map?
          : null;
      return RKToggleItem(
        onLabel: (raw?['onLabel'] == null)
            ? null
            : (raw?['onLabel'] as String? ?? String.fromCharCode(65 + i)),
        onIcon: iconFromName(raw?['onIcon'] as String?),
        offLabel:
            (raw?['offLabel'] == null) ? null : (raw?['offLabel'] as String?),
        offIcon: iconFromName(raw?['offIcon'] as String?),
      );
    });
    final itemMask = isPlay
        ? ((element.properties['itemMask'] as num?)?.toInt() ?? 0xFF)
        : 0xFF;
    return RKMultiSelect(
      items: items,
      bitmask: isPlay
          ? (designerState!.getRuntimeWidgetValue(id, 0) as int?) ?? 0
          : 0,
      onChanged:
          isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      itemMask: itemMask,
      buttonSize: buttonSize,
      enableHapticFeedback: element.properties['haptic'] ?? true,
      orientation: horizontal ? RKAxis.horizontal : RKAxis.vertical,
      label: (!element.labelHidden && element.label.isNotEmpty)
          ? element.label
          : null,
      showDebug: showDebug,
    );
  }

  Widget _buildGasPedal(String id, bool isPlay, double cs, bool showDebug) {
    final vertical = element.height > element.width;
    final pixelW = element.width.toDouble() * cs;
    final pixelH = element.height.toDouble() * cs;
    return RKGasPedal(
      value: isPlay
          ? (designerState!.getRuntimeWidgetValue(id, 0.0) as double)
          : 0.0,
      onChanged:
          isPlay ? (v) => designerState!.setRuntimeWidgetValue(id, v) : (_) {},
      min: (element.properties['min'] as num?)?.toDouble() ?? 0,
      max: (element.properties['max'] as num?)?.toDouble() ?? 100,
      orientation: vertical ? RKAxis.vertical : RKAxis.horizontal,
      thickness: vertical ? pixelW / 8 : pixelH / 8,
      length: vertical ? pixelH : pixelW,
      autoCenter: _acEnabled(element.properties['autoCenter'] as List?),
      center: _acPosition(element.properties['autoCenter'] as List?),
      springCurve: _acCurve(element.properties['autoCenter'] as List?),
      springDuration: Duration(
        milliseconds:
            _acDuration(element.properties['autoCenter'] as List?, 300),
      ),
      divisions: element.properties['divisions'] as int?,
      label: (!element.labelHidden && element.label.isNotEmpty)
          ? element.label
          : null,
      showDebug: showDebug,
    );
  }

  Curve _acCurve(List<dynamic>? ac) {
    final type = ac?[1] as String? ?? 'smooth';
    switch (type) {
      case 'linear':
        return Curves.linear;
      case 'elastic':
        return Curves.elasticOut;
      default:
        return Curves.easeOutCubic;
    }
  }

  double _acPosition(List<dynamic>? ac) {
    final pos = ac?[0] as String?;
    switch (pos) {
      case 'min':
        return 0.0;
      case 'max':
        return 1.0;
      case 'center':
      default:
        return 0.5;
    }
  }

  bool _acEnabled(List<dynamic>? ac) =>
      (ac?[0] as String?) != null;

  int _acDuration(List<dynamic>? ac, int fallback) =>
      (ac?[2] as num?)?.toInt() ?? fallback;

  RKLEDState _getLEDState(String? state) {
    switch (state) {
      case 'on':
        return RKLEDState.on;
      case 'blink':
        return RKLEDState.blink;
      case 'breathe':
        return RKLEDState.breathe;
      default:
        return RKLEDState.off;
    }
  }

  RKLEDShape _getLEDShape(String? shape) {
    switch (shape) {
      case 'square':
        return RKLEDShape.square;
      case 'diamond':
        return RKLEDShape.diamond;
      case 'star':
        return RKLEDShape.star;
      default:
        return RKLEDShape.circle;
    }
  }
}
