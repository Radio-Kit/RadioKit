import 'package:flutter/material.dart';
import 'fs_helpers.dart';

/// M3 breadcrumb widget.
///
/// Renders a horizontal row of [ActionChip]s, one per path segment. The
/// last segment is non-interactive and uses [Chip] (a "read-only" chip).
class FsBreadcrumbs extends StatelessWidget {
  final String currentPath;
  final ValueChanged<int> onJumpTo;
  final VoidCallback? onOpenRepoBrowser;
  final Widget? trailing;

  const FsBreadcrumbs({
    super.key,
    required this.currentPath,
    required this.onJumpTo,
    this.onOpenRepoBrowser,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segments = <String>['/', ...pathSegments(currentPath)];

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: segments.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
        itemBuilder: (context, i) {
          final isLast = i == segments.length - 1;
          final isRoot = i == 0;
          final label = isRoot ? null : segments[i];
          if (isLast) {
            return Chip(
              avatar: Icon(
                isRoot ? Icons.home_rounded : Icons.folder_rounded,
                size: 16,
                color: scheme.onSecondaryContainer,
              ),
              label: Text(
                isRoot ? 'root' : label!,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: scheme.secondaryContainer,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            );
          }
          return ActionChip(
            avatar: Icon(
              isRoot ? Icons.home_rounded : Icons.folder_outlined,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            label: Text(
              isRoot ? 'root' : label!,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            backgroundColor: scheme.surfaceContainerHigh,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            onPressed: () => onJumpTo(i),
          );
        },
      ),
    ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: trailing!,
            )
          else if (onOpenRepoBrowser != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.public_rounded, size: 16),
                label: const Text(
                  'Upload',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: onOpenRepoBrowser,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
