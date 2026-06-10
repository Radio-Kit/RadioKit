import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/device_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/serial_provider.dart';
import '../../models/device_info.dart';
import '../../theme/app_theme.dart';
import '../../services/websocket_service.dart';
import '../../widgets/console_log_view.dart';

// ── Pair Bottom Sheet ──────────────────────────────────────────────────────

void showPairBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => const PairBottomSheet(),
  );
}

class PairBottomSheet extends StatefulWidget {
  const PairBottomSheet();

  @override
  State<PairBottomSheet> createState() => _PairBottomSheetState();
}

class _PairBottomSheetState extends State<PairBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBaud = '1000000';
  final Set<String> _connectingIds = {};
  final Map<String, String> _failedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Defer scanning to avoid calling notifyListeners() during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScan();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startScan();
      });
    }
  }

  void _startScan() {
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    ble.startScan();
    serial.startScan();
    // WiFi tab needs no scan — manual IP entry
  }

  Future<void> _connectBle(DeviceInfo device) async {
    final id = device.id;
    if (_connectingIds.contains(id)) return;
    setState(() {
      _connectingIds.add(id);
      _failedIds.remove(id);
    });

    try {
      final bleProvider = context.read<BleProvider>();
      final deviceProvider = context.read<DeviceProvider>();
      final history = context.read<HistoryProvider>();

      await bleProvider.stopScan();
      if (!mounted) return;

      deviceProvider.setTransport(bleProvider.bleService);
      await deviceProvider.connectToDevice(device);
      if (!mounted) return;

      if (deviceProvider.isConnected) {
        await history.saveDevice(
          device,
          'ble',
          configName: deviceProvider.configName,
          description: deviceProvider.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control');
        }
        return;
      }
      // Connection completed but not connected
      if (mounted) {
        setState(() => _failedIds[id] = 'Connection failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _failedIds[id] = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _connectingIds.remove(id));
    }
  }

  Future<void> _connectSerial(DeviceInfo device, int baudRate) async {
    final id = device.id;
    if (_connectingIds.contains(id)) return;
    setState(() {
      _connectingIds.add(id);
      _failedIds.remove(id);
    });

    try {
      final serialProvider = context.read<SerialProvider>();
      final deviceProvider = context.read<DeviceProvider>();
      final history = context.read<HistoryProvider>();

      await serialProvider.stopScan();
      if (!mounted) return;

      deviceProvider.setTransport(serialProvider.serialService);
      await deviceProvider.connectToDevice(device, baudRate: baudRate);
      if (!mounted) return;

      if (deviceProvider.isConnected) {
        await history.saveDevice(
          device,
          'serial',
          configName: deviceProvider.configName,
          description: deviceProvider.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control');
        }
        return;
      }
      // Connection completed but not connected
      if (mounted) {
        setState(() => _failedIds[id] = 'Connection failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _failedIds[id] = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _connectingIds.remove(id));
    }
  }

  Future<void> _connectWiFi(String host, int port) async {
    final url = 'ws://$host:$port';
    // Build a device ID that can be detected as WiFi transport
    final deviceId = 'ws://$host:$port';
    if (_connectingIds.contains(deviceId)) return;
    setState(() {
      _connectingIds.add(deviceId);
      _failedIds.remove(deviceId);
    });

    try {
      final deviceProvider = context.read<DeviceProvider>();
      final history = context.read<HistoryProvider>();

      final wsService = WebSocketService();
      deviceProvider.setTransport(wsService);
      
      final device = DeviceInfo(
        id: deviceId,
        name: '$host:$port',
        rssi: null,
        hasFs: false,
      );
      await deviceProvider.connectToDevice(device);
      if (!mounted) return;

      if (deviceProvider.isConnected) {
        await history.saveDevice(
          device,
          'wifi',
          configName: deviceProvider.configName,
          description: deviceProvider.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control');
        }
        return;
      }
      if (mounted) {
        setState(() => _failedIds[deviceId] = 'Connection failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _failedIds[deviceId] = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _connectingIds.remove(deviceId));
    }
  }

  void _dismissError(String id) {
    setState(() => _failedIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.brandOrange,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
            tabs: const [
              Tab(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('BLE'),
                ],
              )),
              Tab(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.usb_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('USB'),
                ],
              )),
              Tab(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('WiFi'),
                ],
              )),
            ],
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabController,
              children: [
                _PairBleTab(
                  onConnect: _connectBle,
                  connectingIds: _connectingIds,
                  failedIds: _failedIds,
                  onDismissError: _dismissError,
                ),
                _PairUsbTab(
                  onConnect: _connectSerial,
                  connectingIds: _connectingIds,
                  failedIds: _failedIds,
                  onDismissError: _dismissError,
                  selectedBaud: _selectedBaud,
                  onBaudChanged: (v) => setState(() => _selectedBaud = v),
                ),
                _PairWiFiTab(
                  onConnect: _connectWiFi,
                  connectingIds: _connectingIds,
                  failedIds: _failedIds,
                  onDismissError: _dismissError,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            flex: 1,
            child: ConsoleLogView(height: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ── Pair BLE Tab ─────────────────────────────────────────────────────────────

class _PairBleTab extends StatelessWidget {
  final Future<void> Function(DeviceInfo) onConnect;
  final Set<String> connectingIds;
  final Map<String, String> failedIds;
  final ValueChanged<String> onDismissError;

  const _PairBleTab({
    required this.onConnect,
    required this.connectingIds,
    required this.failedIds,
    required this.onDismissError,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, ble, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status header ──────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ble.isScanning || ble.devices.isNotEmpty
                          ? AppColors.brandOrange
                          : Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ble.isScanning ? 'SCANNING' : 'IDLE',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.0),
                      ),
                      const Text('BLUETOOTH LOW ENERGY',
                          style: TextStyle(color: Colors.white24, fontSize: 8)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${ble.devices.length.toString().padLeft(2, '0')}_NODES',
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ble.isScanning ? null : 1.0,
                backgroundColor: const Color(0x0DFFFFFF),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.brandOrange),
                minHeight: 1,
              ),
              const SizedBox(height: 20),
              // ── Device list ───────────────────────────────────
              if (ble.devices.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      ble.isScanning ? 'Scanning...' : 'No BLE devices found',
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                )
              else
                ...ble.devices.map(
                  (device) => _PairDeviceCard(
                    device: device,
                    isConnecting: connectingIds.contains(device.id),
                    errorMessage: failedIds[device.id],
                    trailing: _PairSignalBars(rssi: device.rssi),
                    onTap: () => onConnect(device),
                    onRetry: () => onConnect(device),
                    onDismissError: () => onDismissError(device.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Pair USB Tab ─────────────────────────────────────────────────────────────

class _PairUsbTab extends StatelessWidget {
  final Future<void> Function(DeviceInfo device, int baudRate) onConnect;
  final Set<String> connectingIds;
  final Map<String, String> failedIds;
  final ValueChanged<String> onDismissError;
  final String selectedBaud;
  final ValueChanged<String> onBaudChanged;

  const _PairUsbTab({
    required this.onConnect,
    required this.connectingIds,
    required this.failedIds,
    required this.onDismissError,
    required this.selectedBaud,
    required this.onBaudChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SerialProvider>(
      builder: (context, serial, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status header (same style as BLE tab) ──────────
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: serial.ports.isNotEmpty
                          ? AppColors.brandOrange
                          : Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SCANNING',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0)),
                      const Text('USB SERIAL',
                          style: TextStyle(color: Colors.white24, fontSize: 8)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${serial.ports.length.toString().padLeft(2, '0')}_PORTS',
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                value: null,
                backgroundColor: Color(0x0DFFFFFF),
                valueColor:
                    AlwaysStoppedAnimation(AppColors.brandOrange),
                minHeight: 1,
              ),
              const SizedBox(height: 20),
              // ── Port list ─────────────────────────────────────
              if (serial.ports.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('No serial ports found',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                  ),
                )
              else
                ...serial.ports.map(
                  (port) => _PairSerialDeviceCard(
                    device: port,
                    isConnecting: connectingIds.contains(port.id),
                    errorMessage: failedIds[port.id],
                    selectedBaud: selectedBaud,
                    onBaudChanged: onBaudChanged,
                    onConnect: () =>
                        onConnect(port, int.tryParse(selectedBaud) ?? 1000000),
                    onRetry: () =>
                        onConnect(port, int.tryParse(selectedBaud) ?? 1000000),
                    onDismissError: () => onDismissError(port.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Pair WiFi Tab ────────────────────────────────────────────────────────────

class _PairWiFiTab extends StatefulWidget {
  final Future<void> Function(String host, int port) onConnect;
  final Set<String> connectingIds;
  final Map<String, String> failedIds;
  final ValueChanged<String> onDismissError;

  const _PairWiFiTab({
    required this.onConnect,
    required this.connectingIds,
    required this.failedIds,
    required this.onDismissError,
  });

  @override
  State<_PairWiFiTab> createState() => _PairWiFiTabState();
}

class _PairWiFiTabState extends State<_PairWiFiTab> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '5555');
  bool _connecting = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final port = int.tryParse(portStr);
    if (host.isEmpty) return;
    if (port == null || port < 1 || port > 65535) return;

    setState(() => _connecting = true);
    try {
      await widget.onConnect(host, port);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status header ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandOrange,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ENTER DEVICE ADDRESS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0)),
                  const Text('WiFi / WEBSOCKET',
                      style: TextStyle(color: Colors.white24, fontSize: 8)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Host input ─────────────────────────────────────────
          TextFormField(
            controller: _hostController,
            autofocus: true,
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              hintText: '192.168.4.1',
              hintStyle: const TextStyle(color: Colors.white24),
              labelText: 'IP ADDRESS / HOSTNAME',
              labelStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: AppColors.brandOrange.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Port input ─────────────────────────────────────────
          TextFormField(
            controller: _portController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              hintText: '5555',
              hintStyle: const TextStyle(color: Colors.white24),
              labelText: 'PORT',
              labelStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: AppColors.brandOrange.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Connect button ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandOrange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: _connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.wifi_rounded, size: 20),
              label: Text(
                  _connecting ? 'CONNECTING...' : 'CONNECT',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 14,
                      height: 1)),
              onPressed: _connecting ? null : _connect,
            ),
          ),
          const SizedBox(height: 16),
          // ── Help text ──────────────────────────────────────────
          const Text(
            'Enter the IP address or hostname of your RadioKit device.\n'
            'The device must be on the same network and have WiFi transport enabled.\n'
            'Default WebSocket port is 5555.',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Pair Device Card (BLE) ───────────────────────────────────────────────────

class _PairDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isConnecting;
  final String? errorMessage;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onDismissError;

  const _PairDeviceCard({
    required this.device,
    required this.isConnecting,
    this.errorMessage,
    this.trailing,
    required this.onTap,
    this.onRetry,
    this.onDismissError,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && !isConnecting;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasError
          ? Colors.redAccent.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.05),
      child: InkWell(
        onTap: isConnecting ? null : hasError ? onRetry : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Connection indicator
              if (isConnecting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasError)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Icon(Icons.error_rounded,
                      size: 16, color: Colors.redAccent),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.connected,
                  ),
                ),
              const SizedBox(width: 14),
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName.toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          color: hasError ? Colors.redAccent : Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isConnecting
                          ? 'Connecting...'
                          : hasError
                              ? errorMessage!
                              : 'READY TO PAIR',
                      style: TextStyle(
                        color: hasError
                            ? Colors.redAccent
                            : isConnecting
                                ? AppColors.brandOrange
                                : Colors.white38,
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Trailing
              if (isConnecting)
                const SizedBox.shrink()
              else if (hasError)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDismissError != null)
                      GestureDetector(
                        onTap: () => onDismissError!(),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Colors.white38),
                      ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                )
              else ...[
                if (trailing != null) trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pair Signal Bars ─────────────────────────────────────────────────────────

class _PairSignalBars extends StatelessWidget {
  final int rssi;
  const _PairSignalBars({required this.rssi});

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

// ── Pair Serial Device Card ──────────────────────────────────────────────────

class _PairSerialDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isConnecting;
  final String? errorMessage;
  final String selectedBaud;
  final ValueChanged<String> onBaudChanged;
  final VoidCallback onConnect;
  final VoidCallback? onRetry;
  final VoidCallback? onDismissError;

  const _PairSerialDeviceCard({
    required this.device,
    required this.isConnecting,
    this.errorMessage,
    required this.selectedBaud,
    required this.onBaudChanged,
    required this.onConnect,
    this.onRetry,
    this.onDismissError,
  });

  static const _baudRates = ['9600', '19200', '38400', '57600', '115200', '1000000'];

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && !isConnecting;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasError
          ? Colors.redAccent.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Status indicator
            if (isConnecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (hasError)
              SizedBox(
                width: 16,
                height: 16,
                child: Icon(Icons.error_rounded,
                    size: 16, color: Colors.redAccent),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.connected,
                ),
              ),
            const SizedBox(width: 14),
            // Port name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: hasError ? Colors.redAccent : Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isConnecting
                        ? 'Connecting...'
                        : hasError
                            ? errorMessage!
                            : 'READY TO PAIR',
                    style: TextStyle(
                      color: hasError
                          ? Colors.redAccent
                          : isConnecting
                              ? AppColors.brandOrange
                              : Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Baud rate selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: PopupMenuButton<String>(
                onSelected: onBaudChanged,
                initialValue: selectedBaud,
                offset: const Offset(0, 30),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selectedBaud,
                        style: GoogleFonts.jetBrainsMono(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const Icon(Icons.arrow_drop_down_rounded,
                        size: 16, color: Colors.white38),
                  ],
                ),
                itemBuilder: (ctx) =>
                    _baudRates.map((rate) => PopupMenuItem(
                      value: rate,
                      child: Text(rate,
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 12, color: Colors.white)),
                    )).toList(),
              ),
            ),
            const SizedBox(width: 8),
            // Connect button
            SizedBox(
              height: 32,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: hasError ? onRetry : onConnect,
                child: Text(hasError ? 'RETRY' : 'CONNECT',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
