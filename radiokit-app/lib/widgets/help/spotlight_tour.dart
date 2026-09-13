import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Single step definition for a spotlight tour.
class SpotlightStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData? icon;

  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.icon,
  });
}

/// Controller and overlay manager for in-situ spotlight tours.
class SpotlightTour {
  final BuildContext context;
  final String tourId;
  final List<SpotlightStep> steps;
  final VoidCallback? onComplete;

  OverlayEntry? _overlayEntry;
  int _currentStepIndex = 0;

  SpotlightTour({
    required this.context,
    required this.tourId,
    required this.steps,
    this.onComplete,
  });

  void start() {
    if (steps.isEmpty) return;
    _currentStepIndex = 0;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _next() {
    if (_currentStepIndex < steps.length - 1) {
      _currentStepIndex++;
      _overlayEntry?.markNeedsBuild();
    } else {
      finish();
    }
  }

  void finish() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    onComplete?.call();
  }

  Rect? _getTargetRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & size;
  }

  Widget _buildOverlay(BuildContext context) {
    final step = steps[_currentStepIndex];
    final targetRect = _getTargetRect(step.targetKey);
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Cutout scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  scrimColor: Colors.black.withValues(alpha: 0.75),
                  accentColor: context.tokens.primary,
                ),
              ),
            ),
          ),
          // Tooltip card
          _buildTooltipCard(context, step, targetRect, screenSize),
        ],
      ),
    );
  }

  Widget _buildTooltipCard(
    BuildContext context,
    SpotlightStep step,
    Rect? targetRect,
    Size screenSize,
  ) {
    final tokens = context.tokens;
    final isLast = _currentStepIndex == steps.length - 1;

    // Determine vertical placement: if target is in top half, show card below target; else above
    double top;
    if (targetRect != null) {
      if (targetRect.center.dy < screenSize.height / 2) {
        top = targetRect.bottom + 16;
      } else {
        top = targetRect.top - 180;
      }
    } else {
      top = screenSize.height / 3;
    }

    // Keep card inside viewport bounds
    top = top.clamp(40.0, screenSize.height - 220.0);

    return Positioned(
      left: 20,
      right: 20,
      top: top,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens.base200,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (step.icon != null) ...[
                  Icon(step.icon, color: tokens.primary, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    step.title.toUpperCase(),
                    style: GoogleFonts.changa(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.2,
                      color: tokens.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentStepIndex + 1}/${steps.length}',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: tokens.onSurface.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: finish,
                  child: const Text('Skip Tour', style: TextStyle(fontSize: 12)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primary,
                    foregroundColor: tokens.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'DONE' : 'NEXT',
                    style: GoogleFonts.changa(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final Color scrimColor;
  final Color accentColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.scrimColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Offset.zero & size);

    if (targetRect == null) {
      canvas.drawPath(backgroundPath, Paint()..color = scrimColor);
      return;
    }

    final cutoutRect = targetRect!.inflate(8.0);
    final rrect = RRect.fromRectAndRadius(cutoutRect, const Radius.circular(12));
    final cutoutPath = Path()..addRRect(rrect);

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(combinedPath, Paint()..color = scrimColor);

    // Glowing border around target
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.scrimColor != scrimColor ||
        oldDelegate.accentColor != accentColor;
  }
}
