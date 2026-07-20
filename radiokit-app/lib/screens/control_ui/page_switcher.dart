import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';

/// Tab-style page switcher for play/control mode.
/// Shows named page tabs with chevrons.
/// Only visible when numPages > 1 and showControlPageBar is enabled.
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
        if (deviceProvider.numPages <= 1 || deviceProvider.isOtaInProgress) {
          return const SizedBox.shrink();
        }

        // Check showControlPageBar from device config JSON
        final configJson = deviceProvider.deviceConfigJson;
        final showPageBar = configJson?['canvas']?['showControlPageBar'] as bool? ?? true;
        if (!showPageBar) return const SizedBox.shrink();

        final activePage = deviceProvider.activePage;
        final numPages = deviceProvider.numPages;
        final pageNames = deviceProvider.pageNames;
        final colorScheme = Theme.of(context).colorScheme;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
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
              // Scrollable tab buttons
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(numPages, (index) {
                        final isActive = index == activePage;
                        final pageName = index < pageNames.length
                            ? pageNames[index]
                            : 'Page ${index + 1}';
                        return GestureDetector(
                          onTap: () {
                            if (isActive) return;
                            HapticFeedback.lightImpact();
                            deviceProvider.sendSetPage(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: isActive
                                  ? null
                                  : Border.all(
                                      color: colorScheme.outline.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                            ),
                            child: Text(
                              pageName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
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
