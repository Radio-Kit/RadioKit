import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import 'rk_linear_slider.dart';

/// A gas-pedal style slider widget for RadioKit with a 3D tilt effect.
///
/// Delegates all interaction logic (auto-center, echo filter,
/// master-slave) to [RKSlider] while providing a distinct visual treatment.
class RKGasPedal extends StatelessWidget {
  const RKGasPedal({
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
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
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
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  Widget build(BuildContext context) {
    return RKSlider(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      orientation: orientation,
      thickness: thickness,
      length: length,
      onInteractionChanged: onInteractionChanged,
      autoCenter: autoCenter,
      center: center,
      springCurve: springCurve,
      springDuration: springDuration,
      divisions: divisions,
      rotation: rotation,
      label: label,
      showDebug: showDebug,
      invertGesture: true,
      builder: _buildGasPedal,
    );
  }

  Widget _buildGasPedal(BuildContext context, RKTokens tokens, double normalized) {
    final isHorizontal = orientation == RKAxis.horizontal;
    const double maxTilt = 0.45;
    final double containerW = isHorizontal ? length : thickness * 8;
    final double containerH = isHorizontal ? thickness * 8 : length;

    return Center(
      child: Transform(
        alignment:
            isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX(isHorizontal ? 0 : -normalized * maxTilt)
          ..rotateY(isHorizontal ? normalized * maxTilt : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: containerW,
          height: containerH,
          padding: EdgeInsets.symmetric(
            vertical: isHorizontal ? containerH * 0.12 : containerH * 0.07,
            horizontal: isHorizontal ? containerW * 0.05 : containerW * 0.12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.borderRadius * 1.5),
            gradient: tokens.surfaceGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 15,
                offset: isHorizontal
                    ? const Offset(-10, 0)
                    : const Offset(0, 10),
              ),
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
                    (index) => _PedalGrip(
                      isHorizontal: isHorizontal,
                      normalized: normalized,
                      tokens: tokens,
                      containerWidth: containerW,
                      containerHeight: containerH,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => _PedalGrip(
                      isHorizontal: isHorizontal,
                      normalized: normalized,
                      tokens: tokens,
                      containerWidth: containerW,
                      containerHeight: containerH,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PedalGrip extends StatelessWidget {
  final bool isHorizontal;
  final double normalized;
  final RKTokens tokens;
  final double containerWidth;
  final double containerHeight;

  const _PedalGrip({
    required this.isHorizontal,
    required this.normalized,
    required this.tokens,
    required this.containerWidth,
    required this.containerHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double gripW = isHorizontal
        ? containerWidth * 0.04
        : containerWidth * 0.55;
    final double gripH = isHorizontal
        ? containerHeight * 0.55
        : containerHeight * 0.04;
    final double radius = (gripW < gripH ? gripW : gripH) * 0.12;
    final double blur = (gripW < gripH ? gripW : gripH) * 0.08;

    return Container(
      width: gripW,
      height: gripH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius.clamp(2, 12)),
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
            blurRadius: blur.clamp(1, 8),
            offset: isHorizontal ? const Offset(3, 0) : const Offset(0, 3),
          ),
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
