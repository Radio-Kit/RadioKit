import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/device_info.dart';
import '../../../models/fs_info.dart';
import '../../../providers/device_provider.dart';
import 'fs_helpers.dart';

/// M3 [NavigationDrawer] for the file explorer.
///
/// Contains:
///   - Header: device name + storage usage LinearProgressIndicator
///   - Destinations: '/' (root) and the current path's ancestors
///   - Footer: FORMAT PARTITION (long-press to confirm)
class FsDrawer extends StatelessWidget {
  final FsInfo? info;
  final String currentPath;
  final void Function(String path) onJumpTo;
  final Future<bool> Function() onFormatPartition;

  const FsDrawer({
    super.key,
    required this.info,
    required this.currentPath,
    required this.onJumpTo,
    required this.onFormatPartition,
  });

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>().connectedDevice;
    final segments = ['/', ...pathSegments(currentPath)];
    final lastIndex = segments.length - 1;

    return _FsDrawerContent(
      info: info,
      device: device,
      segments: segments,
      lastIndex: lastIndex,
      onJumpTo: onJumpTo,
      onFormatPartition: onFormatPartition,
    );
  }
}

class _FsDrawerContent extends StatefulWidget {
  final FsInfo? info;
  final DeviceInfo? device;
  final List<String> segments;
  final int lastIndex;
  final void Function(String path) onJumpTo;
  final Future<bool> Function() onFormatPartition;

  const _FsDrawerContent({
    required this.info,
    required this.device,
    required this.segments,
    required this.lastIndex,
    required this.onJumpTo,
    required this.onFormatPartition,
  });

  @override
  State<_FsDrawerContent> createState() => _FsDrawerContentState();
}

class _FsDrawerContentState extends State<_FsDrawerContent> {
  late int _selectedIndex = widget.lastIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = widget.info;
    final device = widget.device;
    final segments = widget.segments;

    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) {
        if (i == _selectedIndex) {
          Navigator.of(context).pop();
          return;
        }
        setState(() => _selectedIndex = i);
        final path = segments.take(i + 1).join('/');
        Navigator.of(context).pop();
        widget.onJumpTo(path);
      },
      children: [
        SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder_special_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Filesystem',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                          if (device != null)
                            Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (info != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: info.usedFraction.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHigh,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatBytes(info.usedBytes)} / ${formatBytes(info.totalBytes)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ] else
                  Text(
                    'Querying storage…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 8, 28, 8),
          child: _SectionLabel('JUMP TO'),
        ),
        for (int i = 0; i < segments.length; i++)
          _PathDestination(
            index: i,
            isRoot: i == 0,
            label: i == 0 ? 'root' : baseName(segments[i]),
          ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.format_color_fill_rounded,
              color: scheme.error),
          title: Text(
            'Format partition',
            style: TextStyle(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Erases ALL data on ${info?.fsTypeName ?? 'the filesystem'}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          onLongPress: () async {
            Navigator.of(context).pop();
            final ok = await _confirmFormat(context, device, info);
            if (ok == true) {
              await widget.onFormatPartition();
            }
          },
        ),
      ],
    );
  }

  Future<bool?> _confirmFormat(
      BuildContext context, DeviceInfo? device, FsInfo? info) {
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final expected = device?.name ?? '';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 32),
        title: const Text('Format partition?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently erase all files and folders on the device.',
            ),
            const SizedBox(height: 12),
            Text(
              'Type the device name to confirm:',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              expected,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              autofocus: true,
              inputFormatters: [
                LengthLimitingTextInputFormatter(expected.length),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) {
              final ok = v.text == expected && expected.isNotEmpty;
              return FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                ),
                onPressed:
                    ok ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Format'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PathDestination extends StatelessWidget {
  final int index;
  final bool isRoot;
  final String label;

  const _PathDestination({
    required this.index,
    required this.isRoot,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationDrawerDestination(
      icon: Icon(
        isRoot ? Icons.home_rounded : Icons.folder_outlined,
        color: scheme.onSurfaceVariant,
      ),
      selectedIcon: Icon(
        isRoot ? Icons.home_rounded : Icons.folder_rounded,
        color: scheme.primary,
      ),
      label: Text(label),
    );
  }
}
