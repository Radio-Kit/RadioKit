import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

class RKKnob extends StatefulWidget {
  const RKKnob({
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
  });

  final IconData? centerIcon;
  final double rotation;
  final String? label;
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
  State<RKKnob> createState() => _RKKnobState();
}

class _RKKnobState extends State<RKKnob> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(RKKnob oldWidget) {
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

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      contentWidth: widget.size,
      contentHeight: widget.size,
      labelColor: tokens.primary.withValues(alpha: 0.7),
      fitContent: true,
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _KnobPainter(
                  angle: currentAngle,
                  tokens: tokens,
                  normalized: normalized,
                  startAngle: startRad,
                  sweepAngle: sweepRad,
                  centerPos: widget.center,
                ),
              ),
              if (widget.centerIcon != null)
                Transform.rotate(
                  angle: currentAngle + math.pi / 2,
                  child: Icon(widget.centerIcon, color: tokens.primary.withValues(alpha: 0.5), size: widget.size * 0.25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({
    required this.angle,
    required this.tokens,
    required this.normalized,
    required this.centerPos,
    required this.startAngle,
    required this.sweepAngle,
  });

  final double angle;
  final RKTokens tokens;
  final double normalized;
  final double centerPos;
  final double startAngle;
  final double sweepAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final knobRadius = radius * 0.8;

    final trackPaint = Paint()
      ..color = tokens.trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..color = tokens.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final arcStart = startAngle + centerPos * sweepAngle;
    final arcSweep = (normalized - centerPos) * sweepAngle;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      arcStart,
      arcSweep,
      false,
      activePaint,
    );

    canvas.drawCircle(center, knobRadius, Paint()
      ..color = tokens.shadowColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawCircle(center, knobRadius, Paint()
      ..color = tokens.surface
      ..style = PaintingStyle.fill);

    canvas.drawCircle(center, knobRadius, Paint()
      ..color = tokens.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    final pointerPaint = Paint()
      ..color = tokens.primary
      ..style = PaintingStyle.fill;

    final pointerCenter = Offset(
      center.dx + (knobRadius - 12) * math.cos(angle),
      center.dy + (knobRadius - 12) * math.sin(angle),
    );

    canvas.drawCircle(pointerCenter, 4, pointerPaint);
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.angle != angle;
}
