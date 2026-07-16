import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/protocol.dart';
import '../../providers/device_provider.dart';
import '../../providers/multi_device_provider.dart';
import '../../providers/debug_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/device_designer_bridge.dart';
import 'page_switcher.dart';

/// Dynamic widget rendering screen for a connected RadioKit device.
///
/// When [deviceId] is provided, the screen renders widgets for that specific
/// device. When null, falls back to the primary (legacy single-device) provider.
class ControlScreen extends StatefulWidget {
  final String? deviceId;
  const ControlScreen({super.key, this.deviceId});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  void initState() {
    super.initState();
    _applyFullscreen();
    _applyCanvasOrientation();

    // Set focused device when entering control screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final multiDevice = context.read<MultiDeviceProvider>();
      multiDevice.setFocusedDevice(widget.deviceId);
    });
  }

  @override
  void didUpdateWidget(covariant ControlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deviceId != oldWidget.deviceId) {
      // Update focused device when navigating between devices
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final multiDevice = context.read<MultiDeviceProvider>();
        multiDevice.setFocusedDevice(widget.deviceId);
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Clear focused device when leaving control screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final multiDevice = context.read<MultiDeviceProvider>();
      multiDevice.setFocusedDevice(null);
    });
    super.dispose();
  }

  void _applyFullscreen() {
    final settings = context.read<SettingsProvider>();
    if (settings.useFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _applyCanvasOrientation() {
    final dp = _resolveDeviceProvider();
    if (dp == null) return;
    final isLandscape = dp.orientation == kOrientationLandscape;
    SystemChrome.setPreferredOrientations([
      if (isLandscape) ...[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ] else ...[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    ]);
  }

  /// Resolve the DeviceProvider for this screen from MultiDeviceProvider.
  DeviceProvider? _resolveDeviceProvider() {
    final multiDevice = context.read<MultiDeviceProvider>();
    if (widget.deviceId == null) return multiDevice.primaryDevice;
    return multiDevice.getDevice(widget.deviceId!);
  }

  Future<void> _disconnect() async {
    final multiDevice = context.read<MultiDeviceProvider>();
    if (widget.deviceId != null) {
      await multiDevice.disconnectDevice(widget.deviceId!);
    } else {
      // Legacy: disconnect primary
      final dp = multiDevice.primaryDevice;
      if (dp != null) await dp.disconnect();
    }
    if (mounted) context.go('/models');
  }

  void _openDebug() {
    final dp = _resolveDeviceProvider();
    if (dp == null || !mounted) return;
    final debugP = context.read<DebugProvider>();
    debugP.attachTransport(dp.currentTransport);
    if (mounted) {
      context.push('/debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiDevice = context.watch<MultiDeviceProvider>();

    // Resolve device provider for this screen
    DeviceProvider? deviceProvider;
    if (widget.deviceId != null) {
      deviceProvider = multiDevice.getDevice(widget.deviceId!);
    } else {
      deviceProvider = multiDevice.primaryDevice;
    }

    // Device gone (disconnected / removed from collection) — go back silently
    if (deviceProvider == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/models');
      });
      return const SizedBox.shrink();
    }

    // Resolve current device mapKey for dropdown value matching
    String? currentKey;
    if (widget.deviceId != null) {
      currentKey = widget.deviceId;
      // If it's a UID, find the mapKey
      if (!multiDevice.deviceIds.contains(currentKey)) {
        for (final entry in multiDevice.deviceEntries) {
          if (entry.$2.connectedDevice?.id == currentKey) {
            currentKey = entry.$1;
            break;
          }
        }
      }
    } else {
      // Fallback to primary / first connected
      final primary = multiDevice.primaryDevice;
      if (primary != null) {
        for (final entry in multiDevice.deviceEntries) {
          if (entry.$2 == primary) {
            currentKey = entry.$1;
            break;
          }
        }
      }
    }

    // Update system UI mode
    if (settings.useFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return ListenableBuilder(
      listenable: deviceProvider,
      builder: (context, _) {
        final isDisconnected = deviceProvider!.connectionState == DeviceConnectionState.disconnected ||
            deviceProvider.connectionState == DeviceConnectionState.error;

        if (isDisconnected) {
          final otherConnectedEntries = multiDevice.deviceEntries.where((e) {
            return e.$1 != currentKey && e.$2.isConnected;
          }).toList();

          if (otherConnectedEntries.isNotEmpty) {
            final nextDevKey = otherConnectedEntries.first.$1;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/control/$nextDevKey');
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go('/models');
              }
            });
          }
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final device = deviceProvider.connectedDevice;
        final isConnected = deviceProvider.isConnected;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.go('/models');
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              leadingWidth: 220,
              leading: SizedBox(
                width: 220,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home_rounded),
                        tooltip: 'Home',
                        onPressed: () => context.go('/models'),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected ? context.tokens.success : context.tokens.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected ? context.tokens.success : context.tokens.error)
                                  .withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isConnected)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.tokens.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.tokens.onSurface.withValues(alpha: 0.1), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.signal_cellular_alt_rounded,
                                    size: 14, color: _getRssiColor(deviceProvider.rssi ?? -127)),
                                const SizedBox(width: 4),
                                Text('${deviceProvider.rssi ?? "--"} dBm',
                                    style: TextStyle(fontSize: 10, color: context.tokens.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                                if (deviceProvider.rssi != null && deviceProvider.latencyMs != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('|', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.1), fontSize: 10)),
                                  ),
                                Icon(Icons.timer_rounded, size: 14, color: context.tokens.onSurface.withValues(alpha: 0.54)),
                                const SizedBox(width: 4),
                                Text('${deviceProvider.latencyMs ?? "--"}ms',
                                    style: TextStyle(fontSize: 10, color: context.tokens.onSurface.withValues(alpha: 0.54))),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              title: () {
                final displayName = device?.displayName ?? 'RadioKit Device';
                if (multiDevice.deviceCount <= 1) {
                  return Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                }

                final entries = multiDevice.deviceEntries;
                final currentIndex = entries.indexWhere((e) => e.$1 == currentKey);
                if (currentIndex == -1) {
                  return Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                }

                final prevIndex = (currentIndex - 1 + entries.length) % entries.length;
                final nextIndex = (currentIndex + 1) % entries.length;

                void navigateTo(int index) {
                  final targetKey = entries[index].$1;
                  context.go('/control/$targetKey');
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => navigateTo(prevIndex),
                      tooltip: 'Previous Device',
                      visualDensity: VisualDensity.compact,
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity == null) return;
                        if (details.primaryVelocity! > 0) {
                          // Swipe right -> Previous device
                          navigateTo(prevIndex);
                        } else if (details.primaryVelocity! < 0) {
                          // Swipe left -> Next device
                          navigateTo(nextIndex);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => navigateTo(nextIndex),
                      tooltip: 'Next Device',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                );
              }(),
              actions: [
                if (kDebugMode)
                  IconButton(
                    icon: const Icon(Icons.bug_report_rounded),
                    tooltip: 'Debug',
                    onPressed: _openDebug,
                    color: context.tokens.warning,
                  ),
                IconButton(
                  icon: const Icon(Icons.dangerous_rounded),
                  onPressed: _disconnect,
                  tooltip: 'Disconnect',
                  color: context.tokens.error,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: _buildBody(deviceProvider),
          ),
        );
      },
    );
  }

  Widget _buildBody(DeviceProvider deviceProvider) {
    switch (deviceProvider.connectionState) {
      case DeviceConnectionState.fetchingConfig:
        return _buildLoadingState('Loading device configuration...');
      case DeviceConnectionState.error:
        return _buildErrorState(
            deviceProvider.errorMessage ?? 'Unknown error', deviceProvider);
      case DeviceConnectionState.connected:
        return _buildCanvas(deviceProvider);
      case DeviceConnectionState.otaRebooting:
        return _buildLoadingState('Device rebooting - reconnecting...');
      case DeviceConnectionState.disconnected:
        return _buildDisconnectedOverlay(deviceProvider);
      default:
        return _buildLoadingState('Connecting...');
    }
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: context.tokens.primary, strokeWidth: 2),
          const SizedBox(height: 20),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildDisconnectedOverlay(DeviceProvider deviceProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: context.tokens.error),
            const SizedBox(height: 20),
            Text('Device Disconnected',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(deviceProvider.errorMessage ?? 'Connection lost',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RECONNECT'),
              onPressed: () async {
                final device = deviceProvider.connectedDevice;
                if (device != null) {
                  final multiDevice = context.read<MultiDeviceProvider>();
                  await multiDevice.reconnectDevice(device.id);
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _disconnect, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, DeviceProvider deviceProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: context.tokens.error),
            const SizedBox(height: 20),
            Text('Connection Error',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              onPressed: () async {
                final device = deviceProvider.connectedDevice;
                if (device != null) {
                  await deviceProvider.connectToDevice(device);
                }
              },
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _disconnect, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi == -127) return context.tokens.onSurface.withValues(alpha: 0.24);
    if (rssi > -60) return context.tokens.success;
    if (rssi > -80) return context.tokens.warning;
    return context.tokens.error;
  }

  Widget _buildCanvas(DeviceProvider deviceProvider) {
    final debugProvider = context.watch<DebugProvider>();
    final settings = context.watch<SettingsProvider>();
    return Column(
      children: [
        const PageSwitcher(),
        Expanded(
          child: DeviceDesignerBridge(
            deviceProvider: deviceProvider,
            debugMode: debugProvider.debugMode,
            overrideTheme: settings.overrideTheme,
          ),
        ),
      ],
    );
  }
}
