import 'package:flutter/material.dart';
import '../../../models/fs_info.dart';
import 'fs_helpers.dart';

/// M3 storage-usage indicator shown above the file list.
///
/// Displays a [Card.filled] containing a [LinearProgressIndicator] plus
/// "X used of Y" labels and the filesystem type chip.
class FsInfoStrip extends StatelessWidget {
  final FsInfo? info;
  final bool loading;

  const FsInfoStrip({super.key, required this.info, required this.loading});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card.filled(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  info?.fsTypeName ?? 'Filesystem',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                if (info != null)
                  Text(
                    '${formatBytes(info!.usedBytes)} of ${formatBytes(info!.totalBytes)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  )
                else if (loading)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: info?.usedFraction.clamp(0, 1),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            if (info != null)
              Row(
                children: [
                  _LegendDot(color: scheme.primary, label: 'Used'),
                  const SizedBox(width: 16),
                  _LegendDot(
                    color: scheme.surfaceContainerHigh,
                    label: 'Free ${formatBytes(info!.freeBytes)}',
                  ),
                  const Spacer(),
                  Text(
                    '${(info!.usedFraction * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
