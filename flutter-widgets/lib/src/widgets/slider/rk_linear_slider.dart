import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_debug_overlay.dart';
import '../rk_rotated_wrapper.dart';

class RKSlider extends StatefulWidget {
  const RKSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.orientation = RKAxis.horizontal,
    this.thickness = 11.0,
    this.length = 200.0,
    this.onInteractionChanged,
    this.autoCenter = false,
    this.center = 0.5,
    this.springCurve = Curves.easeOutCubic,
    this.springDuration = const Duration(milliseconds: 300),
    this.divisions,
    this.showTicks = true,
    this.tickCount = 20,
    this.rotation = 0.0,
    this.label,
    this.builder,
    this.invertGesture = false,
    this.showDebug = true,
    this.showPillBackground = true,
    this.pillPadding = 8.0,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final double min;
  final double max;
  final RKAxis orientation;
  final double thickness;
  final double length;
  final bool autoCenter;
  final double center;
  final Curve springCurve;
  final Duration springDuration;
  final int? divisions;
  final bool showTicks;
  final int tickCount;
  final double rotation;
  final String? label;
  final Widget Function(BuildContext, RKTokens, double normalized)? builder;
  final bool invertGesture;
  final bool showDebug;
  final bool showPillBackground;
  final double pillPadding;

  @override
  State<RKSlider> createState() => _RKSliderState();
}

class _RKSliderState extends State<RKSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _centerController;
  Animation<double>? _centerAnimation;

  double? _lastEmittedValue;
  final List<double> _echoBuffer = [];
  bool _isInteracting = false;

  double get _range => widget.max - widget.min;
  bool get _hasValidRange => _range.abs() > 0.000001;
  double get _thumbWidth => widget.orientation == RKAxis.horizontal
      ? widget.thickness * 4.5
      : widget.thickness * 6.0;

  double get _thumbHeight => widget.orientation == RKAxis.horizontal
      ? widget.thickness * 6.0
      : widget.thickness * 4.5;

  double get _travelInset => math.max(2, widget.thickness * 0.9);

  void _addToHistory(double val) {
    _echoBuffer.add(val);
    if (_echoBuffer.length > 20) {
      _echoBuffer.removeAt(0);
    }
  }

  double _clampValue(double value) {
    final minV = math.min(widget.min, widget.max);
    final maxV = math.max(widget.min, widget.max);
    return value.clamp(minV, maxV);
  }

  double _normalizedFromValue(double value) {
    if (!_hasValidRange) return 0.0;
    return ((value - widget.min) / _range).clamp(0.0, 1.0);
  }

  double _snapToDivisions(double value) {
    final divisions = widget.divisions;
    if (divisions == null || divisions <= 0 || !_hasValidRange) {
      return _clampValue(value);
    }
    final step = _range / divisions;
    if (step.abs() <= 0.000001) {
      return _clampValue(value);
    }
    final snapped =
        ((value - widget.min) / step).round() * step + widget.min;
    return _clampValue(snapped);
  }

  void _emitValue(double value) {
    final newValue = _snapToDivisions(_clampValue(value));
    if (_lastEmittedValue != null &&
        (newValue - _lastEmittedValue!).abs() < 0.000001) {
      return;
    }
    _lastEmittedValue = newValue;
    _addToHistory(newValue);
    widget.onChanged(newValue);
  }

  @override
  void initState() {
    super.initState();
    _centerController = AnimationController(
      vsync: this,
      duration: widget.springDuration,
    )..addListener(_handleCenterTick);
  }

  void _handleCenterTick() {
    final animation = _centerAnimation;
    if (animation == null) return;
    _emitValue(animation.value);
  }

  @override
  void didUpdateWidget(covariant RKSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.springDuration != oldWidget.springDuration) {
      _centerController.duration = widget.springDuration;
    }

    if (_isInteracting) return;

    if (widget.value != oldWidget.value) {
      if (_hasValidRange) {
        final rangeAbs = _range.abs();
        final isEcho = _echoBuffer.any(
          (v) => (v - widget.value).abs() < rangeAbs * 0.03,
        );
        if (!isEcho) {
          final diff = (widget.value - (_lastEmittedValue ?? widget.value)).abs();
          if (diff > rangeAbs * 0.05) {
            _lastEmittedValue = widget.value;
            if (_centerController.isAnimating) {
              _centerController.stop();
            }
          }
        }
      } else {
        _lastEmittedValue = widget.value;
        if (_centerController.isAnimating) {
          _centerController.stop();
        }
      }
    }

    if (widget.autoCenter &&
        (widget.autoCenter != oldWidget.autoCenter ||
            widget.center != oldWidget.center)) {
      _triggerCenter();
    }
  }

  @override
  void dispose() {
    _centerController
      ..removeListener(_handleCenterTick)
      ..dispose();
    super.dispose();
  }

  void _triggerCenter() {
    if (!widget.autoCenter || !_hasValidRange) return;

    final targetNormalized = widget.center.clamp(0.0, 1.0);
    final targetValue = widget.min + targetNormalized * _range;

    _centerController.stop();
    _centerAnimation = Tween<double>(
      begin: _clampValue(widget.value),
      end: _clampValue(targetValue),
    ).animate(
      CurvedAnimation(
        parent: _centerController,
        curve: widget.springCurve,
      ),
    );
    _centerController.forward(from: 0.0);
  }

  void _handleUpdate(Offset localPos, Size size) {
    if (!_hasValidRange) return;
    if (_centerController.isAnimating) {
      _centerController.stop();
    }

    final thumbMainSize =
        widget.orientation == RKAxis.horizontal ? _thumbWidth : _thumbHeight;
    final endpointInset = _travelInset + thumbMainSize / 2;

    double progress;

    if (widget.orientation == RKAxis.horizontal) {
      final start = endpointInset;
      final end = math.max(start + 1.0, size.width - endpointInset);
      progress = ((localPos.dx - start) / (end - start)).clamp(0.0, 1.0);
    } else {
      final start = endpointInset;
      final end = math.max(start + 1.0, size.height - endpointInset);
      progress = (1.0 - ((localPos.dy - start) / (end - start))).clamp(0.0, 1.0);
    }

    if (widget.invertGesture) {
      progress = 1.0 - progress;
    }

    final newVal = widget.min + progress * _range;
    _emitValue(newVal);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final normalized = _normalizedFromValue(_clampValue(widget.value));
    final zeroPos = _normalizedFromValue(0.0);

    final double contentW =
        widget.orientation == RKAxis.horizontal ? widget.length : widget.thickness * 8.8;
    final double contentH =
        widget.orientation == RKAxis.vertical ? widget.length : widget.thickness * 6.8;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: false,
      contentWidth: contentW,
      contentHeight: contentH,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
      fitContent: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          setState(() => _isInteracting = true);
          widget.onInteractionChanged?.call(true);
          _handleUpdate(details.localPosition, Size(contentW, contentH));
        },
        onPanUpdate: (details) {
          _handleUpdate(details.localPosition, Size(contentW, contentH));
        },
        onPanCancel: () {
          setState(() => _isInteracting = false);
          widget.onInteractionChanged?.call(false);
          if (widget.autoCenter) {
            _triggerCenter();
          }
        },
        onPanEnd: (_) {
          setState(() => _isInteracting = false);
          widget.onInteractionChanged?.call(false);
          if (widget.autoCenter) {
            _triggerCenter();
          }
        },
        child: SizedBox(
          width: contentW,
          height: contentH,
          child: widget.builder != null
              ? widget.builder!(context, tokens, normalized)
              : ClipRect(
                  child: CustomPaint(
                    painter: _LinearSliderPainter(
                      normalized: normalized,
                      zeroPos: zeroPos,
                      tokens: tokens,
                      orientation: widget.orientation,
                      thickness: widget.thickness,
                      showTicks: widget.showTicks,
                      tickCount: widget.tickCount,
                      showPillBackground: widget.showPillBackground,
                      showDebug: widget.showDebug,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LinearSliderPainter extends CustomPainter {
  _LinearSliderPainter({
    required this.normalized,
    required this.zeroPos,
    required this.tokens,
    required this.orientation,
    required this.thickness,
    required this.showTicks,
    required this.tickCount,
    required this.showPillBackground,
    required this.showDebug,
  });

  final double normalized;
  final double zeroPos;
  final RKTokens tokens;
  final RKAxis orientation;
  final double thickness;
  final bool showTicks;
  final int tickCount;
  final bool showPillBackground;
  final bool showDebug;

  double get _pillRadius => tokens.radiusSelector;
  double get _trackRadius => tokens.radiusField;
  double get _travelInset => math.max(2, thickness * 0.9);

  @override
  void paint(Canvas canvas, Size size) {
    final isHorizontal = orientation == RKAxis.horizontal;
    final centerY = size.height / 2;
    final centerX = size.width / 2;
    canvas.save();

    final thumbWidth = isHorizontal
        ? math.min(thickness * 4.5, size.width)
        : math.min(thickness * 6.0, size.width);

    final thumbHeight = isHorizontal
        ? math.min(thickness * 6.0, size.height)
        : math.min(thickness * 4.5, size.height);

    final thumbMainAxisSize = isHorizontal ? thumbWidth : thumbHeight;
    final thumbHalfMainAxis = thumbMainAxisSize / 2;
    final endpointInset = _travelInset + thumbHalfMainAxis;

    final travelStart = endpointInset;
    final travelEnd =
        (isHorizontal ? size.width : size.height) - endpointInset;
    final travelLength = math.max(0.0, travelEnd - travelStart);

    final trackThickness = thickness;
    final trackRect = isHorizontal
        ? Rect.fromLTWH(
            travelStart,
            centerY - trackThickness / 2,
            travelLength,
            trackThickness,
          )
        : Rect.fromLTWH(
            centerX - trackThickness / 2,
            travelStart,
            trackThickness,
            travelLength,
          );

    if (showPillBackground && tokens.depth > 0) {
      final pillRect = Offset.zero & size;

      if (size.width > 0 && size.height > 0) {
        final pillRRect = RRect.fromRectAndRadius(
          pillRect,
          Radius.circular(_pillRadius),
        );

        final shadowPaint = Paint()
          ..color = tokens.base300.withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
        canvas.drawRRect(
          pillRRect,
          shadowPaint,
        );

        final fillPaint = Paint()
          ..color = tokens.surface
          ..style = PaintingStyle.fill;
        canvas.drawRRect(pillRRect, fillPaint);
      }
    }

    if (showDebug && RKDebugOverlay.enabled) {
      final debugPaint = Paint()
        ..color = const Color(0x55AAFFFF)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final debugRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          0.75,
          0.75,
          size.width - 1.5,
          size.height - 1.5,
        ),
        Radius.circular(_pillRadius),
      );

      final path = Path()..addRRect(debugRect);
      final metrics = path.computeMetrics();
      const double dashLength = 4.0;
      const double gapLength = 3.0;
      for (final metric in metrics) {
        double distance = 0;
        while (distance < metric.length) {
          final end = (distance + dashLength).clamp(0.0, metric.length);
          final segment = metric.extractPath(distance, end);
          canvas.drawPath(segment, debugPaint);
          distance += dashLength + gapLength;
        }
      }
    }

    if (trackRect.width <= 0 || trackRect.height <= 0) {
      canvas.restore();
      return;
    }

    final trackRRect =
        RRect.fromRectAndRadius(trackRect, Radius.circular(_trackRadius));

    final trackBgPaint = Paint()
      ..color = tokens.base200
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackBgPaint);

    final trackBorderPaint = Paint()
      ..color = tokens.effectiveOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, thickness * 0.08);
    canvas.drawRRect(trackRRect, trackBorderPaint);

    final innerDeflate = math.min(thickness * 0.16, thickness / 2 - 0.1);
    final innerTrackRect = trackRect.deflate(innerDeflate);
    if (innerTrackRect.width > 0 && innerTrackRect.height > 0) {
      final innerPaint = Paint()
        ..color = tokens.onSurface.withValues(alpha: 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          innerTrackRect,
          Radius.circular(math.max(0.0, _trackRadius - innerDeflate)),
        ),
        innerPaint,
      );
    }

    final thumbCenter = isHorizontal
        ? Offset(travelStart + normalized * travelLength, centerY)
        : Offset(centerX, travelEnd - normalized * travelLength);

    final zeroCenter = isHorizontal
        ? Offset(travelStart + zeroPos * travelLength, centerY)
        : Offset(centerX, travelEnd - zeroPos * travelLength);

    final activeHeight = thickness * 0.48;
    final activeFillPaint = Paint()
      ..color = tokens.effectiveOutline.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    final activeRect = isHorizontal
        ? Rect.fromLTRB(
            math.min(zeroCenter.dx, thumbCenter.dx),
            centerY - activeHeight / 2,
            math.max(zeroCenter.dx, thumbCenter.dx),
            centerY + activeHeight / 2,
          )
        : Rect.fromLTRB(
            centerX - activeHeight / 2,
            math.min(zeroCenter.dy, thumbCenter.dy),
            centerX + activeHeight / 2,
            math.max(zeroCenter.dy, thumbCenter.dy),
          );

    if (activeRect.width > 0 && activeRect.height > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          activeRect,
          Radius.circular(activeHeight / 2),
        ),
        activeFillPaint,
      );
    }

    if (showTicks && tickCount > 0) {
      final minorPaint = Paint()
        ..color = tokens.onSurface.withValues(alpha: 0.40)
        ..strokeWidth = math.max(1.0, thickness * 0.09)
        ..strokeCap = StrokeCap.round;

      final majorPaint = Paint()
        ..color = tokens.onSurface.withValues(alpha: 0.55)
        ..strokeWidth = math.max(1.0, thickness * 0.13)
        ..strokeCap = StrokeCap.round;

      final majorEvery = tickCount > 10 ? 5 : 2;
      final tickOffset = thickness * 0.82;

      if (isHorizontal) {
        final startX = travelStart;
        final endX = travelEnd;
        for (int i = 0; i <= tickCount; i++) {
          final t = i / tickCount;
          final x = startX + (endX - startX) * t;
          final isMajor = i % majorEvery == 0;
          final paint = isMajor ? majorPaint : minorPaint;
          final h = isMajor ? thickness * 1.05 : thickness * 0.62;

          canvas.drawLine(
            Offset(x, centerY - tickOffset),
            Offset(x, centerY - tickOffset - h),
            paint,
          );
          canvas.drawLine(
            Offset(x, centerY + tickOffset),
            Offset(x, centerY + tickOffset + h),
            paint,
          );
        }
      } else {
        final startY = travelEnd;
        final endY = travelStart;
        for (int i = 0; i <= tickCount; i++) {
          final t = i / tickCount;
          final y = startY + (endY - startY) * t;
          final isMajor = i % majorEvery == 0;
          final paint = isMajor ? majorPaint : minorPaint;
          final h = isMajor ? thickness * 1.05 : thickness * 0.62;

          canvas.drawLine(
            Offset(centerX - tickOffset, y),
            Offset(centerX - tickOffset - h, y),
            paint,
          );
          canvas.drawLine(
            Offset(centerX + tickOffset, y),
            Offset(centerX + tickOffset + h, y),
            paint,
          );
        }
      }
    }

    _drawThumb(canvas, thumbCenter, thumbWidth, thumbHeight);
    canvas.restore();
  }

  void _drawThumb(Canvas canvas, Offset center, double thumbWidth, double thumbHeight) {
    final outerRect = Rect.fromCenter(
      center: center,
      width: thumbWidth,
      height: thumbHeight,
    );
    final outerRadius = tokens.radiusField;
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(outerRadius),
    );

    if (tokens.depth > 0) {
      final dropShadowPaint = Paint()
        ..color = tokens.base300.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawRRect(
        outerRRect,
        dropShadowPaint,
      );
    }

    final fillPaint = Paint()
      ..color = tokens.primary
      ..style = PaintingStyle.fill;
    canvas.drawRRect(outerRRect, fillPaint);

    final borderPaint = Paint()
      ..color = tokens.primary.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, thickness * 0.14);
    canvas.drawRRect(
      outerRRect.deflate(thickness * 0.03),
      borderPaint,
    );

    final gripColor = tokens.surface.withValues(alpha: 0.58);
    final gripLength = thumbWidth * 0.42;
    final gripThickness = math.max(1.2, thickness * 0.18);
    final gripSpacing = gripThickness * 1.8;
    final gripCount = 4;
    final totalGripSpan =
        gripThickness * gripCount + gripSpacing * (gripCount - 1);
    final startY = center.dy - totalGripSpan / 2 + gripThickness / 2;

    for (int i = 0; i < gripCount; i++) {
      final cy = startY + i * (gripThickness + gripSpacing);
      final rRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, cy),
          width: gripLength,
          height: gripThickness,
        ),
        Radius.circular(gripThickness / 2),
      );
      canvas.drawRRect(rRect, Paint()..color = gripColor);
    }
  }

  @override
  bool shouldRepaint(covariant _LinearSliderPainter oldDelegate) {
    return oldDelegate.normalized != normalized ||
        oldDelegate.zeroPos != zeroPos ||
        oldDelegate.tokens != tokens ||
        oldDelegate.orientation != orientation ||
        oldDelegate.thickness != thickness ||
        oldDelegate.showTicks != showTicks ||
        oldDelegate.tickCount != tickCount ||
        oldDelegate.showPillBackground != showPillBackground ||
        oldDelegate.showDebug != showDebug;
  }
}