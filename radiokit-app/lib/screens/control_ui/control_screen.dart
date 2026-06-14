import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/protocol.dart';
import '../../providers/device_provider.dart';
import '../../providers/debug_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/device_designer_bridge.dart';

/// Dynamic widget rendering screen for the connected RadioKit device.
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {

  @override
  void initState() {
    super.initState();
    _applyFullscreen();
    _applyCanvasOrientation();
  }

  void _applyFullscreen() {
    final settings = context.read<SettingsProvider>();
    if (settings.useFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// Lock device orientation to match the canvas orientation from the config.
  void _applyCanvasOrientation() {
    final device = context.read<DeviceProvider>();
    final isLandscape = device.orientation == kOrientationLandscape;
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

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _disconnect() async {
    final dp = context.read<DeviceProvider>();
    await dp.disconnect();
    if (mounted) context.go('/models');
  }

  void _openDebug() {
    final dp     = context.read<DeviceProvider>();
    if (!mounted) return;
    final debugP = context.read<DebugProvider>();

    // No need to wrap here, DeviceProvider handles it robustly.
    // We just ensure the DebugProvider knows about the current transport for manual sends.
    debugP.attachTransport(dp.currentTransport);

    if (mounted) {
      context.push('/debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    // Update system UI mode based on setting, but keep the App's UI (AppBar) visible
    if (settings.useFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
        final device      = deviceProvider.connectedDevice;
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
                    SizedBox(width: 4),
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
                    SizedBox(width: 12),
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
                                SizedBox(width: 4),
                                Text('${deviceProvider.rssi ?? "--"} dBm', 
                                  style: TextStyle(fontSize: 10, color: context.tokens.onSurface.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                              if (deviceProvider.rssi != null && deviceProvider.latencyMs != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('|', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.1), fontSize: 10)),
                                ),
                                Icon(Icons.timer_rounded, size: 14, color: context.tokens.onSurface.withValues(alpha: 0.54)),
                                SizedBox(width: 4),
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
            title: Text(
                device?.displayName ?? 'RadioKit Device',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
                SizedBox(width: 8),
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
        return _buildLoadingState('Device rebooting — reconnecting...');
      case DeviceConnectionState.disconnected:
        return _buildLoadingState('Disconnecting...');
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
          SizedBox(height: 20),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
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
            SizedBox(height: 20),
            Text('Connection Error',
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            SizedBox(height: 32),
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
            SizedBox(height: 12),
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
    return DeviceDesignerBridge(
      deviceProvider: deviceProvider,
      debugMode: debugProvider.debugMode,
    );
  }
}
