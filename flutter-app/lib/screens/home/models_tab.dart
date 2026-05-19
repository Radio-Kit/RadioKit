import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/device_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/serial_provider.dart';
import '../../providers/console_provider.dart';
import '../../models/console_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';

class ModelsTab extends StatelessWidget {
  const ModelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RadioKitAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 24),
          
          _ActiveLinkSection(),
          
          const SizedBox(height: 32),
          _PairedModelsList(),
          const SizedBox(height: 32),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              if (!settings.showDemo) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildSectionTag(context, 'INTERACTIVE_DEMO'),
                  _InteractiveDemoSection(),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

}

class _ActiveLinkSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final isConnected = deviceProvider.isConnected;

    if (!isConnected) return const SizedBox.shrink();

    final device = deviceProvider.connectedDevice!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTag(context, 'ACTIVE_LINKS'),
        Card(
          clipBehavior: Clip.antiAlias,
          color: Colors.white.withValues(alpha: 0.05),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: 160,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.local_shipping_rounded,
                              color: AppColors.brandOrange, size: 32),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'TELEMETRY_LIVE',
                                    style: GoogleFonts.inter(
                                      color: AppColors.connected,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.connected,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                device.displayName.toUpperCase(),
                                style: GoogleFonts.exo2(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    '6X6_OFF-ROAD_CHASSIS',
                                    style: TextStyle(
                                      color: AppColors.brandOrange.withValues(alpha: 0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandOrange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: AppColors.brandOrange.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text('UNIT 02',
                                      style: TextStyle(color: AppColors.brandOrange, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1, color: Colors.white12),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TelemetryItem(
                          label: 'LATENCY', 
                          value: deviceProvider.latencyMs?.toString() ?? '--', 
                          unit: 'ms',
                        ),
                        _TelemetryItem(
                          label: 'SIGNAL',
                          value: (deviceProvider.rssi ?? device.rssi) != 0 
                              ? '${deviceProvider.rssi ?? device.rssi}' 
                              : '--',
                          unit: 'dBm',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandOrange,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                        ),
                        onPressed: () {
                          context.go('/control');
                        },
                        child: Text('OPEN_CONTROLLER', style: GoogleFonts.changa(fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildSectionTag(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          color: AppColors.brandOrange,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.brandOrange,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    ),
  );
}

class _TelemetryItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? color;

  const _TelemetryItem({
    required this.label,
    required this.value,
    required this.unit,
  }) : color = null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.exo2(
                    color: color ?? AppColors.brandOrange,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _PairedModelsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    
    final connectedId = deviceProvider.isConnected ? deviceProvider.connectedDevice?.id : null;
    final allDevices = history.pairedDevices;
    final filteredDevices = allDevices.where((d) => d.id != connectedId).toList();

    if (filteredDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTag(context, 'PAIRED_MODELS'),
        ...filteredDevices.map((device) {
        final connectionIcon = device.type == 'ble'
            ? Icons.bluetooth_rounded
            : Icons.usb_rounded;

        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                connectionIcon,
                color: AppColors.brandOrange.withValues(alpha: 0.7),
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (device.configName?.isNotEmpty == true ? device.configName! : device.name).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(width: 8),
                Icon(
                  connectionIcon,
                  size: 14,
                  color: AppColors.brandOrange.withValues(alpha: 0.5),
                ),
              ],
            ),
            subtitle: Text(
              device.description?.isNotEmpty == true ? device.description! : 'NO_DESCRIPTION_PROVIDED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () => _handleReconnect(context, device),
          ),
        );
      }),
    ],
  );
}

  Future<void> _handleReconnect(BuildContext context, PairedDevice device) async {
    final console = context.read<ConsoleProvider>();
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    console.log('RE-INITIALIZING SOURCE: ${device.type.toUpperCase()}', level: ConsoleLogLevel.info);
    
    if (device.type == 'ble') {
      deviceProvider.setTransport(ble.bleService);
    } else {
      deviceProvider.setTransport(serial.serialService);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checking availability for ${device.name}...')),
    );

    bool isLive = false;
    if (device.type == 'ble') {
      // Always perform a fresh scan to ensure the device is currently live
      await ble.startScan();
      await Future.delayed(const Duration(milliseconds: 2500));
      await ble.stopScan();
      isLive = ble.devices.any((d) => d.id == device.id);
    } else if (device.type == 'serial') {
      // On serial, we can just refresh the list
      await serial.startScan();
      isLive = serial.ports.any((p) => p.id == device.id);
    } else {
      // For demo/debug, always live
      isLive = true;
    }

    if (!isLive) {
      if (!context.mounted) return;
      console.log('RECONNECT FAILED: Device "${device.name}" is not reachable.', level: ConsoleLogLevel.error);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ble.errorMessage ?? 'Device is offline or out of range.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${device.name}...')),
    );

    try {
      await deviceProvider.connectToDevice(device.toDeviceInfo());

      // Guard against stale context if the user navigated away during connect.
      if (!context.mounted) return;

      if (deviceProvider.isConnected) {
        console.log('RESYNC SUCCESSFUL: ${device.name}', level: ConsoleLogLevel.success);
      } else {
        final error = deviceProvider.errorMessage ?? 'Connection failed';
        console.log('RESYNC FAILED: $error', level: ConsoleLogLevel.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $error'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      console.log('RUNTIME ERROR: $e', level: ConsoleLogLevel.error);
    }
  }
}

class _InteractiveDemoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _DemoModelTile(
          icon: Icons.widgets_rounded,
          demoId: 'WIDGETS_DEMO',
          title: 'WIDGETS_DEMO',
          subtitle: 'Explore all available widget types',
        ),
        _DemoModelTile(
          icon: Icons.sports_esports_rounded,
          demoId: 'RC_CONTROLLER',
          title: 'RC_CONTROLLER',
          subtitle: 'Simulated remote control interface',
        ),
        _DemoModelTile(
          icon: Icons.dashboard_rounded,
          demoId: 'IOT_DASHBOARD',
          title: 'IOT_DASHBOARD',
          subtitle: 'IoT monitoring and control panel',
        ),
      ],
    );
  }
}

class _DemoModelTile extends StatelessWidget {
  final IconData icon;
  final String demoId;
  final String title;
  final String subtitle;

  const _DemoModelTile({
    required this.icon,
    required this.demoId,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.brandOrange,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.wifi_tethering_rounded,
              size: 14,
              color: AppColors.brandOrange,
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () async {
          final dp = context.read<DeviceProvider>();
          await dp.loadDemo(demoId);
          if (context.mounted) {
            context.go('/control');
          }
        },
      ),
    );
  }
}