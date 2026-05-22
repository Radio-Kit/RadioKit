import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Button mode — momentary (push) or latching (toggle).
enum RKButtonMode { push, toggle }

/// A hardware-style button widget for RadioKit.
class RKButton extends StatefulWidget {
  const RKButton({
    super.key,
    required this.onChanged,
    this.mode = RKButtonMode.push,
    this.onText,
    this.offText,
    this.onIcon,
    this.offIcon,
    this.size = 100.0,
    this.enableHapticFeedback = true,
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  /// The fixed aspect ratio (width/height) for this widget.
  static const double? aspectRatio = 1.0;

  final ValueChanged<bool> onChanged;
  final RKButtonMode mode;
  final String? onText;
  final String? offText;
  final IconData? onIcon;
  final IconData? offIcon;
  final double size;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onInteractionChanged;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  State<RKButton> createState() => _RKButtonState();
}

class _RKButtonState extends State<RKButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _isLatched = false;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final activeColor = tokens.primary;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: widget.size,
      contentHeight: widget.size,
      labelColor: tokens.trackColor.withValues(alpha: 0.8),
      fitContent: true,
      child: Listener(
        onPointerDown: (_) => _handleDown(),
        onPointerUp: (_) => _handleUp(),
        onPointerCancel: (_) => _handleCancel(),
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_glowController.value);
            
            return Transform.scale(
              scale: _pressed ? 0.98 : 1.0,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.5 * t),
                      blurRadius: 10 + (12 * t),
                      spreadRadius: 1 + (2 * t),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF222428),
                    border: Border.all(
                      color: const Color(0xFF1A1C1E),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(widget.size * 0.04),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color.lerp(
                              const Color(0xFF2A2C30),
                              activeColor,
                              t,
                            )!,
                            Color.lerp(
                              const Color(0xFF1E2024),
                              Color.lerp(activeColor, Colors.white, 0.3)!,
                              t,
                            )!,
                            Color.lerp(
                              const Color(0xFF2A2C30),
                              activeColor,
                              t,
                            )!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.5 * t),
                            blurRadius: 6 + (10 * t),
                            spreadRadius: 0 + (2 * t),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(widget.size * 0.08),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF25272B),
                            border: Border.all(
                              color: const Color(0xFF1C1E22),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _buildContent(t, activeColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(double t, Color activeColor) {
    final currentIcon = (t > 0.5 ? widget.onIcon : widget.offIcon) ?? Icons.power_settings_new_rounded;
    final currentText = (t > 0.5 ? widget.onText : widget.offText);
    final hasText = (widget.onText ?? widget.offText) != null;

    return [
      Icon(
        currentIcon,
        size: widget.size * (hasText ? 0.25 : 0.35),
        color: Color.lerp(
          const Color(0xFF6E7278),
          activeColor,
          t,
        ),
      ),
      if (hasText) ...[
        SizedBox(height: widget.size * 0.05),
        Text(
          (currentText ?? '').toUpperCase(),
          style: TextStyle(
            color: Color.lerp(
              const Color(0xFF6E7278),
              activeColor,
              t,
            ),
            fontSize: widget.size * 0.08,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ];
  }

  void _handleDown() {
    if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
    setState(() => _pressed = true);
    widget.onInteractionChanged?.call(true);
    
    if (widget.mode == RKButtonMode.toggle) {
      _isLatched = !_isLatched;
      if (_isLatched) {
        _glowController.forward();
      } else {
        _glowController.reverse();
      }
      widget.onChanged(_isLatched);
    } else {
      _glowController.forward();
      widget.onChanged(true);
    }
  }

  void _handleUp() {
    setState(() => _pressed = false);
    widget.onInteractionChanged?.call(false);
    if (widget.mode == RKButtonMode.push) {
      _glowController.reverse();
      widget.onChanged(false);
    }
  }

  void _handleCancel() {
    setState(() => _pressed = false);
    widget.onInteractionChanged?.call(false);
    if (widget.mode == RKButtonMode.push) {
      _glowController.reverse();
      widget.onChanged(false);
    }
  }
}
