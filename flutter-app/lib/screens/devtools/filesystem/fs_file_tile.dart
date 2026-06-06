import 'package:flutter/material.dart';
import '../../../models/fs_entry.dart';
import 'fs_helpers.dart';

/// A Material 3 [ListTile] row for a single filesystem entry.
///
/// Supports two visual modes:
///   - normal: leading icon + title + subtitle + trailing chevron/menu
///   - selectable: leading checkbox + title + subtitle, no trailing
class FsFileTile extends StatelessWidget {
  final FsEntry entry;
  final String fullPath;
  final bool isSelected;
  final bool isMultiSelect;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryAction;

  const FsFileTile({
    super.key,
    required this.entry,
    required this.fullPath,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = fileVisual(entry.name, isDir: entry.isDirectory);

    final tileColor = isSelected
        ? scheme.primaryContainer.withValues(alpha: 0.5)
        : null;

    final title = Text(
      entry.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: entry.isDirectory ? FontWeight.w600 : FontWeight.normal,
        color: scheme.onSurface,
      ),
    );

    final subtitle = entry.isDirectory
        ? Text(
            'Folder',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        : Text(
            formatBytes(entry.size),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final leading = isMultiSelect
        ? Checkbox(
            value: isSelected,
            onChanged: (_) => onTap(),
            visualDensity: VisualDensity.compact,
          )
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(visual.icon, color: visual.color, size: 20),
          );

    final trailing = isMultiSelect
        ? null
        : entry.isDirectory
            ? Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              )
            : IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More actions',
                onPressed: onSecondaryAction,
              );

    return Container(
      color: tileColor,
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 2,
        ),
      ),
    );
  }
}
