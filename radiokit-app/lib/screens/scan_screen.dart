import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/logo_icon.dart';
import '../widgets/radiokit_app_bar.dart';
import '../providers/ble_provider.dart';
import '../providers/serial_provider.dart';
import '../providers/device_provider.dart';
import '../models/device_info.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'control_screen.dart';
import 'debug_screen.dart';

/// Device scanner screen — BLE tab and USB Serial tab.
///
/// Selecting a device from either tab swaps the [DeviceProvider] transport
/// to the appropriate [TransportService] before connecting.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BleProvider>().startScan();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Connection helpers
  // ---------------------------------------------------------------------------

  Future<void> _connectBle(DeviceInfo device) async {
    final bleProvider    = context.read<BleProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    await bleProvider.stopScan();
    if (!mounted) return;

    // Swap transport to BLE
    deviceProvider.setTransport(bleProvider.bleService);

    await _connect(device, deviceProvider);
  }

  Future<void> _connectSerial(DeviceInfo device) async {
    final serialProvider = context.read<SerialProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    await serialProvider.stopScan();
    if (!mounted) return;

    // Swap transport to Serial
    deviceProvider.setTransport(serialProvider.serialService);

    await _connect(device, deviceProvider);
  }

  Future<void> _connect(DeviceInfo device, DeviceProvider deviceProvider) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to ${device.displayName}...'),
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );

    await deviceProvider.connectToDevice(device);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (deviceProvider.connectionState == DeviceConnectionState.connected) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else {
      final error = deviceProvider.errorMessage ?? 'Connection failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: RadioKitAppBar(
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_rounded),
            tooltip: 'Debug Monitor',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DebugScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth_rounded), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.usb_rounded), text: 'USB Serial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BleTab(onDeviceTapped: _connectBle),
          _SerialTab(onPortTapped: _connectSerial),
        ],
      ),
    );
  }
}

// ===========================================================================
// BLE Tab
// ===========================================================================

class _BleTab extends StatelessWidget {
  final Future<void> Function(DeviceInfo) onDeviceTapped;

  const _BleTab({required this.onDeviceTapped});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, _) {
        if (bleProvider.errorMessage != null) {
          return _buildErrorState(context, bleProvider.errorMessage!);
        }
        if (kIsWeb) {
          return _buildWebPickerState(context, bleProvider);
        }
        if (bleProvider.devices.isEmpty) {
          return _buildEmptyState(context, bleProvider);
        }
        return _buildDeviceList(context, bleProvider);
      },
    );
  }

  Widget _buildWebPickerState(BuildContext context, BleProvider bleProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LogoIcon(),
            const SizedBox(height: 32),
            Text('RadioKit Web', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: bleProvider.isAvailable,
              builder: (context, snapshot) {
                final isSupported = bleProvider.isSupported;
                final isAvailable = snapshot.data ?? false;

                String message = 'Ready to connect';
                IconData icon   = Icons.check_circle_outline_rounded;
                Color color     = AppColors.connected;

                if (!isSupported) {
                  message = 'Browser does not support Web Bluetooth';
                  icon    = Icons.error_outline_rounded;
                  color   = Theme.of(context).colorScheme.error;
                } else if (!isAvailable && snapshot.connectionState == ConnectionState.done) {
                  message = 'Bluetooth hardware not found or disabled';
                  icon    = Icons.bluetooth_disabled_rounded;
                  color   = Theme.of(context).colorScheme.error;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Click the button below to open the browser Bluetooth device picker.\n'
              'Make sure your Arduino is powered on and running the RadioKit sketch.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            bleProvider.isScanning
                ? CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.bluetooth_searching_rounded),
                    label: const Text('Connect via Bluetooth'),
                    onPressed: () async {
                      await bleProvider.startScan();
                      if (bleProvider.devices.isNotEmpty) {
                        await onDeviceTapped(bleProvider.devices.first);
                      }
                    },
                  ),
            const SizedBox(height: 32),
            _DemoModeButton(
              onPressed: () {
                bleProvider.useMockDevice();
                onDeviceTapped(bleProvider.devices.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, BleProvider bleProvider) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: () => bleProvider.startScan(),
      child: Column(
        children: [
          if (bleProvider.isScanning)
            LinearProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bleProvider.devices.length,
              itemBuilder: (context, index) {
                return _DeviceCard(
                  device: bleProvider.devices[index],
                  icon: Icons.bluetooth_rounded,
                  subtitle: bleProvider.devices[index].id,
                  onTap: () => onDeviceTapped(bleProvider.devices[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BleProvider bleProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bleProvider.isScanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.bluetooth_disabled_rounded,
              size: 72,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 24),
            Text(
              bleProvider.isScanning
                  ? 'Scanning for devices...'
                  : 'No RadioKit devices found.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              bleProvider.isScanning
                  ? 'Make sure your Arduino is powered on and running the RadioKit library.'
                  : 'Tap the refresh icon or pull down to rescan.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (bleProvider.isScanning) ...[
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: AppColors.brandOrange,
                strokeWidth: 2,
              ),
            ] else ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Scan Again'),
                onPressed: () => bleProvider.startScan(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled_rounded,
                size: 72, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 24),
            Text('Bluetooth Error', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Serial Tab
// ===========================================================================

class _SerialTab extends StatelessWidget {
  final Future<void> Function(DeviceInfo) onPortTapped;

  const _SerialTab({required this.onPortTapped});

  @override
  Widget build(BuildContext context) {
    return Consumer<SerialProvider>(
      builder: (context, serialProvider, _) {
        if (!serialProvider.isSupported) {
          return _buildUnsupported(context);
        }
        if (serialProvider.errorMessage != null) {
          return _buildErrorState(context, serialProvider.errorMessage!);
        }
        if (kIsWeb) {
          return _buildWebPickerState(context, serialProvider);
        }
        if (serialProvider.ports.isEmpty) {
          return _buildEmptyState(context, serialProvider);
        }
        return _buildPortList(context, serialProvider);
      },
    );
  }

  Widget _buildWebPickerState(BuildContext context, SerialProvider serialProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb_rounded, size: 72,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 32),
            Text('USB Serial', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Click the button to open the browser\'s serial port picker.\n'
              'Connect your Arduino via USB, then select the COM/tty port.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            serialProvider.isScanning
                ? CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.usb_rounded),
                    label: const Text('Select Serial Port'),
                    onPressed: () async {
                      final port = await serialProvider.startScan();
                      if (port != null && context.mounted) {
                        await onPortTapped(port);
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortList(BuildContext context, SerialProvider serialProvider) {
    return Column(
      children: [
        if (serialProvider.isScanning)
          LinearProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
        ListTile(
          dense: true,
          leading: Icon(Icons.refresh_rounded,
              color: Theme.of(context).colorScheme.primary),
          title: Text('Refresh ports',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          onTap: () => serialProvider.startScan(),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: serialProvider.ports.length,
            itemBuilder: (context, index) {
              final port = serialProvider.ports[index];
              return _DeviceCard(
                device: port,
                icon: Icons.usb_rounded,
                subtitle: port.id,
                onTap: () => onPortTapped(port),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, SerialProvider serialProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb_off_rounded, size: 72,
                color: Theme.of(context).disabledColor),
            const SizedBox(height: 24),
            Text(
              serialProvider.isScanning
                  ? 'Scanning USB ports...'
                  : 'No USB Serial devices found.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your Arduino via USB and make sure the RadioKit sketch is running.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Scan Again'),
              onPressed: () => serialProvider.startScan(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupported(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb_off_rounded, size: 72,
                color: Theme.of(context).disabledColor),
            const SizedBox(height: 24),
            Text('USB Serial Not Supported',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'USB Serial is available on Android and on Chrome/Edge (Web Serial API).\n'
              'This platform does not support it.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb_off_rounded, size: 72,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 24),
            Text('Serial Error', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared sub-widgets
// ===========================================================================

/// Generic device/port list card.
class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.icon,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: Theme.of(context).colorScheme.onPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Show RSSI bars only for BLE (serial rssi == 0)
              if (device.rssi != 0) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SignalBars(bars: device.signalBars),
                    const SizedBox(height: 3),
                    Text('${device.rssi} dBm',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int bars;
  const _SignalBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = (i + 1) <= bars;
        return Container(
          width: 5,
          height: 6.0 + i * 3.0,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.connected : Theme.of(context).disabledColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}

class _DemoModeButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DemoModeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_rounded,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              'Try Interactive Demo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
