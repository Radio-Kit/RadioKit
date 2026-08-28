import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../../../models/fs_entry.dart';
import 'fs_helpers.dart';
import '../../../widgets/themed_bottom_sheet.dart';

/// Result of one of the actions in [FsActionSheet]. The caller is
/// responsible for performing the actual FS operation.
enum FsAction { download, rename, copyPath, delete, info, edit }

/// M3 modal bottom sheet for per-file / per-directory actions.
///
/// Shows the entry name + size as a header, then a vertical list of
/// [ListTile]s (one per action). The download tile is hidden for
/// directories. The caller drives the dialogs (rename, delete
/// confirmation) and FS calls.
class FsActionSheet extends StatelessWidget {
  final FsEntry entry;
  final String fullPath;

  const FsActionSheet({
    super.key,
    required this.entry,
    required this.fullPath,
  });

  static Future<FsAction?> show(BuildContext context,
      {required FsEntry entry, required String fullPath}) {
    return showThemedBottomSheet<FsAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) =>
          FsActionSheet(entry: entry, fullPath: fullPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = fileVisual(entry.name, isDir: entry.isDirectory);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Transform.translate(
        offset: const Offset(0, -18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!entry.isDirectory) ...[
              if (isEditableFile(entry.name))
                _SheetTile(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  subtitle: 'Edit file content',
                  onTap: () => Navigator.of(context).pop(FsAction.edit),
                ),
              _SheetTile(
                icon: Icons.download_rounded,
                label: 'Download',
                subtitle: 'Save to this device',
                onTap: () => Navigator.of(context).pop(FsAction.download),
              ),
            ],
            _SheetTile(
              icon: Icons.edit_rounded,
              label: 'Rename',
              subtitle: 'Move or rename this entry',
              onTap: () => Navigator.of(context).pop(FsAction.rename),
            ),
            _SheetTile(
              icon: Icons.link_rounded,
              label: 'Copy path',
              subtitle: fullPath,
              onTap: () => Navigator.of(context).pop(FsAction.copyPath),
            ),
            _SheetTile(
              icon: Icons.info_outline_rounded,
              label: 'Info',
              subtitle: entry.isDirectory
                  ? 'Folder'
                  : '${formatBytes(entry.size)} • ${entry.size} bytes',
              onTap: () => Navigator.of(context).pop(FsAction.info),
            ),
            _SheetTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              subtitle: entry.isDirectory
                  ? 'Recursive delete'
                  : 'Permanent delete',
              destructive: true,
              onTap: () => Navigator.of(context).pop(FsAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

/// Show a confirmation dialog for delete. Returns true if confirmed.
Future<bool> confirmDelete(BuildContext context, FsEntry entry) async {
  final scheme = Theme.of(context).colorScheme;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 32),
      title: const Text('Delete?'),
      content: Text(
        entry.isDirectory
            ? 'This will delete the folder "${entry.name}" and ALL files inside it.'
            : 'This will permanently delete "${entry.name}".',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Show a rename dialog. Returns the new path or null if cancelled.
Future<String?> promptRename(BuildContext context, String oldPath) async {
  final oldName = baseName(oldPath);
  final controller = TextEditingController(text: oldName);
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'New name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
  if (newName == null || newName.isEmpty || newName == oldName) return null;
  return joinPath(parentPath(oldPath), newName);
}

/// Show a "create folder" dialog. Returns the new path or null.
Future<String?> promptNewFolder(BuildContext context, String parent) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Folder name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return null;
  return joinPath(parent, name);
}

/// Show a file picker (single) and return the picked bytes + name.
Future<({String name, Uint8List bytes})?> pickUploadFile(
    BuildContext context) async {
  final result = await FilePicker.pickFiles(
    withData: true,
    allowMultiple: false,
  );
  if (result.isEmpty) return null;
  final f = result.first;
  if (f.bytes == null || f.bytes!.isEmpty) return null;
  return (name: f.name, bytes: f.bytes!);
}

/// Show a save-as dialog for a downloaded file.
Future<Uri?> promptSaveFile(BuildContext context,
    {required String fileName, required Uint8List bytes}) {
  return FilePicker.saveFile(fileName: fileName, bytes: bytes);
}
