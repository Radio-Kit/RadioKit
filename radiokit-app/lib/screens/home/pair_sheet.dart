import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/device_provider.dart';
import '../../providers/multi_device_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/mdns_provider.dart';
import '../../providers/serial_provider.dart';
import '../../providers/cloud_identity_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/account.dart';
import 'accounts_sheet.dart';
import '../../models/device_info.dart';
import '../../theme/app_theme.dart';
import '../../services/websocket_service.dart';
import '../../widgets/console_log_view.dart';
import '../../services/ble_transport.dart';

// ── Pair Bottom Sheet ──────────────────────────────────────────────────────

void showPairBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.tokens.surface,
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
    _tabController = TabController(length: 4, vsync: this);
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
    final mdns = context.read<MdnsProvider>();
    ble.startScan();
    serial.startScan();
    if (mdns.isSupported) mdns.startScan();
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
      final multiDevice = context.read<MultiDeviceProvider>();
      final history = context.read<HistoryProvider>();

      await bleProvider.stopScan();
      if (!mounted) return;

      await multiDevice.connectDevice(device: device, transport: BleTransport(bleProvider.bleService));
      if (!mounted) return;

      final connected = multiDevice.isDeviceConnected(device.id);
        if (connected) {
        final dp = multiDevice.getDevice(device.id);
        await history.saveDevice(
          device,
          'ble',
          configName: dp?.configName,
          description: dp?.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control/${device.id}');
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
      final multiDevice = context.read<MultiDeviceProvider>();
      final history = context.read<HistoryProvider>();

      await serialProvider.stopScan();
      if (!mounted) return;

      await multiDevice.connectDevice(device: device, transport: serialProvider.serialService, baudRate: baudRate);
      if (!mounted) return;

      final connected = multiDevice.isDeviceConnected(device.id);
        if (connected) {
        final dp = multiDevice.getDevice(device.id);
        await history.saveDevice(
          device,
          'serial',
          configName: dp?.configName,
          description: dp?.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control/${device.id}');
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

  Future<void> _connectWiFi(DeviceInfo device) async {
    final deviceId = device.id;
    if (_connectingIds.contains(deviceId)) return;
    setState(() {
      _connectingIds.add(deviceId);
      _failedIds.remove(deviceId);
    });

    try {
      final multiDevice = context.read<MultiDeviceProvider>();
      final history = context.read<HistoryProvider>();
      final mdns = context.read<MdnsProvider>();
      await mdns.stopScan();
      if (!mounted) return;

      final wsService = WebSocketService();
      await multiDevice.connectDevice(device: device, transport: wsService);
      if (!mounted) return;

      final connected = multiDevice.isDeviceConnected(device.id);
        if (connected) {
        final dp = multiDevice.getDevice(device.id);
        await history.saveDevice(
          device,
          'wifi',
          configName: dp?.configName,
          description: dp?.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control/${device.id}');
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

  /// Called by `_PairCloudTab` after the user selects a device from the list.
  /// The WebSocket is already connected and has joined the device on the relay.
  Future<void> _finalizeCloudConnection(WebSocketService ws, String host,
      int port, String deviceName, String account) async {
    final url = '${port == 443 ? "wss" : "ws"}://$host:$port';
    final displayName = '$deviceName @ $host:$port';
    if (_connectingIds.contains(url)) return;
    setState(() => _connectingIds.add(url));

    try {
      final multiDevice = context.read<MultiDeviceProvider>();
      final history = context.read<HistoryProvider>();

      final cloudDevice = DeviceInfo(
        id: url,
        name: displayName,
        rssi: 0,
        hasFs: false,
        currentTransport: TransportType.cloud,
        transportAddress: url,
      );
      await multiDevice.connectDevice(device: cloudDevice, transport: ws);
      if (!mounted) return;

      final connected = multiDevice.isDeviceConnected(url);
        if (connected) {
        final dp = multiDevice.getDevice(url);
        final savedDevice = DeviceInfo(
          id: url,
          name: displayName,
          rssi: 0,
          hasFs: dp?.hasFs ?? false,
          currentTransport: TransportType.cloud,
          transportAddress: url,
        );
        await history.saveDevice(
          savedDevice,
          'cloud',
          configName: dp?.configName,
          description: dp?.description,
        );
        if (mounted) {
          Navigator.of(context).maybePop();
          context.go('/control/${Uri.encodeComponent(url)}');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        _showError('Cloud join failed: $e');
      }
    } finally {
      if (mounted) setState(() => _connectingIds.remove(url));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
            indicatorColor: context.tokens.primary,
            labelColor: context.tokens.onSurface,
            unselectedLabelColor: context.tokens.onSurface.withValues(alpha: 0.54),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
            tabs: const [
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.usb_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('USB'),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('BLE'),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('WiFi'),
                ],
              )),
              Tab(
                  child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Cloud'),
                ],
              )),
            ],
          ),
          Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabController,
              children: [
                _PairUsbTab(
                  onConnect: _connectSerial,
                  connectingIds: _connectingIds,
                  failedIds: _failedIds,
                  onDismissError: _dismissError,
                  selectedBaud: _selectedBaud,
                  onBaudChanged: (v) => setState(() => _selectedBaud = v),
                ),
                _PairBleTab(
                  onConnect: _connectBle,
                  connectingIds: _connectingIds,
                  failedIds: _failedIds,
                  onDismissError: _dismissError,
                ),
                Consumer<MdnsProvider>(
                  builder: (context, mdns, _) => _PairWiFiTab(
                    onConnect: _connectWiFi,
                    connectingIds: _connectingIds,
                    failedIds: _failedIds,
                    onDismissError: _dismissError,
                    discoveredDevices: mdns.devices,
                    isScanning: mdns.isScanning,
                    isMdnsSupported: mdns.isSupported,
                  ),
                ),
                _PairCloudTab(
                  onFinalize: _finalizeCloudConnection,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
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
                          ? context.tokens.primary
                          : context.tokens.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                  SizedBox(width: 12),
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
                      Text('BLUETOOTH LOW ENERGY',
                          style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 8)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${ble.devices.length.toString().padLeft(2, '0')}_NODES',
                    style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 9),
                  ),
                ],
              ),
              SizedBox(height: 12),
              LinearProgressIndicator(
                value: ble.isScanning ? null : 1.0,
                backgroundColor: context.tokens.onSurface.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(context.tokens.primary),
                minHeight: 1,
              ),
              SizedBox(height: 20),
              // ── Device list ───────────────────────────────────
              if (ble.devices.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      ble.isScanning ? 'Scanning...' : 'No BLE devices found',
                      style:
                          TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 12),
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
                          ? context.tokens.primary
                          : context.tokens.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SCANNING',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0)),
                      Text('USB SERIAL',
                          style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 8)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${serial.ports.length.toString().padLeft(2, '0')}_PORTS',
                    style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 9),
                  ),
                ],
              ),
              SizedBox(height: 12),
              LinearProgressIndicator(
                value: null,
                backgroundColor: context.tokens.onSurface.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(context.tokens.primary),
                minHeight: 1,
              ),
              SizedBox(height: 20),
              // ── Port list ─────────────────────────────────────
              if (serial.ports.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('No serial ports found',
                        style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 12)),
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

class _PairWiFiTab extends StatelessWidget {
  final Future<void> Function(DeviceInfo) onConnect;
  final Set<String> connectingIds;
  final Map<String, String> failedIds;
  final ValueChanged<String> onDismissError;
  final List<DeviceInfo> discoveredDevices;
  final bool isScanning;
  final bool isMdnsSupported;

  const _PairWiFiTab({
    required this.onConnect,
    required this.connectingIds,
    required this.failedIds,
    required this.onDismissError,
    required this.discoveredDevices,
    required this.isScanning,
    required this.isMdnsSupported,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscovered = discoveredDevices.isNotEmpty;

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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isScanning || hasDiscovered)
                      ? context.tokens.primary
                      : context.tokens.onSurface.withValues(alpha: 0.12),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isScanning
                        ? 'SCANNING'
                        : hasDiscovered
                            ? 'DISCOVERED'
                            : 'IDLE',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0),
                  ),
                  Text('MDNS / WEBSOCKET',
                      style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 8)),
                ],
              ),
              const Spacer(),
              Text(
                '${discoveredDevices.length.toString().padLeft(2, '0')}_NODES',
                style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 9),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: isScanning ? null : 1.0,
            backgroundColor: const Color(0x0DFFFFFF),
            valueColor: AlwaysStoppedAnimation(context.tokens.primary),
            minHeight: 1,
          ),
          SizedBox(height: 16),

          // ── Discovered devices ────────────────────────────────
          if (hasDiscovered) ...[
            ...discoveredDevices.map(
              (device) => _PairDeviceCard(
                device: device,
                isConnecting: connectingIds.contains(device.id),
                errorMessage: failedIds[device.id],
                onTap: () => onConnect(device),
                onRetry: () => onConnect(device),
                onDismissError: () => onDismissError(device.id),
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 1,
              color: context.tokens.onSurface.withValues(alpha: 0.08),
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'OR ENTER MANUALLY',
                style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.3),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            SizedBox(height: 16),
          ],

          // ── No devices found message ──────────────────────────
          if (!hasDiscovered && isScanning)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Scanning for WiFi devices...',
                    style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 12)),
              ),
            ),
          if (!hasDiscovered && !isScanning && isMdnsSupported)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No WiFi devices found on the network\nEnter the IP address manually below',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 11),
                ),
              ),
            ),
          if (!isMdnsSupported)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(
                child: Text(
                  'mDNS discovery is not available on this platform.\nEnter the device IP address manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 11),
                ),
              ),
            ),

          // ── Manual entry form ─────────────────────────────────
          _PairWiFiManualEntry(
            onConnect: (host) {
              final url = 'ws://$host:5555';
              final device = DeviceInfo(
                id: url,
                name: host,
                rssi: 0,
                hasFs: false,
                currentTransport: TransportType.wifi,
                transportAddress: url,
              );
              return onConnect(device);
            },
          ),
        ],
      ),
    );
  }
}

// ── Pair WiFi Manual Entry ──────────────────────────────────────────────────

class _PairWiFiManualEntry extends StatefulWidget {
  final Future<void> Function(String host) onConnect;

  const _PairWiFiManualEntry({required this.onConnect});

  @override
  State<_PairWiFiManualEntry> createState() => _PairWiFiManualEntryState();
}

class _PairWiFiManualEntryState extends State<_PairWiFiManualEntry> {
  final _hostController = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() => _connecting = true);
    try {
      await widget.onConnect(host);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Host input + Connect button ────────────────────────
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hostController,
                style: GoogleFonts.martianMono(
                    color: context.tokens.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.tokens.onSurface.withValues(alpha: 0.05),
                  hintText: '192.168.4.1',
                  hintStyle: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24)),
                  labelText: 'IP ADDRESS',
                  labelStyle: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.38),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: context.tokens.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.tokens.primary,
                  foregroundColor: context.tokens.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _connecting ? null : _connect,
                child: _connecting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.tokens.onPrimary))
                    : const Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // ── Help text ──────────────────────────────────────────
        Text(
          'Enter the IP address of your RadioKit device on the local network.\n'
          'The device must have WiFi transport enabled. Default port is 5555.',
          style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 10),
        ),
      ],
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
          ? context.tokens.error.withValues(alpha: 0.08)
          : context.tokens.onSurface.withValues(alpha: 0.05),
      child: InkWell(
        onTap: isConnecting
            ? null
            : hasError
                ? onRetry
                : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Connection indicator
              if (isConnecting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasError)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Icon(Icons.error_rounded,
                      size: 16, color: context.tokens.error),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.tokens.success,
                  ),
                ),
              SizedBox(width: 14),
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
                          color: hasError ? context.tokens.error : context.tokens.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      isConnecting
                          ? 'Connecting...'
                          : hasError
                              ? errorMessage!
                              : 'READY TO PAIR',
                      style: TextStyle(
                        color: hasError
                            ? context.tokens.error
                            : isConnecting
                                ? context.tokens.primary
                                : context.tokens.onSurface.withValues(alpha: 0.38),
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
                        child: Icon(Icons.close_rounded,
                            size: 16, color: context.tokens.onSurface.withValues(alpha: 0.38)),
                      ),
                    if (trailing != null) ...[
                      SizedBox(width: 8),
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
            color: active ? context.tokens.primary : context.tokens.onSurface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(0.5),
          ),
        );
      }),
    );
  }
}

// ── Pair Cloud Tab ────────────────────────────────────────────────────────────

enum _CloudStep { idle, connectingRelay, deviceList, joiningDevice }

class _PairCloudTab extends StatefulWidget {
  final Future<void> Function(WebSocketService ws, String host, int port,
      String deviceName, String account) onFinalize;

  const _PairCloudTab({required this.onFinalize});

  @override
  State<_PairCloudTab> createState() => _PairCloudTabState();
}

class _PairCloudTabState extends State<_PairCloudTab> {
  final _hostController = TextEditingController();
  final _accountController = TextEditingController();
  _CloudStep _step = _CloudStep.idle;
  WebSocketService? _ws;
  List<String> _devices = [];
  String? _error;
  String _host = '';
  int _port = 443;
  String _account = '';

  @override
  void initState() {
    super.initState();
    // Auto-fill account from Ed25519 keypair or auto-select single account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final identity = context.read<CloudIdentityProvider>();
      final ap = context.read<AccountProvider>();

      if (ap.accounts.length == 1) {
        final account = ap.accounts.first;
        _accountController.text = account.publicKey;
        if (account.relay.isNotEmpty) {
          _hostController.text = account.relay;
        }
        // Auto-connect after a brief delay to let the widget tree settle
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _connectToRelay();
        });
      } else if (identity.account != null) {
        _accountController.text = identity.account!;
        // Auto-select matching account and connect if one exists
        final matching = ap.accounts.where((a) => a.publicKey == identity.account!).toList();
        if (matching.isNotEmpty) {
          final account = matching.first;
          if (account.relay.isNotEmpty) {
            _hostController.text = account.relay;
          }
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _connectToRelay();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _hostController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  String get _scheme => _port == 443 ? 'wss' : 'ws';

  Future<void> _connectToRelay() async {
    final rawHost = _hostController.text.trim();
    final account = _accountController.text.trim();
    if (account.isEmpty) return;

    // Parse host:port
    String host = rawHost;
    int port = 443;
    if (host.isEmpty) {
      host = 'relay.radiokit.app';
    } else if (host.contains(':')) {
      final parts = host.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]) ?? 443;
    }

    _host = host;
    _port = port;
    _account = account;
    _error = null;

    setState(() => _step = _CloudStep.connectingRelay);

    try {
      final ws = WebSocketService()..account = account;
      _ws = ws;

      // Set up Ed25519 identity for challenge-response auth
      final identityProvider = context.read<CloudIdentityProvider>();
      ws.identity = identityProvider.identityService;
      ws.account = account;

      // Listen for auth success → request device list
      ws.onAuthSuccess = () {
        if (!mounted) return;
        _log('Auth succeeded, requesting device list...');
        ws.sendListDevices();
      };

      // Listen for auth failure
      ws.onAuthFailed = (error) {
        if (!mounted) return;
        setState(() {
          _error = 'Authentication failed: $error';
          _step = _CloudStep.idle;
        });
      };

      // Listen for device list
      ws.onDeviceList = (devices) {
        if (!mounted) return;
        setState(() {
          _devices = devices;
          _step = devices.isEmpty ? _CloudStep.idle : _CloudStep.deviceList;
          if (devices.isEmpty) {
            _error = 'No devices found for account public key';
          }
        });
      };

      // Listen for join success
      ws.onCloudJoined = (deviceName) async {
        if (!mounted) return;
        setState(() => _step = _CloudStep.joiningDevice);
        // Hand off to parent for finalization
        await widget.onFinalize(ws, _host, _port, deviceName, _account);
      };

      // Listen for connection lost
      ws.onConnectionLost = (reason) {
        if (!mounted) return;
        setState(() {
          _error = 'Relay connection lost: $reason';
          _step = _CloudStep.idle;
        });
      };

      // Connect to the relay
      final url = '$_scheme://$_host:$_port';
      await ws.connect(url);

      if (!mounted) return;
      _log('Connected to relay, auth flow started...');

      // Timeout after 15 seconds (allows for auth challenge-response + device list)
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _step == _CloudStep.connectingRelay) {
          setState(() {
            _error = 'Timeout waiting for authentication from relay';
            _step = _CloudStep.idle;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to connect: $e';
        _step = _CloudStep.idle;
      });
    }
  }

  Widget _buildRelaySuffix() {
    if (_step == _CloudStep.connectingRelay) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_step == _CloudStep.deviceList) {
      return Icon(
        Icons.check_circle_rounded,
        size: 22,
        color: context.tokens.success.withValues(alpha: 0.8),
      );
    }
    if (_error != null) {
      return Icon(
        Icons.error_rounded,
        size: 22,
        color: context.tokens.error.withValues(alpha: 0.8),
      );
    }
    // Idle — tap to connect
    return IconButton(
      icon: Icon(
        Icons.refresh_rounded,
        size: 20,
        color: context.tokens.primary.withValues(alpha: 0.7),
      ),
      onPressed: _connectToRelay,
      tooltip: 'Connect to relay',
    );
  }

  void _joinDevice(String deviceName) {
    if (_ws == null) return;
    setState(() => _step = _CloudStep.joiningDevice);
    _log('Joining device: $deviceName');
    _ws!.sendJoinForDevice(deviceName);
  }

  void _disconnect() {
    _ws?.disconnect();
    _ws = null;
    _devices = [];
    _error = null;
    setState(() => _step = _CloudStep.idle);
  }

  void _log(String msg) {
    debugPrint('CLOUD_TAB: $msg');
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _error != null
                      ? context.tokens.error
                      : _step == _CloudStep.deviceList
                          ? context.tokens.primary
                          : _step == _CloudStep.idle
                              ? context.tokens.onSurface.withValues(alpha: 0.12)
                              : context.tokens.primary,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error != null
                        ? 'ERROR'
                        : _step == _CloudStep.idle
                            ? 'READY'
                            : _step == _CloudStep.connectingRelay
                                ? 'CONNECTING'
                                : _step == _CloudStep.deviceList
                                    ? '${_devices.length} DEVICE(S)'
                                    : 'JOINING',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0),
                  ),
                  Text(
                    _error != null
                        ? _error!
                        : _step == _CloudStep.connectingRelay
                            ? 'CONNECTING...'
                            : _step == _CloudStep.deviceList
                                ? 'SELECT A DEVICE TO JOIN'
                                : 'CLOUD RELAY',
                    style: TextStyle(
                      color: _error != null
                          ? context.tokens.error
                          : context.tokens.onSurface.withValues(alpha: 0.4),
                      fontSize: 8,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (_step != _CloudStep.idle || _error != null) ...[
                const Spacer(),
                if (_error != null) ...[
                  GestureDetector(
                    onTap: _connectToRelay,
                    child: Icon(Icons.refresh_rounded,
                        size: 18, color: context.tokens.onSurface.withValues(alpha: 0.54)),
                  ),
                  SizedBox(width: 12),
                ],
                GestureDetector(
                  onTap: _disconnect,
                  child: Icon(Icons.close_rounded,
                      size: 18, color: context.tokens.onSurface.withValues(alpha: 0.38)),
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: _step == _CloudStep.idle || _step == _CloudStep.deviceList
                ? 1.0
                : null,
            backgroundColor: const Color(0x0DFFFFFF),
            valueColor: AlwaysStoppedAnimation(context.tokens.primary),
            minHeight: 1,
          ),
          SizedBox(height: 20),

          // ── Input form ──────────────────────────────────────────
          if (_step != _CloudStep.joiningDevice) ...[
            Text('RELAY HOST (OPTIONAL)',
                style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            SizedBox(height: 8),
            TextFormField(
              controller: _hostController,
              style: GoogleFonts.martianMono(
                  color: context.tokens.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.tokens.onSurface.withValues(alpha: 0.05),
                hintText: 'relay.radiokit.app:443',
                hintStyle: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: _buildRelaySuffix(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                      color: context.tokens.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('PUBLIC KEY (ACCOUNT)',
                style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            SizedBox(height: 8),
            Consumer<AccountProvider>(
              builder: (context, ap, _) {
                final accounts = ap.accounts;
                final hasAccounts = accounts.isNotEmpty;

                String? selectedValue;
                // Find which account's public key matches the current input
                if (_accountController.text.isNotEmpty) {
                  final match = accounts.cast<Account?>().firstWhere(
                        (a) => a!.publicKey == _accountController.text,
                        orElse: () => null,
                      );
                  selectedValue = match?.id;
                }

                return DropdownButtonFormField<String>(
                  value: selectedValue,
                  isExpanded: true,
                  dropdownColor: context.tokens.base200,
                  style: GoogleFonts.martianMono(
                    color: context.tokens.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.tokens.onSurface.withValues(alpha: 0.05),
                    hintText:
                        hasAccounts ? 'Select an account' : 'No accounts saved',
                    hintStyle:
                        TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: context.tokens.primary.withValues(alpha: 0.5)),
                    ),
                  ),
                  items: [
                    ...accounts.map((a) => DropdownMenuItem<String>(
                          value: a.id,                              child: Row(
                            children: [
                              Icon(Icons.person_rounded,
                                  size: 16,
                                  color: context.tokens.primary
                                      .withValues(alpha: 0.7)),
                              SizedBox(width: 10),
                              Text(
                                a.name,
                                style: TextStyle(
                                    color: context.tokens.onSurface, fontSize: 13),
                              ),
                            ],
                          ),
                        )),
                    DropdownMenuItem<String>(
                      value: '__manage__',
                      child: Container(
                        decoration: hasAccounts
                            ? BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: context.tokens.onSurface.withValues(alpha: 0.08),
                                  ),
                                ),
                              )
                            : null,
                        padding: EdgeInsets.only(top: hasAccounts ? 8 : 0),
                        child: Row(
                          children: [
                            Icon(Icons.settings_rounded,
                                size: 16,
                                color: context.tokens.onSurface.withValues(alpha: 0.5)),
                            SizedBox(width: 10),
                            Text(
                              'Manage accounts',
                              style: TextStyle(
                                color: context.tokens.onSurface.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__manage__') {
                      AccountsSheet.show(context);
                      return;
                    }
                    if (value != null) {
                      final account = accounts.firstWhere((a) => a.id == value);
                      _accountController.text = account.publicKey;
                      // Auto-fill relay host from account
                      if (account.relay.isNotEmpty) {
                        _hostController.text = account.relay;
                      }
                      // Auto-connect to relay
                      _connectToRelay();
                    }
                  },
                );
              },
            ),
          ],

          // ── Device list ────────────────────────────────────────
          if (_step == _CloudStep.deviceList) ...[
            SizedBox(height: 16),
            Text('AVAILABLE DEVICES',
                style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            SizedBox(height: 12),
            ..._devices.map((name) => _PairDeviceCard(
                  device: DeviceInfo(
                    id: name,
                    name: name,
                    rssi: 0,
                    hasFs: false,
                    currentTransport: TransportType.cloud,
                    transportAddress: name,
                  ),
                  isConnecting: _step == _CloudStep.joiningDevice,
                  onTap: () => _joinDevice(name),
                  onRetry: () => _joinDevice(name),
                )),
          ],

          // ── Joining ────────────────────────────────────────────
          if (_step == _CloudStep.joiningDevice) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: 16),
                    Text('Joining device...',
                        style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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

  static const _baudRates = [
    '9600',
    '19200',
    '38400',
    '57600',
    '115200',
    '1000000'
  ];

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && !isConnecting;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasError
          ? context.tokens.error.withValues(alpha: 0.08)
          : context.tokens.onSurface.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Status indicator
            if (isConnecting)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (hasError)
              SizedBox(
                width: 16,
                height: 16,
                child: Icon(Icons.error_rounded,
                    size: 16, color: context.tokens.error),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.tokens.success,
                ),
              ),
            SizedBox(width: 14),
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
                        color: hasError ? context.tokens.error : context.tokens.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    device.id,
                    style: TextStyle(
                      fontSize: 9,
                      color: context.tokens.onSurface.withValues(alpha: 0.38),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    isConnecting
                        ? 'Connecting...'
                        : hasError
                            ? errorMessage!
                            : 'READY TO PAIR',
                    style: TextStyle(
                      color: hasError
                          ? context.tokens.error
                          : isConnecting
                              ? context.tokens.primary
                              : context.tokens.onSurface.withValues(alpha: 0.38),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            // Baud rate selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: context.tokens.onSurface.withValues(alpha: 0.05),
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
                        style: GoogleFonts.martianMono(
                            color: context.tokens.onSurface.withValues(alpha: 0.54),
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    Icon(Icons.arrow_drop_down_rounded,
                        size: 16, color: context.tokens.onSurface.withValues(alpha: 0.38)),
                  ],
                ),
                itemBuilder: (ctx) => _baudRates
                    .map((rate) => PopupMenuItem(
                          value: rate,
                          child: Text(rate,
                              style: GoogleFonts.martianMono(
                                  fontSize: 12, color: context.tokens.onSurface)),
                        ))
                    .toList(),
              ),
            ),
            SizedBox(width: 8),
            // Connect button
            SizedBox(
              height: 32,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.tokens.primary,
                  foregroundColor: context.tokens.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: hasError ? onRetry : onConnect,
                child: Text(hasError ? 'RETRY' : 'CONNECT',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700, fontSize: 11, height: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
