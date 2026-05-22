import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

class RKSteeringWheel extends StatefulWidget {
  const RKSteeringWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.size = 100.0,
    this.divisions,
    this.onInteractionChanged,
    this.minAngle = -135.0,
    this.maxAngle = 135.0,
    this.autoCenter = false,
    this.center = 0.5,
    this.springCurve = Curves.easeOutCubic,
    this.springDuration = const Duration(milliseconds: 500),
    this.centerIcon,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  /// The fixed aspect ratio (width/height) for this widget.
  static const double? aspectRatio = 1.0;

  final IconData? centerIcon;
  final double rotation;
  final String? label;
  final bool showDebug;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final Curve springCurve;
  final Duration springDuration;
  final double min;
  final double max;
  final double size;
  final int? divisions;
  final double minAngle;
  final double maxAngle;
  final bool autoCenter;
  final double center;

  @override
  State<RKSteeringWheel> createState() => _RKSteeringWheelState();
}

class _RKSteeringWheelState extends State<RKSteeringWheel> with SingleTickerProviderStateMixin {
  late AnimationController _centerController;
  late Animation<double> _centerAnimation;
  double? _lastEmittedValue;
  double? _previousTouchAngle;
  double _currentAccumulatedRotation = 0;
  bool _isInteracting = false;
  final List<double> _echoBuffer = [];

  void _addToHistory(double val) {
    _echoBuffer.add(val);
    if (_echoBuffer.length > 20) _echoBuffer.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    _centerController = AnimationController(
      vsync: this,
      duration: widget.springDuration,
    );
    _centerAnimation = CurvedAnimation(
      parent: _centerController,
      curve: Curves.elasticOut,
    );
    _centerController.addListener(() {
      final val = widget.min + _centerAnimation.value * (widget.max - widget.min);
      _emitValue(val.clamp(widget.min, widget.max));
    });
  }

  @override
  void didUpdateWidget(RKSteeringWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.springDuration != oldWidget.springDuration) {
      _centerController.duration = widget.springDuration;
    }
    if (widget.value != oldWidget.value) {
      if (_isInteracting) return;

      final range = (widget.max - widget.min).abs();
      final isEcho = _echoBuffer.any((v) => (v - widget.value).abs() < range * 0.03);
      if (isEcho) return;

      if (_centerController.isAnimating) {
        final currentNorm = _centerAnimation.value;
        final currentVal = widget.min + currentNorm * (widget.max - widget.min);
        final diff = (widget.value - currentVal).abs();
        if (diff < range * 0.15) return;
      }

      _lastEmittedValue = widget.value;
      if (_centerController.isAnimating) _centerController.stop();
    }

    if ((widget.autoCenter && !oldWidget.autoCenter) ||
        (widget.autoCenter && widget.center != oldWidget.center)) {
      _triggerCenter();
    }
  }

  @override
  void dispose() {
    _centerController.dispose();
    super.dispose();
  }

  void _emitValue(double val) {
    if (val != _lastEmittedValue) {
      _lastEmittedValue = val;
      _addToHistory(val);
      Future.microtask(() => widget.onChanged(val));
    }
  }

  void _triggerCenter() {
    final startNorm = (widget.value - widget.min) / (widget.max - widget.min);
    if ((startNorm - widget.center).abs() < 0.001) return;

    _centerAnimation = Tween<double>(
      begin: startNorm,
      end: widget.center,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));
    _centerController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final normalized = (widget.value - widget.min) / (widget.max - widget.min);

    final sweepRad = (widget.maxAngle - widget.minAngle) * math.pi / 180;
    final startRad = (-math.pi / 2) + (widget.minAngle * math.pi / 180);
    final currentAngle = startRad + normalized * sweepRad;

    final double contentW = widget.size;
    final double contentH = widget.size;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: contentW,
      contentHeight: contentH,
      labelColor: tokens.trackColor.withValues(alpha: 0.8),
      fitContent: true,
      indicator: _RKKnobIndicator(normalized: normalized, tokens: tokens, knobSize: widget.size * 0.5),
      child: GestureDetector(
        onPanStart: (details) {
          _centerController.stop();
          setState(() => _isInteracting = true);
          widget.onInteractionChanged?.call(true);
          final radius = widget.size / 2;
          final localPos = details.localPosition;
          _previousTouchAngle = math.atan2(localPos.dy - radius, localPos.dx - radius) * 180 / math.pi;
          _currentAccumulatedRotation = (normalized - widget.center) * (widget.maxAngle - widget.minAngle);
        },
        onPanUpdate: (details) {
          if (_previousTouchAngle == null) return;
          final radius = widget.size / 2;
          final localPos = details.localPosition;
          final currentTouchAngle = math.atan2(localPos.dy - radius, localPos.dx - radius) * 180 / math.pi;
          double delta = currentTouchAngle - _previousTouchAngle!;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          if (delta.abs() < 1.5) return;
          _currentAccumulatedRotation += delta;
          _previousTouchAngle = currentTouchAngle;
          final minRot = (0.0 - widget.center) * (widget.maxAngle - widget.minAngle);
          final maxRot = (1.0 - widget.center) * (widget.maxAngle - widget.minAngle);
          final targetRotation = _currentAccumulatedRotation.clamp(minRot, maxRot);
          final norm = (targetRotation - minRot) / (maxRot - minRot);
          double newVal = widget.min + norm * (widget.max - widget.min);
          if (widget.divisions != null && widget.divisions! > 0) {
            final step = (widget.max - widget.min) / widget.divisions!;
            newVal = ((newVal - widget.min) / step).round() * step + widget.min;
          }
          final prevVal = _lastEmittedValue;
          if (prevVal != null) {
            final deadband = (widget.max - widget.min) * 0.003;
            if ((newVal - prevVal).abs() < deadband) return;
          }
          _emitValue(newVal);
        },
        onPanEnd: (_) {
          setState(() => _isInteracting = false);
          widget.onInteractionChanged?.call(false);
          if (widget.autoCenter) _triggerCenter();
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Transform.rotate(
            angle: currentAngle + math.pi / 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _SteeringWheelPainter(tokens: tokens),
                ),
                _SteeringWheelHub(tokens: tokens, centerIcon: widget.centerIcon, knobSize: widget.size),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SteeringWheelPainter extends CustomPainter {
  final RKTokens tokens;

  const _SteeringWheelPainter({
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final rect = Offset.zero & size;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.96);
    canvas.translate(-center.dx, -center.dy);

    final rimDark = Color.lerp(Colors.black, tokens.surface, 0.4)!;
    final rimMid = tokens.surface;
    final rimLight = tokens.primary;
    final spokeDark = Color.lerp(Colors.black, tokens.surface, 0.2)!;
    final spoke = tokens.surface;
    final hubDark = Color.lerp(Colors.black, tokens.surface, 0.5)!;
    final hubMid = tokens.surface;

    final fillPaint = Paint()..isAntiAlias = true;
    final strokePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    fillPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [rimMid, rimDark],
    ).createShader(rect);

    final outerRim = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: w / 2))
      ..addOval(Rect.fromCircle(center: center, radius: w * 0.4));
    canvas.drawPath(outerRim, fillPaint);

    strokePaint
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          rimLight.withValues(alpha: 0.9),
          Colors.black.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.5))
      ..strokeWidth = 1.5
      ..maskFilter = null;
    canvas.drawCircle(center, w * 0.495, strokePaint);

    strokePaint
      ..shader = null
      ..color = Colors.black.withValues(alpha: 0.85)
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, w * 0.45, strokePaint);

    strokePaint
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 360; i += 15) {
      final rad = i * math.pi / 180;
      final p1 = center + Offset(math.cos(rad) * w * 0.45, math.sin(rad) * w * 0.45);
      final p2 = center + Offset(math.cos(rad) * w * 0.49, math.sin(rad) * w * 0.49);
      canvas.drawLine(p1, p2, strokePaint);
    }

    strokePaint
      ..shader = null
      ..maskFilter = null
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = w * 0.02;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.445),
      0.55, 2.0, false,
      strokePaint,
    );

    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [spoke, spokeDark],
    ).createShader(rect);
    Path path = Path()
      ..moveTo(w / 5, h * 0.39)
      ..cubicTo(w / 5, h * 0.39, w * 0.17, h * 0.45, w * 0.18, h * 0.54)
      ..cubicTo(w / 5, h * 0.56, w * 0.24, h * 0.59, w / 4, h * 0.64)
      ..cubicTo(w * 0.26, h * 0.66, w * 0.26, h * 0.69, w * 0.26, h * 0.71)
      ..cubicTo(w * 0.31, h * 0.71, w * 0.38, h * 0.78, w * 0.38, h * 0.78)
      ..cubicTo(w * 0.42, h * 0.79, w * 0.46, h * 0.79, w / 2, h * 0.79)
      ..cubicTo(w * 0.54, h * 0.79, w * 0.58, h * 0.79, w * 0.62, h * 0.78)
      ..cubicTo(w * 0.69, h * 0.71, w * 0.74, h * 0.71, w * 0.74, h * 0.71)
      ..cubicTo(w * 0.74, h * 0.69, w * 0.74, h * 0.66, w * 0.75, h * 0.64)
      ..cubicTo(w * 0.76, h * 0.59, w * 0.79, h * 0.56, w * 0.82, h * 0.54)
      ..cubicTo(w * 0.83, h * 0.45, w * 0.8, h * 0.39, w * 0.8, h * 0.39)
      ..cubicTo(w * 0.72, h * 0.36, w * 0.61, h * 0.35, w / 2, h * 0.35)
      ..cubicTo(w * 0.39, h * 0.35, w * 0.28, h * 0.36, w / 5, h * 0.39)
      ..close();
    canvas.drawPath(path, fillPaint);

    fillPaint.shader = null;
    fillPaint.color = spokeDark;
    path = Path()
      ..moveTo(w / 4, h * 0.45)
      ..cubicTo(w / 4, h * 0.45, w / 5, h * 0.39, w / 5, h * 0.39)
      ..cubicTo(w * 0.16, h * 0.39, w * 0.13, h * 0.4, w * 0.1, h * 0.42)
      ..cubicTo(w * 0.1, h * 0.42, w * 0.05, h * 0.46, w * 0.05, h * 0.46)
      ..cubicTo(w * 0.05, h * 0.46, w * 0.1, h * 0.52, w * 0.1, h * 0.52)
      ..cubicTo(w * 0.13, h * 0.51, w * 0.16, h * 0.52, w * 0.18, h * 0.54)
      ..cubicTo(w * 0.18, h * 0.54, w / 4, h * 0.45, w / 4, h * 0.45)
      ..close();
    canvas.drawPath(path, fillPaint);

    path = Path()
      ..moveTo(w * 0.75, h * 0.45)
      ..cubicTo(w * 0.75, h * 0.45, w * 0.8, h * 0.39, w * 0.8, h * 0.39)
      ..cubicTo(w * 0.84, h * 0.39, w * 0.87, h * 0.4, w * 0.9, h * 0.42)
      ..cubicTo(w * 0.9, h * 0.42, w * 0.95, h * 0.46, w * 0.95, h * 0.46)
      ..cubicTo(w * 0.95, h * 0.46, w * 0.9, h * 0.52, w * 0.9, h * 0.52)
      ..cubicTo(w * 0.87, h * 0.51, w * 0.84, h * 0.52, w * 0.82, h * 0.54)
      ..cubicTo(w * 0.82, h * 0.54, w * 0.75, h * 0.45, w * 0.75, h * 0.45)
      ..close();
    canvas.drawPath(path, fillPaint);

    path = Path()
      ..moveTo(w * 0.36, h * 0.7)
      ..cubicTo(w * 0.36, h * 0.7, w * 0.26, h * 0.71, w * 0.26, h * 0.71)
      ..cubicTo(w / 4, h * 0.74, w * 0.24, h * 0.77, w * 0.22, h * 0.79)
      ..cubicTo(w * 0.22, h * 0.79, w * 0.23, h * 0.87, w * 0.23, h * 0.87)
      ..cubicTo(w * 0.23, h * 0.87, w * 0.31, h * 0.86, w * 0.31, h * 0.86)
      ..cubicTo(w * 0.31, h * 0.86, w * 0.32, h * 0.81, w * 0.38, h * 0.78)
      ..cubicTo(w * 0.38, h * 0.78, w * 0.36, h * 0.7, w * 0.36, h * 0.7)
      ..close();
    canvas.drawPath(path, fillPaint);

    path = Path()
      ..moveTo(w * 0.64, h * 0.7)
      ..cubicTo(w * 0.64, h * 0.7, w * 0.74, h * 0.71, w * 0.74, h * 0.71)
      ..cubicTo(w * 0.75, h * 0.74, w * 0.76, h * 0.77, w * 0.78, h * 0.79)
      ..cubicTo(w * 0.78, h * 0.79, w * 0.77, h * 0.87, w * 0.77, h * 0.87)
      ..cubicTo(w * 0.77, h * 0.87, w * 0.69, h * 0.86, w * 0.69, h * 0.86)
      ..cubicTo(w * 0.69, h * 0.86, w * 0.68, h * 0.81, w * 0.62, h * 0.78)
      ..cubicTo(w * 0.62, h * 0.78, w * 0.64, h * 0.7, w * 0.64, h * 0.7)
      ..close();
    canvas.drawPath(path, fillPaint);

    final hubRect = Rect.fromCircle(center: center, radius: w * 0.14);
    fillPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [hubMid, hubDark],
    ).createShader(hubRect);
    canvas.drawCircle(center, w * 0.135, fillPaint);

    strokePaint
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rimLight, Colors.black],
      ).createShader(hubRect)
      ..maskFilter = null
      ..strokeWidth = w * 0.015;
    canvas.drawCircle(center, w * 0.145, strokePaint);

    strokePaint
      ..shader = null
      ..color = rimLight.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, w * 0.108, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SteeringWheelPainter old) => false;
}

class _SteeringWheelHub extends StatelessWidget {
  final RKTokens tokens;
  final IconData? centerIcon;
  final double knobSize;

  const _SteeringWheelHub({
    required this.tokens,
    this.centerIcon,
    required this.knobSize,
  });

  @override
  Widget build(BuildContext context) {
    final hubSize = knobSize * 0.4;
    final iconSize = knobSize * 0.18;
    return Container(
      width: hubSize,
      height: hubSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surface,
            Color.lerp(Colors.black, tokens.surface, 0.5)!,
          ],
        ),
        border: Border.all(
          color: tokens.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: hubSize * 0.16,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Center(
        child: centerIcon != null ? Icon(
          centerIcon,
          color: tokens.primary,
          size: iconSize,
        ) : null,
      ),
    );
  }
}

class _RKKnobIndicator extends StatelessWidget {
  final double normalized;
  final RKTokens tokens;
  final double knobSize;

  const _RKKnobIndicator({
    required this.normalized,
    required this.tokens,
    required this.knobSize,
  });

  @override
  Widget build(BuildContext context) {
    const dotCount = 11;
    final spacing = knobSize * 0.04;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (index) {
        final progress = normalized * (dotCount - 1);
        final intensity = _getIntensity(progress, index);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: _GlowDot(
            intensity: intensity,
            color: tokens.primary,
            knobSize: knobSize,
          ),
        );
      }),
    );
  }

  double _getIntensity(double progress, int index) {
    double diff = (progress - index).abs();
    if (diff < 1.0) return 1.0 - diff;
    if (diff < 2.0) return (2.0 - diff) * 0.3;
    return 0.0;
  }
}

class _GlowDot extends StatelessWidget {
  final double intensity;
  final Color color;
  final double knobSize;

  const _GlowDot({required this.intensity, required this.color, required this.knobSize});

  @override
  Widget build(BuildContext context) {
    final dimColor = Colors.white.withValues(alpha: 0.08);
    final baseSize = knobSize * 0.036;

    final scale = 1.0 + (1.5 * intensity);
    final currentSize = baseSize * scale;

    final double absoluteMaxSize = baseSize * 2.5;

    return SizedBox(
      width: absoluteMaxSize,
      height: absoluteMaxSize,
      child: Center(
        child: Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(dimColor, Colors.white, intensity),
            boxShadow: [
              if (intensity > 0.1)
                BoxShadow(
                  color: color.withValues(alpha: intensity * 0.3),
                  blurRadius: knobSize * 0.04 * intensity,
                  spreadRadius: knobSize * 0.005 * intensity,
                ),
              if (intensity > 0.6)
                BoxShadow(
                  color: color.withValues(alpha: (intensity - 0.6) * 0.6),
                  blurRadius: knobSize * 0.08 * intensity,
                  spreadRadius: knobSize * 0.012 * intensity,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
