import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Shared card shell for all model/project cards in the app.
///
/// Provides a consistent visual structure: [ConstrainedBox] with minHeight
/// + [Card] + [InkWell] + [Row] with optional leading/trailing.
/// The card dynamically sizes based on its content.
///
/// Used by:
/// - `_PairedModelCard` (models_tab.dart) — paired device connections
/// - `_DesignCard` (designs_tab.dart) — saved design project cards
class ModelCard extends StatelessWidget {
  /// Leading widget (e.g. icon container). Shown on the left with 16px gap.
  final Widget? leading;

  /// Title widget — placed in an [Expanded] column on the left side.
  final Widget title;

  /// Optional subtitle — rendered below the title with 4px gap.
  final Widget? subtitle;

  /// Trailing widget — shown on the right side with 12px gap.
  final Widget? trailing;

  /// Optional card background color override. Default: white @ 5%.
  final Color? cardColor;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Long-press handler.
  final VoidCallback? onLongPress;

  /// Secondary tap (right-click) handler.
  /// Passes the global position where the tap occurred for positioning menus.
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Whether to vertically center the title/subtitle column.
  final bool centerContent;

  /// Creates a [ModelCard] with the standard 60×60 icon container as leading.
  ///
  /// Renders a [Container] with [tokens.base200] background, a centered [Icon]
  /// in [tokens.primary] at size 36. If [badge] is provided, it is overlaid in
  /// the bottom-right corner via a [Stack].
  static Widget standardLeading({
    required BuildContext context,
    required IconData icon,
    Widget? badge,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: context.tokens.base200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(icon, color: context.tokens.primary, size: 36),
          ),
        ),
        if (badge != null)
          Positioned(right: -2, bottom: -2, child: badge),
      ],
    );
  }

  /// Creates a title widget for a [ModelCard] with standard styling.
  ///
  /// Renders a [FittedBox]-wrapped [Text] in [GoogleFonts.exo2] (weight 900,
  /// size 18, uppercase) that scales down to fit the available width.
  static Widget standardTitle(String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.exo2(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          fontSize: 18,
        ),
      ),
    );
  }

  /// Creates a subtitle widget for a [ModelCard] with standard styling.
  ///
  /// Renders a [Text] in [tokens.primary] at 70% opacity, 11px bold, with
  /// 1-line ellipsis overflow.
  static Widget standardSubtitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.tokens.primary.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  const ModelCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.cardColor,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: cardColor ?? context.tokens.onSurface.withValues(alpha: 0.05),
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.tokens.borderRadius.clamp(0, 32)),
          side: BorderSide.none,
        ),
        child: GestureDetector(
          onSecondaryTapDown: onSecondaryTap != null
              ? (details) => onSecondaryTap!(details.globalPosition)
              : null,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: centerContent
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        title,
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          subtitle!,
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
