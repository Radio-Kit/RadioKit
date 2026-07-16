import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../services/protocol_service.dart';
import '../../models/protocol.dart';

/// Page switcher widget for play/control mode.
/// Shows chevrons, dot indicators, and page name.
/// Only visible when numPages > 1.
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
    // Only show when there are multiple pages and no OTA in progress
    if (deviceProvider.numPages <= 1 || deviceProvider.isOtaInProgress) {
      return const SizedBox.shrink();
    }

        final activePage = deviceProvider.activePage;
        final numPages = deviceProvider.numPages;
        final pageNames = deviceProvider.pageNames;
        final pageName = activePage < pageNames.length
            ? pageNames[activePage]
            : 'Page ${activePage + 1}';

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left chevron
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: activePage > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        deviceProvider.sendSetPage(activePage - 1);
                      }
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              // Dot indicators
              ...List.generate(numPages, (index) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    deviceProvider.sendSetPage(index);
                  },
                  child: Container(
                    width: index == activePage ? 12 : 8,
                    height: index == activePage ? 12 : 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == activePage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Page name
              Text(
                pageName,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              // Right chevron
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: activePage < numPages - 1
                    ? () {
                        HapticFeedback.lightImpact();
                        deviceProvider.sendSetPage(activePage + 1);
                      }
                    : null,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}
