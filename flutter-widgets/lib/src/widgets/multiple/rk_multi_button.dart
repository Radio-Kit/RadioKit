import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Data model for a single toggle item in [RKMultiButton] or [RKMultiSelect].
class RKToggleItem {
  final String? onLabel;
  final String? offLabel;
  final IconData? onIcon;
  final IconData? offIcon;

  const RKToggleItem({
    this.onLabel,
    this.offLabel,
    this.onIcon,
    this.offIcon,
  });

  bool get isOffEmpty =>
      (offIcon == null) && (offLabel == null || offLabel!.isEmpty);

  String labelFor(bool selected) {
    if (selected) return onLabel ?? '';
    if (isOffEmpty) return onLabel ?? '';
    return offLabel ?? '';
  }

  IconData? iconFor(bool selected) {
    if (selected) return onIcon;
    if (isOffEmpty) return onIcon;
    return offIcon;
  }
}

/// Radio-style multi-button group for RadioKit.
///
/// ### Defined aspect ratio
/// The widget enforces a strict **N:1** width:height ratio where **N = number
/// of items** plus the outer padding and gaps.
class RKMultiButton extends StatelessWidget {
  const RKMultiButton({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.itemMask = 0xFF,
    this.buttonSize = 24.0,
    this.gap = 8.0,
    this.enableHapticFeedback = true,
    this.onActiveChanged,
    this.orientation = RKAxis.horizontal,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  final List<RKToggleItem> items;
  final int selected;
  final ValueChanged<int> onChanged;
  final int itemMask;
  final double buttonSize;
  final double gap;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onActiveChanged;
  final RKAxis orientation;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final visibleIndices = <int>[];
    for (int i = 0; i < items.length; i++) {
      if (i >= 8 || (itemMask & (1 << i)) != 0) {
        visibleIndices.add(i);
      }
    }
    final int count = visibleIndices.length;
    final bool isHorizontal = orientation == RKAxis.horizontal;

    final double shellPadding = (buttonSize * 0.08).clamp(2.0, 10.0);
    final double cw = isHorizontal
        ? (count > 0 ? buttonSize * count + gap * (count - 1) : 0) + shellPadding * 2
        : buttonSize + shellPadding * 2;
    final double ch = isHorizontal
        ? buttonSize + shellPadding * 2
        : (count > 0 ? buttonSize * count + gap * (count - 1) : 0) + shellPadding * 2;

    if (count == 0) {
      return const SizedBox.shrink();
    }

    return RKRotatedWrapper(
      rotation: rotation,
      label: label,
      showDebug: showDebug,
      contentWidth: cw,
      contentHeight: ch,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
      fitContent: true,
      child: Container(
        width: cw,
        height: ch,
        padding: EdgeInsets.all(shellPadding),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.effectiveOutline, width: 1),
          borderRadius: BorderRadius.circular(tokens.borderRadius * 0.6),
          boxShadow: tokens.depth > 0
              ? [
                  BoxShadow(
                    color: tokens.base300.withValues(alpha: 0.3),
                    blurRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Listener(
          onPointerDown: (_) => onActiveChanged?.call(true),
          onPointerUp: (_) => onActiveChanged?.call(false),
          onPointerCancel: (_) => onActiveChanged?.call(false),
          child: _buildAxis(visibleIndices, tokens, isHorizontal),
        ),
      ),
    );
  }

  Widget _buildAxis(List<int> visibleIndices, RKTokens tokens, bool isHorizontal) {
    final children = <Widget>[];
    for (int k = 0; k < visibleIndices.length; k++) {
      if (k > 0) {
        children
            .add(isHorizontal ? SizedBox(width: gap) : SizedBox(height: gap));
      }
      final originalIndex = visibleIndices[k];
      children.add(Expanded(
        child: _ToggleButton(
          item: items[originalIndex],
          selected: originalIndex == selected,
          buttonSize: buttonSize,
          onTap: () {
            if (enableHapticFeedback) {
              HapticFeedback.lightImpact();
            }
            onChanged(originalIndex);
          },
          tokens: tokens,
        ),
      ));
    }
    if (isHorizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
  }
}

/// Bitmask multi-select group for RadioKit.
///
/// ### Defined aspect ratio
/// Same as [RKMultiButton]: strict **N:1** width:height ratio where **N =
/// number of items** plus the outer padding and gaps.
class RKMultiSelect extends StatelessWidget {
  const RKMultiSelect({
    super.key,
    required this.items,
    required this.bitmask,
    required this.onChanged,
    this.itemMask = 0xFF,
    this.buttonSize = 24.0,
    this.gap = 8.0,
    this.enableHapticFeedback = true,
    this.onActiveChanged,
    this.orientation = RKAxis.horizontal,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  final List<RKToggleItem> items;
  final int bitmask;
  final ValueChanged<int> onChanged;
  final int itemMask;
  final double buttonSize;
  final double gap;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onActiveChanged;
  final RKAxis orientation;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final visibleIndices = <int>[];
    for (int i = 0; i < items.length; i++) {
      if (i >= 8 || (itemMask & (1 << i)) != 0) {
        visibleIndices.add(i);
      }
    }
    final int count = visibleIndices.length;
    final bool isHorizontal = orientation == RKAxis.horizontal;

    final double shellPadding = (buttonSize * 0.08).clamp(2.0, 10.0);
    final double cw = isHorizontal
        ? (count > 0 ? buttonSize * count + gap * (count - 1) : 0) + shellPadding * 2
        : buttonSize + shellPadding * 2;
    final double ch = isHorizontal
        ? buttonSize + shellPadding * 2
        : (count > 0 ? buttonSize * count + gap * (count - 1) : 0) + shellPadding * 2;

    if (count == 0) {
      return const SizedBox.shrink();
    }

    return RKRotatedWrapper(
      rotation: rotation,
      label: label,
      showDebug: showDebug,
      contentWidth: cw,
      contentHeight: ch,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
      fitContent: true,
      child: Container(
        width: cw,
        height: ch,
        padding: EdgeInsets.all(shellPadding),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.effectiveOutline, width: 1),
          borderRadius: BorderRadius.circular(tokens.borderRadius * 0.6),
          boxShadow: tokens.depth > 0
              ? [
                  BoxShadow(
                    color: tokens.base300.withValues(alpha: 0.3),
                    blurRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Listener(
          onPointerDown: (_) => onActiveChanged?.call(true),
          onPointerUp: (_) => onActiveChanged?.call(false),
          onPointerCancel: (_) => onActiveChanged?.call(false),
          child: _buildAxis(visibleIndices, tokens, isHorizontal),
        ),
      ),
    );
  }

  Widget _buildAxis(List<int> visibleIndices, RKTokens tokens, bool isHorizontal) {
    final children = <Widget>[];
    for (int k = 0; k < visibleIndices.length; k++) {
      if (k > 0) {
        children
            .add(isHorizontal ? SizedBox(width: gap) : SizedBox(height: gap));
      }
      final originalIndex = visibleIndices[k];
      final isSelected = ((bitmask >> originalIndex) & 1) == 1;
      children.add(Expanded(
        child: _ToggleButton(
          item: items[originalIndex],
          selected: isSelected,
          buttonSize: buttonSize,
          onTap: () {
            if (enableHapticFeedback) {
              HapticFeedback.selectionClick();
            }
            onChanged(bitmask ^ (1 << originalIndex));
          },
          tokens: tokens,
        ),
      ));
    }
    if (isHorizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
  }
}

class _ToggleButton extends StatelessWidget {
  final RKToggleItem item;
  final bool selected;
  final double buttonSize;
  final VoidCallback onTap;
  final RKTokens tokens;

  const _ToggleButton({
    required this.item,
    required this.selected,
    required this.buttonSize,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final activeAccent = tokens.onPrimary;

    // Create buttonDark and buttonDark2 dynamically based on tokens.surface
    // to preserve dark/light theme options and look incredibly good.
    final double lightness = HSLColor.fromColor(tokens.surface).lightness;
    final isDark = lightness < 0.5;

    final Color buttonDark = isDark
        ? HSLColor.fromColor(tokens.surface)
            .withLightness((lightness + 0.07).clamp(0.0, 1.0))
            .toColor()
        : HSLColor.fromColor(tokens.surface)
            .withLightness((lightness - 0.07).clamp(0.0, 1.0))
            .toColor();

    final Color buttonDark2 = isDark
        ? HSLColor.fromColor(tokens.surface)
            .withLightness((lightness - 0.07).clamp(0.0, 1.0))
            .toColor()
        : HSLColor.fromColor(tokens.surface)
            .withLightness((lightness + 0.07).clamp(0.0, 1.0))
            .toColor();

    final borderColor = tokens.effectiveOutline;
    final dullGrey = tokens.onSurface.withValues(alpha: 0.4);

    final double radius = tokens.radiusSelector;
    final double scale = buttonSize / 120.0;

    final iconData = item.iconFor(selected);
    final labelText = item.labelFor(selected);
    final bool hasIcon = iconData != null;
    final bool hasText = labelText.isNotEmpty;

    final double currentIconSize =
        hasText ? buttonSize * 0.55 : buttonSize * 0.65;
    final double currentFontSize =
        hasIcon ? buttonSize * 0.16 : buttonSize * 0.5;

    Widget? iconWidget;
    if (hasIcon) {
      iconWidget = Icon(
        iconData,
        size: currentIconSize,
        color: selected ? activeAccent : dullGrey,
        shadows: selected
            ? [
                Shadow(
                  color: activeAccent.withValues(alpha: 0.8),
                  blurRadius: (12.0 * scale).clamp(2.0, 20.0),
                ),
              ]
            : null,
      );
    }

    Widget? textWidget;
    if (hasText) {
      textWidget = Padding(
        padding: EdgeInsets.symmetric(horizontal: buttonSize * 0.08),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            labelText.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: selected ? activeAccent : dullGrey,
              fontSize: currentFontSize,
              height: 1.1,
              letterSpacing: 1.2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget innerContent;
    if (iconWidget != null && textWidget != null) {
      innerContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top 2/3 for the Icon
          Expanded(
            flex: 2,
            child: Center(child: iconWidget),
          ),
          // Bottom 1/3 for the Text
          Expanded(
            flex: 1,
            child: Center(child: textWidget),
          ),
        ],
      );
    } else if (iconWidget != null) {
      innerContent = Center(child: iconWidget);
    } else if (textWidget != null) {
      innerContent = Center(child: textWidget);
    } else {
      innerContent = const SizedBox.shrink();
    }

    // Border width: scale dynamically and made thinner
    final double selectedBorderWidth =
        (buttonSize * 0.005).clamp(0.1, 1.0); // reduced from 0.04
    final double unselectedBorderWidth =
        (buttonSize * 0.025).clamp(0.1, 1.0); // reduced from 0.033

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [tokens.primary, tokens.primary.withValues(alpha: 0.85)]
                  : [buttonDark, buttonDark2],
            ),
            border: Border.all(
              color: selected ? activeAccent : borderColor,
              width: selected ? selectedBorderWidth : unselectedBorderWidth,
            ),
            boxShadow: tokens.depth > 0 && selected
                ? [
                    BoxShadow(
                      color: activeAccent.withValues(alpha: 0.15),
                      blurRadius: 0.5,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        selected
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (4.0 * scale).clamp(1.0, 8.0),
                    vertical: (8.0 * scale).clamp(2.0, 16.0),
                  ),
                  child: innerContent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
