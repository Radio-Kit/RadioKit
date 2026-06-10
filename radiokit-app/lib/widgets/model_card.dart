import 'package:flutter/material.dart';

/// Shared card shell for all model/project cards in the app.
///
/// Provides a consistent visual structure: [ConstrainedBox] with minHeight
/// + [Card] + [InkWell] + [Row] with optional leading/trailing.
/// The card dynamically sizes based on its content.
///
/// Used by:
/// - `_PairedModelCard` (models_tab.dart) — paired device connections
/// - `_InteractiveDemoSection` (models_tab.dart) — demo model tiles
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

  /// Long-press handler (e.g. delete).
  final VoidCallback? onLongPress;

  /// Whether to vertically center the title/subtitle column.
  final bool centerContent;

  const ModelCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.cardColor,
    this.onTap,
    this.onLongPress,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 80),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: cardColor ?? Colors.white.withValues(alpha: 0.05),
        margin: const EdgeInsets.only(bottom: 8),
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
                    mainAxisAlignment: centerContent ? MainAxisAlignment.center : MainAxisAlignment.start,
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
    );
  }
}
