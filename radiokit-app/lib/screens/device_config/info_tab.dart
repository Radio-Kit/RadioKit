import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/device_provider.dart';
import '../../providers/history_provider.dart';
import '../../models/device_info.dart';
import '../../theme/app_theme.dart';

class InfoTabContent extends StatefulWidget {
  final DeviceInfo device;
  final DeviceProvider? deviceProvider;
  final Map<String, dynamic>? bleInfo;
  final bool loadingBleInfo;

  const InfoTabContent({
    required this.device,
    this.deviceProvider,
    required this.bleInfo,
    required this.loadingBleInfo,
  });

  @override
  State<InfoTabContent> createState() => _InfoTabContentState();
}

class _InfoTabContentState extends State<InfoTabContent> {
  /// Status message shown below transport badges during a transport switch.
  /// null = no switch in progress.
  String? _transportSwitchMessage;

  /// NVS transport enable states (null = not yet loaded).
  bool _nvsBleOn = true;
  bool _nvsWifiOn = false;
  bool _nvsCloudOn = false;
  bool _nvsLoading = true;

  /// Flag to avoid repeatedly scheduling auto-close pop on disconnect.
  bool _sheetAutoClosed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNvsStates());
  }

  Future<void> _loadNvsStates() async {
    final dp = widget.deviceProvider ?? context.read<DeviceProvider>();
    if (!dp.isConnected) {
      if (mounted) setState(() => _nvsLoading = false);
      return;
    }
    final bleResult = await dp.readNvsRawKey('rk_ble_on');
    final wifiResult = await dp.readNvsRawKey('rk_wifi_on');
    final cloudResult = await dp.readNvsRawKey('rk_cloud_on');
    if (!mounted) return;
    setState(() {
      _nvsBleOn = (bleResult.value ?? 1) != 0;
      _nvsWifiOn = (wifiResult.value ?? 0) != 0;
      _nvsCloudOn = (cloudResult.value ?? 0) != 0;
      _nvsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final dp = widget.deviceProvider ?? context.watch<DeviceProvider>();

    // Close the sheet when device disconnects (fire once per disconnect)
    if (!dp.isConnected && !_sheetAutoClosed) {
      _sheetAutoClosed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Dismiss any open dialogs first (they're on the root navigator)
          Navigator.of(context, rootNavigator: true).maybePop();
          // Then close the bottom sheet
          Navigator.of(context).maybePop();
        }
      });
    }
    // Reset flag if device reconnects (unlikely in this flow, but safe)
    if (dp.isConnected && _sheetAutoClosed) {
      _sheetAutoClosed = false;
    }

    final chipInfo = dp.chipInfo;
    final isDemo = device.currentTransport == TransportType.demo;

    // Determine transport states from actual current transport.
    // cloud uses WebSocketService (same as WiFi), so distinguish via
    // the DeviceInfo's currentTransport field.
    final isConnected = dp.isConnected;
    final connectedDeviceInfo = dp.connectedDevice;
    final connectedTransport = connectedDeviceInfo?.currentTransport;
    final isBleConnected = connectedTransport == TransportType.ble;
    final isWifiConnected = connectedTransport == TransportType.wifi;
    final isCloudConnected = connectedTransport == TransportType.cloud;

    final hasBle = dp.hasBle;
    final hasWifi = dp.hasWifi;
    final hasCloud = dp.hasCloud;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName.toUpperCase(),
                        style: GoogleFonts.exo2(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: context.tokens.onSurface)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: context.tokens.success,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        transportLabel(connectedTransport),
                        style: TextStyle(
                            color: context.tokens.onSurface.withValues(alpha: 0.54),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (isBleConnected && widget.loadingBleInfo)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Fetching connection info...',
                  style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11)),
            )
          else ...[
            const SizedBox(height: 12),
            // Transport-aware connection info
            if (isBleConnected) ...[
              Text(
                'Connection: ${widget.bleInfo?['connIntervalMs'] ?? dp.latencyMs ?? '--'}ms '
                '| MTU: ${widget.bleInfo?['negotiatedMtu'] ?? '--'}'
                ' | Signal: ${widget.bleInfo?['rssi'] ?? dp.rssi ?? device.rssi ?? '--'} dBm',
                style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11),
              ),
            ] else if (isWifiConnected || isCloudConnected) ...[
              Text(
                'Latency: ${dp.latencyMs ?? '--'}ms'
                ' | Signal: ${dp.rssi ?? device.rssi ?? '--'} dBm',
                style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11),
              ),
            ],
          ],
          const SizedBox(height: 16),
          // ── Transport Badges ────────────────────────────────
          // Only show badges for transports enabled via NVS on the ESP32
          if (_nvsLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else ...[
            Row(
              children: [
                // BLE badge — always show if NVS-enabled or currently connected via BLE
                if (_nvsBleOn || isBleConnected)
                  TransportBadge(
                    type: 'BLE',
                    icon: Icons.bluetooth_rounded,
                    connected: isConnected && isBleConnected,
                    available: true,
                    rssi: (isConnected && isBleConnected) ? (dp.rssi ?? device.rssi) : null,
                    onTap: isConnected && !isBleConnected
                        ? () => _onTransportTap(context, dp, device, TransportType.ble)
                        : null,
                  ),
                if (_nvsBleOn || isBleConnected) const SizedBox(width: 8),
                // WiFi badge — always show if connected via WiFi; otherwise show if NVS-enabled and device has WiFi
                if ((_nvsWifiOn && (hasWifi || isWifiConnected)) || isWifiConnected)
                  TransportBadge(
                    type: 'WiFi',
                    icon: Icons.wifi_rounded,
                    connected: isConnected && isWifiConnected,
                    available: hasWifi || isWifiConnected,
                    rssi: (isConnected && isWifiConnected) ? (dp.rssi ?? device.rssi) : null,
                    onTap: hasWifi && isConnected && !isWifiConnected
                        ? () => _onTransportTap(context, dp, device, TransportType.wifi)
                        : null,
                  ),
                if (((_nvsWifiOn && (hasWifi || isWifiConnected)) || isWifiConnected)) const SizedBox(width: 8),
                // Cloud badge — always show if connected via Cloud; otherwise show if NVS-enabled and device has Cloud
                if ((_nvsCloudOn && (hasCloud || isCloudConnected)) || isCloudConnected)
                  TransportBadge(
                    type: 'Cloud',
                    icon: Icons.cloud_rounded,
                    connected: isConnected && isCloudConnected,
                    available: hasCloud || isCloudConnected,
                    rssi: null,
                    onTap: hasCloud && isConnected && !isCloudConnected
                        ? () => _onTransportTap(context, dp, device, TransportType.cloud)
                        : null,
                  ),
              ],
            ),
          ],
          // ── Transport Switch Progress ────────────────────────
          if (_transportSwitchMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.tokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: context.tokens.warning.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.tokens.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _transportSwitchMessage!,
                      style: TextStyle(
                        color: context.tokens.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16),
          Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 24),
          // ── Chip Info ───────────────────────────────────────
          Text('CHIP INFO',
              style: TextStyle(
                  color: context.tokens.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 12),
          if (isDemo)
            ..._chipFields({
              'Chip Model': '--',
              'Revision': '--',
              'Cores': '--',
              'Flash Size': '--',
              'PSRAM Size': '--',
              'SDK Version': '--',
              'Chip ID (MAC)': '--',
            })
          else if (chipInfo == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.tokens.primary)),
                SizedBox(width: 12),
                Text('Fetching chip info...',
                    style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 12)),
              ]),
            )
          else
            ..._chipFields({
              'Chip Model': chipInfo['chipModel'] ?? '--',
              'Revision': chipInfo['chipRevision'] != null
                  ? 'v${chipInfo['chipRevision']}'
                  : '--',
              'Cores': chipInfo['chipCores'] != null
                  ? '${chipInfo['chipCores']}'
                  : '--',
              'Flash Size': _fmtBytes(chipInfo['flashSize']),
              'PSRAM Size': chipInfo['psramSize'] != null &&
                      (chipInfo['psramSize'] as int) > 0
                  ? _fmtBytes(chipInfo['psramSize'])
                  : 'None',
              'SDK Version': chipInfo['sdkVersion'] ?? '--',
              'Chip ID (MAC)': chipInfo['chipId'] ?? '--',
            }),
          SizedBox(height: 24),
          Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 24),
          // ── Device Action Buttons ────────────────────────────
          if (!isDemo) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.tokens.error,
                  side: BorderSide(
                      color: context.tokens.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text('REMOVE DEVICE',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 14,
                        height: 1)),
                onPressed: () => confirmRemoveDevice(context, device, dp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onTransportTap(BuildContext context, DeviceProvider dp, DeviceInfo device, TransportType targetTransport) async {
    // Determine current transport label for dialog message
    final connectedInfo = dp.connectedDevice;
    final currentTransport = connectedInfo?.currentTransport;
    String currentLabel;
    switch (currentTransport) {
      case TransportType.ble:
        currentLabel = 'BLE';
        break;
      case TransportType.wifi:
        currentLabel = 'WiFi';
        break;
      case TransportType.cloud:
        currentLabel = 'Cloud';
        break;
      case TransportType.serial:
        currentLabel = 'Serial';
        break;
      default:
        currentLabel = 'current';
    }

    String transportLabel(TransportType t) {
      switch (t) {
        case TransportType.ble:    return 'BLE';
        case TransportType.wifi:   return 'WiFi';
        case TransportType.cloud:  return 'Cloud';
        case TransportType.serial: return 'Serial';
        case TransportType.demo:   return 'Demo';
      }
    }

    final targetLabel = transportLabel(targetTransport);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.swap_horiz_rounded,
            color: context.tokens.primary, size: 32),
        title: Text('Switch to $targetLabel?'),
        content: Text(
          'Connected via $currentLabel. Switching to $targetLabel '
          'connects the new transport first, then seamlessly disconnects '
          'the old one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.primary,
              foregroundColor: context.tokens.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('SWITCH TO $targetLabel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show transport switch progress below badges
    setState(() {
      if (targetTransport == TransportType.wifi) {
        _transportSwitchMessage = 'Getting WiFi info from device...';
      } else if (targetTransport == TransportType.ble) {
        _transportSwitchMessage = 'Connecting via BLE...';
      } else {
        _transportSwitchMessage = 'Connecting via $targetLabel...';
      }
    });

    // Delegate transport switch to DeviceProvider
    final success = await dp.switchTransport(targetTransport);
    if (!context.mounted) return;

    if (success) {
      setState(() {
        _transportSwitchMessage = 'Connected via $targetLabel \u2713';
      });
      // Show success briefly then clear
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _transportSwitchMessage = null);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected via $targetLabel'),
          backgroundColor: context.tokens.success,
        ),
      );
    } else {
      setState(() {
        _transportSwitchMessage =
            'Failed to switch to $targetLabel — staying on $currentLabel';
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _transportSwitchMessage = null);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to switch to $targetLabel — staying on $currentLabel'),
          backgroundColor: context.tokens.warning,
        ),
      );
    }
    // Note: sheet stays open so the user sees the transport switch result.
    // They can close it manually via drag handle or by tapping elsewhere.
  }

  List<Widget> _chipFields(Map<String, String> fields) {
    return fields.entries
        .map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key,
                      style:
                          TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                  Text(e.value,
                      style: GoogleFonts.martianMono(
                          color: context.tokens.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ))
        .toList();
  }

  String _fmtBytes(dynamic value) {
    if (value == null || value == 0) return '--';
    final bytes = value is int ? value : int.tryParse(value.toString()) ?? 0;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

// ── Settings Tab Content ─────────────────────────────────────────────────────

class TransportBadge extends StatelessWidget {
  final String type;
  final IconData icon;
  final bool connected;
  final bool available;
  final int? rssi;
  final VoidCallback? onTap;

  const TransportBadge({
    required this.type,
    required this.icon,
    required this.connected,
    required this.available,
    this.rssi,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: connected
              ? context.tokens.success.withValues(alpha: 0.15)
              : available
                  ? context.tokens.onSurface.withValues(alpha: 0.05)
                  : context.tokens.onSurface.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: connected
                ? context.tokens.success.withValues(alpha: 0.3)
                : available
                    ? context.tokens.onSurface.withValues(alpha: 0.12)
                    : context.tokens.onSurface.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green/gray dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: connected
                    ? context.tokens.success
                    : available
                        ? context.tokens.onSurface.withValues(alpha: 0.38)
                        : context.tokens.onSurface.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon,
                size: 14,
                color: connected
                    ? context.tokens.onSurface
                    : available
                        ? context.tokens.onSurface.withValues(alpha: 0.54)
                        : context.tokens.onSurface.withValues(alpha: 0.15)),
            const SizedBox(width: 4),
            Text(type.toUpperCase(),
                style: TextStyle(
                    color: connected
                        ? context.tokens.onSurface
                        : available
                            ? context.tokens.onSurface.withValues(alpha: 0.54)
                            : context.tokens.onSurface.withValues(alpha: 0.15),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            if (rssi != null) ...[
              const SizedBox(width: 4),
              Text('${rssi}dBm',
                  style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.5),
                      fontSize: 8,
                      fontFamily: 'monospace')),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz_rounded,
                  size: 12,
                  color: context.tokens.primary.withValues(alpha: 0.6)),
            ],
          ],
        ),
      ),
    );
  }
}
Future<void> confirmRemoveDevice(
    BuildContext context, DeviceInfo device, DeviceProvider dp) async {
  final history = context.read<HistoryProvider>();
  final deviceId = device.id;
  final deviceName = device.displayName;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon:
          Icon(Icons.warning_rounded, color: context.tokens.error, size: 32),
      title:
          Text('Remove Device?', style: TextStyle(color: context.tokens.onSurface)),
      content: Text('Disconnect and remove "$deviceName" from paired devices.',
          style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54))),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: context.tokens.error.withValues(alpha: 0.2),
            foregroundColor: context.tokens.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('REMOVE'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await dp.disconnect();
  history.removeDevice(deviceId);

  if (context.mounted) {
    Navigator.of(context).maybePop();
  }
}

// ── Shared bottom widgets ───────────────────────────────────────────────────

/// Returns a human-readable transport label for the given device ID.
String transportLabel(TransportType? transport) {
  switch (transport) {
    case TransportType.ble:
      return 'BLUETOOTH LE';
    case TransportType.wifi:
      return 'WiFi';
    case TransportType.cloud:
      return 'CLOUD';
    case TransportType.serial:
      return 'SERIAL';
    case TransportType.demo:
      return 'DEMO';
    default:
      return 'BLUETOOTH LE';
  }
}
