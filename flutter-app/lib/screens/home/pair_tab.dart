import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/serial_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/console_provider.dart';
import '../../models/device_info.dart';
import '../../models/console_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/console_log_view.dart';
import '../../widgets/logo_icon.dart';

class PairTab extends StatefulWidget {
  const PairTab({super.key});

  @override
  State<PairTab> createState() => _PairTabState();
}

class _PairTabState extends State<PairTab> {
  int _selectedTransportIndex = 0; // 0: BLE, 1: USB

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScan();
      });
    }
  }

  Future<void> _startScan() async {
    final console = context.read<ConsoleProvider>();
    if (_selectedTransportIndex == 0) {
      final ble = context.read<BleProvider>();
      console.log('INITIALIZING BLE_SCANNER...', level: ConsoleLogLevel.info);
      console.log('STEP 1: REQUESTING PERMISSIONS', level: ConsoleLogLevel.info);
      await ble.startScan();
      if (ble.errorMessage != null) {
        console.log('FAILED: ${ble.errorMessage}', level: ConsoleLogLevel.error);
      } else {
        console.log('SUCCESS: SCANNER_ACTIVE', level: ConsoleLogLevel.info);
      }
    } else {
      final serial = context.read<SerialProvider>();
      console.log('SCANNING SERIAL_PORTS...', level: ConsoleLogLevel.info);
      await serial.startScan();
      console.log('SERIAL_SCAN_COMPLETE', level: ConsoleLogLevel.info);
    }
  }

  Future<void> _connectBle(DeviceInfo device) async {
    final bleProvider    = context.read<BleProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final history        = context.read<HistoryProvider>();
    final console        = context.read<ConsoleProvider>();

    console.log('READY TO PAIR: ${device.displayName}', level: ConsoleLogLevel.info);
    await bleProvider.stopScan();
    if (!mounted) return;

    // Wire up logs from the BLE service to our UI console
    final bleService = bleProvider.bleService;
    bleService.logStream.listen((msg) {
      console.log('BLE: $msg', level: ConsoleLogLevel.info);
    });

    deviceProvider.setTransport(bleService);
    final success = await _connect(device, deviceProvider, console);

    if (success) {
      await history.saveDevice(
        device,
        'ble',
        configName: deviceProvider.configName,
        description: deviceProvider.description,
      );
    }
  }

  Future<void> _connectSerial(DeviceInfo device, {int baudRate = 115200}) async {
    final serialProvider = context.read<SerialProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final history        = context.read<HistoryProvider>();
    final console        = context.read<ConsoleProvider>();

    console.log('CONNECTING VIA USB: ${device.displayName}', level: ConsoleLogLevel.info);
    await serialProvider.stopScan();
    if (!mounted) return;

    deviceProvider.setTransport(serialProvider.serialService);
    final success = await _connect(device, deviceProvider, console, baudRate: baudRate);

    if (success) {
      await history.saveDevice(
        device,
        'serial',
        configName: deviceProvider.configName,
        description: deviceProvider.description,
      );
    }
  }

  Future<bool> _connect(
    DeviceInfo device,
    DeviceProvider deviceProvider,
    ConsoleProvider console, {
    int baudRate = 115200,
  }) async {
    if (!mounted) return false;
    console.log('ESTABLISHING HANDSHAKE...', level: ConsoleLogLevel.info);
    await deviceProvider.connectToDevice(device, baudRate: baudRate);
    if (!mounted) return false;

    if (deviceProvider.connectionState == DeviceConnectionState.connected) {
      console.log('CONNECTION ESTABLISHED', level: ConsoleLogLevel.success);
      if (mounted) context.go('/control');
      return true;
    } else {
      final error = deviceProvider.errorMessage ?? 'Connection failed';
      console.log('ERROR: $error', level: ConsoleLogLevel.error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const LogoIcon(),
            const SizedBox(width: 12),
            Text(
              'RADIO_KIT',
              style: GoogleFonts.audiowide(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > constraints.maxHeight) {
            return _buildLandscapeLayout();
          }
          return _buildPortraitLayout();
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildTransportToggle(),
        Expanded(
          child: _selectedTransportIndex == 0
              ? _BleTab(onDeviceTapped: _connectBle)
              : _SerialTab(
                  onPortTapped: (device, baud) =>
                      _connectSerial(device, baudRate: baud)),
        ),
        const ConsoleLogView(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildTransportToggle(),
              Expanded(
                child: _selectedTransportIndex == 0
                    ? _BleTab(onDeviceTapped: _connectBle)
                    : _SerialTab(
                        onPortTapped: (device, baud) =>
                            _connectSerial(device, baudRate: baud)),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: const ConsoleLogView(height: double.infinity),
        ),
      ],
    );
  }

  Widget _buildTransportToggle() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ToggleOption(
                label: 'BLE',
                isActive: _selectedTransportIndex == 0,
                onTap: () {
                  setState(() => _selectedTransportIndex = 0);
                  _startScan();
                },
              ),
            ),
            Expanded(
              child: _ToggleOption(
                label: 'USB',
                isActive: _selectedTransportIndex == 1,
                onTap: () {
                  setState(() => _selectedTransportIndex = 1);
                  _startScan();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleOption(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.changa(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.black : Colors.white38,
            letterSpacing: 1.2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── BLE Tab ──────────────────────────────────────────────────────────────────

class _BleTab extends StatelessWidget {
  final Future<void> Function(DeviceInfo) onDeviceTapped;
  const _BleTab({required this.onDeviceTapped});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, ble, _) {
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildStatusHeader(
                context,
                label: ble.isScanning ? 'SCANNING' : 'IDLE',
                subtitle: 'BLUETOOTH LOW ENERGY',
                protocol: 'BT_SIG_4.2',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DISCOVERED_UNITS',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.brandOrange)),
                    Text(
                        '${ble.devices.length.toString().padLeft(2, '0')}_NODES_FOUND',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 9)),
                  ],
                ),
              ),
              if (ble.devices.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      ble.isScanning ? '...' : 'No units found',
                      style: const TextStyle(color: Colors.white12),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ble.devices.length,
                  itemBuilder: (context, index) {
                    return _UnitCard(
                      device: ble.devices[index],
                      onTap: () => onDeviceTapped(ble.devices[index]),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(BuildContext context,
      {required String label,
      required String subtitle,
      required String protocol}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: label == 'SCANNING'
                        ? AppColors.brandOrange
                        : Colors.white12),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 8)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('PROTOCOL',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 8)),
                  Text(protocol,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            value: 0.3,
            backgroundColor: Color(0x0DFFFFFF),
            valueColor:
                AlwaysStoppedAnimation(AppColors.brandOrange),
            minHeight: 1,
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback onTap;
  const _UnitCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.displayName.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.connected)),
                      const SizedBox(width: 6),
                      const Text('READY TO PAIR',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _SignalBars(rssi: device.rssi),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int rssi;
  const _SignalBars({required this.rssi});

  @override
  Widget build(BuildContext context) {
    int bars = 0;
    if (rssi > -60) {
      bars = 4;
    } else if (rssi > -70) {
      bars = 3;
    } else if (rssi > -80) {
      bars = 2;
    } else if (rssi > -90) {
      bars = 1;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        return Container(
          width: 3,
          height: 8 + (i * 3.0),
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.brandOrange : Colors.white12,
            borderRadius: BorderRadius.circular(0.5),
          ),
        );
      }),
    );
  }
}

// ── Serial Tab ───────────────────────────────────────────────────────────────

class _SerialTab extends StatefulWidget {
  final Future<void> Function(DeviceInfo device, int baudRate) onPortTapped;
  const _SerialTab({required this.onPortTapped});

  @override
  State<_SerialTab> createState() => _SerialTabState();
}

class _SerialTabState extends State<_SerialTab> {
  String _selectedBaud = '115200';
  DeviceInfo? _selectedPort;

  @override
  Widget build(BuildContext context) {
    return Consumer<SerialProvider>(
      builder: (context, serial, _) {
        if (_selectedPort == null && serial.ports.isNotEmpty) {
          _selectedPort = serial.ports.first;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildConfigCard(serial),
        );
      },
    );
  }

  Widget _buildConfigCard(SerialProvider serial) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HARDWARE_INTERFACE',
                style: TextStyle(
                    color: AppColors.brandOrange,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            const Text('CONFIGURATION',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 24),
            _buildDropdownLabel('SERIAL_PORT'),
            _buildDropdown<DeviceInfo?>(
              value: _selectedPort,
              items: serial.ports
                  .map((p) => DropdownMenuItem(
                      value: p, child: Text(p.displayName)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPort = v),
              hint: 'Select device...',
            ),
            const SizedBox(height: 16),
            _buildDropdownLabel('BAUD_RATE'),
            _buildDropdown<String>(
              value: _selectedBaud,
              items: ['9600', '19200', '38400', '57600', '115200']
                  .map((b) =>
                      DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBaud = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black),
                onPressed: _selectedPort == null
                    ? null
                    : () => widget.onPortTapped(
                          _selectedPort!,
                          int.tryParse(_selectedBaud) ?? 115200,
                        ),
                child: Text('CONNECT_+',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF2A2A2A),
          hint: hint != null
              ? Text(hint,
                  style: const TextStyle(color: Colors.white24))
              : null,
          isExpanded: true,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
