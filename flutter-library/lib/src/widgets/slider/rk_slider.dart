import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Standard axis orientation for RadioKit widgets.
enum RKSliderType { linear, gasPedal }

/// A premium linear slider widget for RadioKit with an industrial aesthetic,
/// self-centering, and fill-from-zero support.
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
    this.type = RKSliderType.linear,
    this.rotation = 0.0,
    this.label,
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
  final RKSliderType type;
  final double rotation;
  final String? label;

  @override
  State<RKSlider> createState() => _RKSliderState();
}

class _RKSliderState extends State<RKSlider> with SingleTickerProviderStateMixin {
  late AnimationController _centerController;
  late Animation<double> _centerAnimation;
  double? _lastEmittedValue;
  final List<double> _echoBuffer = [];
  bool _isInteracting = false;

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
      curve: widget.springCurve,
    );

    _centerController.addListener(() {
      final val = _centerAnimation.value;
      if (val != _lastEmittedValue) {
        _lastEmittedValue = val;
        _addToHistory(val);
        Future.microtask(() => widget.onChanged(val));
      }
    });
  }

  @override
  void didUpdateWidget(RKSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.springDuration != oldWidget.springDuration) {
      _centerController.duration = widget.springDuration;
    }
    
    // MASTER-SLAVE Logic: If the user is actively interacting with the slider,
    // we ignore all external value updates.
    if (_isInteracting) return;

    if (widget.value != oldWidget.value) {
      final range = (widget.max - widget.min).abs();
      
      // ECHO FILTER: Ignore updates that match our recent emission history.
      final isEcho = _echoBuffer.any((v) => (v - widget.value).abs() < range * 0.03);
      if (isEcho) return;
      
      // Since we have the echo buffer, we can use a tighter threshold for real external updates.
      final diff = (widget.value - (_lastEmittedValue ?? -999)).abs();
      if (diff > range * 0.05) {
        _lastEmittedValue = widget.value;
        if (_centerController.isAnimating) _centerController.stop();
      }
    }
    
    if (widget.autoCenter && (widget.autoCenter != oldWidget.autoCenter || widget.center != oldWidget.center)) {
      _triggerCenter();
    }
  }

  @override
  void dispose() {
    _centerController.dispose();
    super.dispose();
  }

  void _triggerCenter() {
    if (!widget.autoCenter) return;
    final targetValue = widget.min + widget.center * (widget.max - widget.min);
    _centerController.stop();
    _centerAnimation = Tween<double>(
      begin: widget.value,
      end: targetValue,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));
    _centerController.forward(from: 0);
  }

  void _handleUpdate(Offset localPos, Size size) {
    if (_centerController.isAnimating) _centerController.stop();
    
    double progress;
    final isPedal = widget.type == RKSliderType.gasPedal;
    final topInset = isPedal ? (widget.orientation == RKAxis.horizontal ? size.width * 0.35 : size.height * 0.35) : 16.0;
    final bottomInset = isPedal ? (widget.orientation == RKAxis.horizontal ? size.width * 0.15 : size.height * 0.15) : 16.0;

    if (widget.orientation == RKAxis.horizontal) {
      final availableWidth = size.width - (topInset + bottomInset);
      final rawProgress = ((localPos.dx - bottomInset) / availableWidth).clamp(0.0, 1.0);
      progress = isPedal ? (1.0 - rawProgress) : rawProgress;
    } else {
      final availableHeight = size.height - (topInset + bottomInset);
      final rawProgress = (1.0 - ((localPos.dy - topInset) / availableHeight)).clamp(0.0, 1.0);
      progress = isPedal ? (1.0 - rawProgress) : rawProgress;
    }
    
    double newVal = widget.min + progress * (widget.max - widget.min);
    
    if (widget.divisions != null && widget.divisions! > 0) {
      final step = (widget.max - widget.min) / widget.divisions!;
      newVal = ((newVal - widget.min) / step).round() * step + widget.min;
    }
    
    if (newVal != _lastEmittedValue) {
      _lastEmittedValue = newVal;
      
      _addToHistory(newVal);

      Future.microtask(() => widget.onChanged(newVal));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final normalized = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final zeroPos = ((0.0 - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

    final double contentW = widget.orientation == RKAxis.horizontal ? widget.length : widget.thickness * 8;
    final double contentH = widget.orientation == RKAxis.vertical ? widget.length : widget.thickness * 8;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      contentWidth: contentW,
      contentHeight: contentH,
      labelColor: tokens.trackColor.withValues(alpha: 0.8),
      fitContent: true,
      child: GestureDetector(
          onPanStart: (details) {
            setState(() => _isInteracting = true);
            widget.onInteractionChanged?.call(true);
            _handleUpdate(details.localPosition, Size(contentW, contentH));
          },
          onPanUpdate: (details) => _handleUpdate(details.localPosition, Size(contentW, contentH)),
          onPanEnd: (_) {
            setState(() => _isInteracting = false);
            widget.onInteractionChanged?.call(false);
            if (widget.autoCenter) _triggerCenter();
          },
          child: Container(
            width: contentW,
            height: contentH,
            color: Colors.transparent,
            child: widget.type == RKSliderType.gasPedal
                ? _buildGasPedal(context, tokens, normalized)
                : CustomPaint(
                    painter: _SliderPainter(
                      normalized: normalized,
                      zeroPos: zeroPos,
                      tokens: tokens,
                      orientation: widget.orientation,
                      thickness: widget.thickness,
                      showTicks: widget.showTicks,
                      tickCount: widget.tickCount,
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildGasPedal(BuildContext context, RKTokens tokens, double normalized) {
    final isHorizontal = widget.orientation == RKAxis.horizontal;
    // Max tilt in radians (approx 25 degrees)
    const double maxTilt = 0.45;
    
    return Center(
      child: Transform(
        alignment: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002) // Perspective
          ..rotateX(isHorizontal ? 0 : -normalized * maxTilt)
          ..rotateY(isHorizontal ? normalized * maxTilt : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: isHorizontal ? widget.length : widget.thickness * 8,
          height: isHorizontal ? widget.thickness * 8 : widget.length,
          padding: EdgeInsets.symmetric(
            vertical: isHorizontal ? 10 : 20,
            horizontal: isHorizontal ? 15 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.borderRadius * 1.5),
            gradient: tokens.surfaceGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 15,
                offset: isHorizontal ? const Offset(-10, 0) : const Offset(0, 10),
              ),
              // Dynamic primary glow
              BoxShadow(
                color: tokens.primary.withValues(alpha: 0.1 + (0.3 * normalized)),
                blurRadius: 10 + (15 * normalized),
                spreadRadius: 2 * normalized,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
            border: Border.all(
              color: tokens.primary.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: isHorizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => _RKPedalGrip(
                      isHorizontal: isHorizontal,
                      normalized: normalized,
                      tokens: tokens,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => _RKPedalGrip(
                      isHorizontal: isHorizontal,
                      normalized: normalized,
                      tokens: tokens,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _RKPedalGrip extends StatelessWidget {
  final bool isHorizontal;
  final double normalized;
  final RKTokens tokens;

  const _RKPedalGrip({
    required this.isHorizontal,
    required this.normalized,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isHorizontal ? 10 : 50,
      height: isHorizontal ? 50 : 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.9),
            tokens.trackColor,
            Colors.black.withValues(alpha: 1.0),
          ],
          begin: isHorizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 4,
            offset: isHorizontal ? const Offset(3, 0) : const Offset(0, 3),
          ),
          // Slight primary under-glow
          BoxShadow(
            color: tokens.primary.withValues(alpha: 0.2 * normalized),
            blurRadius: 2,
            offset: isHorizontal ? const Offset(-1, 0) : const Offset(0, -1),
          ),
        ],
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.normalized,
    required this.zeroPos,
    required this.tokens,
    required this.orientation,
    required this.thickness,
    required this.showTicks,
    required this.tickCount,
  });

  final double normalized;
  final double zeroPos;
  final RKTokens tokens;
  final RKAxis orientation;
  final double thickness;
  final bool showTicks;
  final int tickCount;

  @override
  void paint(Canvas canvas, Size size) {
    final isHorizontal = orientation == RKAxis.horizontal;
    const double horizontalInset = 16.0;
    const double thumbSize = 32.0;

    final centerY = size.height / 2;
    final centerX = size.width / 2;

    // 1. Draw Track
    final trackPaint = Paint()
      ..color = tokens.trackColor
      ..style = PaintingStyle.fill;

    final trackRect = isHorizontal
        ? Rect.fromLTWH(
            horizontalInset,
            centerY - thickness / 2,
            size.width - (horizontalInset * 2),
            thickness,
          )
        : Rect.fromLTWH(
            centerX - thickness / 2,
            horizontalInset,
            thickness,
            size.height - (horizontalInset * 2),
          );
    
    final RRect trackRRect = RRect.fromRectAndRadius(trackRect, Radius.circular(thickness / 10));
    canvas.drawRRect(trackRRect, trackPaint);

    // 2. Draw Active Fill
    final activePaint = Paint()
      ..color = tokens.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    Rect activeRect;
    if (isHorizontal) {
      final startX = trackRect.left + zeroPos * trackRect.width;
      final endX = trackRect.left + normalized * trackRect.width;
      activeRect = Rect.fromLTRB(
        startX < endX ? startX : endX,
        trackRect.top,
        startX < endX ? endX : startX,
        trackRect.bottom,
      );
    } else {
      final startY = trackRect.top + (1.0 - zeroPos) * trackRect.height;
      final endY = trackRect.top + (1.0 - normalized) * trackRect.height;
      activeRect = Rect.fromLTRB(
        trackRect.left,
        startY < endY ? startY : endY,
        trackRect.right,
        startY < endY ? endY : startY,
      );
    }
    
    final RRect activeRRect = RRect.fromRectAndRadius(activeRect, Radius.circular(thickness / 2));
    canvas.drawRRect(activeRRect, activePaint);

    // 3. Draw Ticks (over the track)
    if (showTicks && tickCount > 0) {
      final minorPaint = Paint()
        ..color = tokens.onSurface.withValues(alpha: 0.15)
        ..strokeWidth = 0.6
        ..strokeCap = StrokeCap.round;

      final majorPaint = Paint()
        ..color = tokens.onSurface.withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      if (isHorizontal) {
        final startX = horizontalInset;
        final endX = size.width - horizontalInset;
        
        for (int i = 0; i <= tickCount; i++) {
          final t = i / tickCount;
          final x = startX + (endX - startX) * t;
          final isMajor = i % 5 == 0;
          
          final tickHeight = isMajor ? thumbSize * 0.6 : thumbSize * 0.5;
          final top = centerY - tickHeight / 2;
          final bottom = centerY + tickHeight / 2;
          
          canvas.drawLine(
            Offset(x, top),
            Offset(x, bottom),
            isMajor ? majorPaint : minorPaint,
          );
        }
      } else {
        final startY = horizontalInset;
        final endY = size.height - horizontalInset;
        
        for (int i = 0; i <= tickCount; i++) {
          final t = i / tickCount;
          // For vertical, 0 is at the bottom (endY)
          final y = endY - (endY - startY) * t;
          final isMajor = i % 5 == 0;
          
          final tickWidth = isMajor ? thumbSize * 0.6 : thumbSize * 0.5;
          final left = centerX - tickWidth / 2;
          final right = centerX + tickWidth / 2;
          
          canvas.drawLine(
            Offset(left, y),
            Offset(right, y),
            isMajor ? majorPaint : minorPaint,
          );
        }
      }
    }

    // 4. Draw Thumb (Soft Industrial)
    final thumbCenter = isHorizontal
        ? Offset(trackRect.left + normalized * trackRect.width, centerY)
        : Offset(centerX, trackRect.top + (1.0 - normalized) * trackRect.height);

    _drawIndustrialThumb(canvas, thumbCenter);
  }

  void _drawIndustrialThumb(Canvas canvas, Offset center) {
    const double thumbSize = 31.0;
    final glowRect = Rect.fromCenter(center: center, width: thumbSize + 8, height: thumbSize + 8);
    final outerRect = Rect.fromCenter(center: center, width: thumbSize, height: thumbSize);
    final innerRect = Rect.fromCenter(center: center, width: thumbSize - 6, height: thumbSize - 6);

    final glowPaint = Paint()
      ..color = tokens.primary.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final outerPaint = Paint()
      ..color = tokens.primary
      ..style = PaintingStyle.fill;

    final innerPaint = Paint()
      ..color = tokens.surface.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final rimPaint = Paint()
      ..color = tokens.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final gripShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final gripPaint = Paint()
      ..color = tokens.surface.withValues(alpha: 0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, const Radius.circular(10)),
      glowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(8)),
      outerPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(6)),
      innerPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outerRect.deflate(0.5),
        const Radius.circular(8),
      ),
      rimPaint,
    );

    for (int i = -1; i <= 1; i++) {
      final offset = i * 4.2;
      
      if (orientation == RKAxis.horizontal) {
        canvas.drawLine(
          Offset(center.dx + offset, center.dy - 6.0),
          Offset(center.dx + offset, center.dy + 6.0),
          gripShadowPaint,
        );
        canvas.drawLine(
          Offset(center.dx + offset, center.dy - 5.5),
          Offset(center.dx + offset, center.dy + 5.5),
          gripPaint,
        );
      } else {
        canvas.drawLine(
          Offset(center.dx - 6.0, center.dy + offset),
          Offset(center.dx + 6.0, center.dy + offset),
          gripShadowPaint,
        );
        canvas.drawLine(
          Offset(center.dx - 5.5, center.dy + offset),
          Offset(center.dx + 5.5, center.dy + offset),
          gripPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) =>
      oldDelegate.normalized != normalized ||
      oldDelegate.zeroPos != zeroPos ||
      oldDelegate.showTicks != showTicks ||
      oldDelegate.tickCount != tickCount;
}
