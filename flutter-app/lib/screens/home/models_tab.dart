import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/device_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/serial_provider.dart';
import '../../providers/console_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../models/console_entry.dart';
import '../../widgets/console_log_view.dart';
import '../../models/device_info.dart';
import '../../models/fs_entry.dart';
import '../../models/fs_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../services/device_fs_service.dart';
import '../devtools/filesystem/fs_helpers.dart';
import '../devtools/filesystem/fs_breadcrumbs.dart';
import '../devtools/filesystem/fs_file_tile.dart';
import '../devtools/filesystem/fs_info_strip.dart';
import '../devtools/filesystem/fs_action_sheet.dart';
import '../devtools/filesystem/file_editor_cache.dart';
import '../devtools/filesystem/file_editor_dialog.dart';
import '../../widgets/device_settings_dialog.dart';
import '../../widgets/model_card.dart';

class ModelsTab extends StatelessWidget {
  const ModelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const breakpoint = 600;
    final useWideLayout = screenWidth > breakpoint;

    return Scaffold(
      appBar: RadioKitAppBar(
        actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange.withValues(alpha: 0.15),
              foregroundColor: AppColors.brandOrange,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => _showPairBottomSheet(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: AppColors.brandOrange),
                const SizedBox(width: 6),
                Text('+ Connect',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 13,
                        color: AppColors.brandOrange)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: useWideLayout
          ? _buildLandscapeBody(context)
          : _buildPortraitBody(context),
    );
  }

  Widget _buildPortraitBody(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 12),
        _ActiveLinkSection(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PairedModelsList(),
        ),
        const SizedBox(height: 32),
        Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            if (!settings.showDemo) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSectionTag(context, 'INTERACTIVE_DEMO'),
                  _InteractiveDemoSection(),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLandscapeBody(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 12),
        _ActiveLinkSection(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PairedModelsList(),
        ),
        const SizedBox(height: 32),
        Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            if (!settings.showDemo) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSectionTag(context, 'INTERACTIVE_DEMO'),
                  _InteractiveDemoSection(),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Returns the active link card layout — stacks transport info on the right
/// side above the telemetry divider.
Widget _buildActiveLinkCard(
    BuildContext context, DeviceProvider dp, DeviceInfo device) {
  final transportType = device.id.startsWith('demo_')
      ? 'DEMO'
      : device.id.startsWith('COM') || device.id.contains('serial')
          ? 'USB'
          : 'BLE';
  final transportIcon = device.id.startsWith('demo_')
      ? Icons.wifi_tethering_rounded
      : device.id.startsWith('COM') || device.id.contains('serial')
          ? Icons.usb_rounded
          : Icons.bluetooth_rounded;
  final latencyMs = dp.latencyMs;
  final signal = dp.rssi ?? device.rssi;
  final description = dp.description;

  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 200),
    child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Responsive scaling based on available width
          final isNarrow = width < 400;
          final paddingSize = (width / 15).clamp(8.0, 16.0);
          final nameFontSize = (width / 14).clamp(16.0, 26.0);
          final actionGap = (width / 15).clamp(12.0, 24.0);
          final iconSize = isNarrow ? 28.0 : 36.0;
          final iconContainerPad = isNarrow ? 6.0 : 10.0;
          final gapIconName = isNarrow ? 8.0 : 12.0;

          return Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.white.withValues(alpha: 0.05),
        child: Padding(
              padding: EdgeInsets.all(paddingSize),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header row: info + icon ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Connection info + name + description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Connection info row
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(transportIcon,
                                      size: isNarrow ? 10 : 12,
                                      color: AppColors.connected),
                                  const SizedBox(width: 4),
                                  Text(transportType,
                                      style: GoogleFonts.inter(
                                          color: AppColors.connected,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isNarrow ? 10 : 12,
                                          letterSpacing: 1.2)),
                                  if (latencyMs != null) ...[
                                    const SizedBox(width: 10),
                                    Icon(Icons.timer_outlined,
                                        size: 9,
                                        color: AppColors.connected.withValues(alpha: 0.6)),
                                    const SizedBox(width: 2),
                                    Text('${latencyMs}ms',
                                        style: GoogleFonts.jetBrainsMono(
                                            color: AppColors.connected.withValues(alpha: 0.8),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                  const SizedBox(width: 10),
                                  Icon(Icons.signal_cellular_alt_rounded,
                                      size: 9,
                                      color: AppColors.connected.withValues(alpha: 0.6)),
                                  const SizedBox(width: 2),
                                  Text('${signal} dBm',
                                      style: GoogleFonts.jetBrainsMono(
                                          color: AppColors.connected.withValues(alpha: 0.8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Device name (single line, scale down)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(device.displayName.toUpperCase(),
                                  style: GoogleFonts.exo2(
                                      fontSize: nameFontSize,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5)),
                            ),
                            const SizedBox(height: 1),
                            // Description (truncated)
                            Text(
                              description?.isNotEmpty == true
                                  ? description!.toUpperCase()
                                  : 'NO_DESCRIPTION',
                              style: TextStyle(
                                  color: AppColors.brandOrange.withValues(alpha: 0.7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: gapIconName),
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(4),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.local_shipping_rounded,
                            color: AppColors.brandOrange, size: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Telemetry ──────────────────────────────────────────
                  _buildActiveLinkTelemetry(dp, device),
                  SizedBox(height: actionGap),
                  // ── Action row ─────────────────────────────────────────
                  _buildActiveLinkActions(context, dp, device),
                ],
              ),
            ),
        );
      },
    ),
  );
}

// ── Active Link Section ──────────────────────────────────────────────────────

class _ActiveLinkSection extends StatefulWidget {
  @override
  State<_ActiveLinkSection> createState() => _ActiveLinkSectionState();
}

class _ActiveLinkSectionState extends State<_ActiveLinkSection> {
  bool _authDialogShown = false;

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final useWide = MediaQuery.of(context).size.width > 600;
    final isConnected = deviceProvider.isConnected;

    if (!isConnected) {
      // Reset flag when disconnected so it can re-trigger on next connection
      if (_authDialogShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _authDialogShown = false);
        });
      }
      return const SizedBox.shrink();
    }

    final device = deviceProvider.connectedDevice!;
    final needAuth = deviceProvider.hasPassword && !deviceProvider.isAuthenticated;

    // If auth is needed and dialog hasn't been shown yet, trigger it
    if (needAuth && !_authDialogShown) {
      _authDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        
        // Try auto-auth with saved password first
        final saved = await SecureStorageService.loadPassword(device.id);
        if (saved != null && saved.isNotEmpty) {
          final ok = await context.read<DeviceProvider>().authenticate(saved);
          if (ok && mounted) return; // Auto-authenticated — no dialog needed
        }
        
        if (!mounted) return;
        final ok = await _showAuthDialog(context, device);
        if (!mounted) return;
        if (!ok) {
          // Defer disconnect to next frame to allow dialog route
          // elements (e.g. _AuthCountdown watching DeviceProvider)
          // to fully dispose before notifyListeners fires.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) deviceProvider.disconnect();
          });
        }
      });
    }

    // Don't show anything if auth is needed (dialog handles it)
    if (needAuth) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTag(context, 'ACTIVE_LINKS'),
        if (useWide)
          _buildLandscapeActiveLink(context, deviceProvider, device)
        else
          _buildActiveLinkCard(context, deviceProvider, device),
      ],
    );
  }

  Widget _buildLandscapeActiveLink(
      BuildContext context, DeviceProvider dp, DeviceInfo device) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildActiveLinkCard(context, dp, device),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

}

// ── Active link helpers ──────────────────────────────────────────────────────

void _showDeviceInfoSheet(
    BuildContext context, DeviceProvider dp, DeviceInfo device) {
  dp.requestChipInfo();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => _DeviceInfoTabs(device: device),
  );
}

Widget _buildActiveLinkTelemetry(DeviceProvider dp, DeviceInfo device) {
  // User telemetry placeholders — replace with live data from the device
  final battery = 85;
  final speed = 42;
  final temp = 23;

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Flexible(child: _TelemetryItem(label: 'BATTERY', value: '$battery', unit: '%')),
      Flexible(child: _TelemetryItem(label: 'SPEED', value: '$speed', unit: 'km/h')),
      Flexible(child: _TelemetryItem(label: 'TEMP', value: '$temp', unit: '°C')),
    ],
  );
}

Widget _buildActiveLinkActions(
    BuildContext context, DeviceProvider dp, DeviceInfo device) {
  const buttonHeight = 52.0;
  const borderRadius = 6.0;

  return Row(
    children: [
      _ActiveLinkButton(
        icon: Icons.tune_rounded,
        onTap: () => _showDeviceInfoSheet(context, dp, device),
        height: buttonHeight,
        borderRadius: borderRadius,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ActiveLinkButton(
          label: 'OPEN_CONTROLLER',
          shortLabel: 'OPEN',
          icon: Icons.gamepad_rounded,
          onTap: () => context.go('/control'),
          height: buttonHeight,
          borderRadius: borderRadius,
        ),
      ),
      const SizedBox(width: 8),
      _ActiveLinkButton(
        icon: Icons.link_off_rounded,
        onTap: () => dp.disconnect(),
        height: buttonHeight,
        borderRadius: borderRadius,
      ),
    ],
  );
}

class _ActiveLinkButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String? shortLabel;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;

  const _ActiveLinkButton({
    this.icon,
    this.label,
    this.shortLabel,
    required this.onTap,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDisconnect = icon == Icons.link_off_rounded;
    return SizedBox(
      height: height,
      width: icon != null && label == null ? height : null,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              isDisconnect ? Colors.redAccent : AppColors.brandOrange,
          foregroundColor: isDisconnect ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: icon != null && label != null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final showShort = constraints.maxWidth < 180;
                  final displayLabel = showShort ? (shortLabel ?? label) : label;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(displayLabel ?? '',
                          style: GoogleFonts.changa(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                              fontSize: 20,
                              color: isDisconnect ? Colors.white : Colors.black)),
                      if (showShort) ...[
                        const SizedBox(width: 6),
                        Icon(icon, size: 26),
                      ],
                    ],
                  );
                },
              )
            : icon != null
                ? Icon(icon, size: 28)
                : Text(label ?? '',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 20,
                        color: isDisconnect ? Colors.white : Colors.black)),
      ),
    );
  }
}

// ── Device Info Tabs Sheet ───────────────────────────────────────────────────

class _DeviceInfoTabs extends StatefulWidget {
  final DeviceInfo device;
  const _DeviceInfoTabs({required this.device});

  @override
  State<_DeviceInfoTabs> createState() => _DeviceInfoTabsState();
}

class _DeviceInfoTabsState extends State<_DeviceInfoTabs>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _bleInfo;
  bool _loadingBleInfo = true;
  TabController? _tabController;
  int _tabCount = 0;

  @override
  void initState() {
    super.initState();
    _initTabs();
    _fetchBleInfo();
  }

  void _initTabs() {
    final dp = context.read<DeviceProvider>();
    final isUserMode = dp.isUserMode;
    final hasFs = widget.device.hasFs;
    final hasOta = dp.hasOta;
    _tabCount = 1; // Info always present
    // Hide FS/OTA tabs in user mode — admin required
    if (hasFs && !isUserMode) _tabCount++;
    if (hasOta && !isUserMode) _tabCount++;
    if (_tabCount > 1) {
      _tabController = TabController(length: _tabCount, vsync: this);
    }
  }

  Future<void> _fetchBleInfo() async {
    final dp = context.read<DeviceProvider>();
    final info = await dp.sendGetBleInfo();
    if (mounted) {
      setState(() => _bleInfo = info);
      _loadingBleInfo = false;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final device = widget.device;
    final hasFs = device.hasFs;
    final hasOta = dp.hasOta;
    final showTabs = hasFs || hasOta;

    final isUserMode = dp.isUserMode;
    
    if (!showTabs || isUserMode) {
      // Only Info when in user mode (or no FS/OTA at all)
      return _InfoTabContent(
        device: device,
        bleInfo: _bleInfo,
        loadingBleInfo: _loadingBleInfo,
      );
    }

    // Build tabs list (admin mode — show all available tabs)
    final tabs = <Tab>[];
    final tabWidgets = <Widget>[];

    tabs.add(const Tab(text: 'INFO'));
    tabWidgets.add(_InfoTabContent(
      device: device,
      bleInfo: _bleInfo,
      loadingBleInfo: _loadingBleInfo,
    ));

    if (hasFs) {
      tabs.add(const Tab(text: 'FILESYSTEM'));
      tabWidgets.add(_FsTabContent());
    }

    if (hasOta) {
      tabs.add(const Tab(text: 'FIRMWARE'));
      tabWidgets.add(_FirmwareTabContent(
        device: device,
      ));
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController!,
            indicatorColor: AppColors.brandOrange,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
            tabs: tabs,
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: tabWidgets,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Tab Content ─────────────────────────────────────────────────────────

class _InfoTabContent extends StatelessWidget {
  final DeviceInfo device;
  final Map<String, dynamic>? bleInfo;
  final bool loadingBleInfo;

  const _InfoTabContent({
    required this.device,
    required this.bleInfo,
    required this.loadingBleInfo,
  });

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final chipInfo = dp.chipInfo;
    final isDemo = device.id.startsWith('demo_');

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
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.connected,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        device.id.startsWith('demo_')
                            ? 'DEMO'
                            : device.id.startsWith('COM') ||
                                    device.id.contains('serial')
                                ? 'SERIAL'
                                : 'BLE',
                        style: const TextStyle(
                            color: Colors.white54,
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
          if (loadingBleInfo)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Fetching connection info...',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            )
          else ...[
            const SizedBox(height: 12),
            Text(
              'Connection: ${bleInfo?['connIntervalMs'] ?? dp.latencyMs ?? '--'}ms '
              '| MTU: ${bleInfo?['negotiatedMtu'] ?? '--'}'
              ' | Signal: ${bleInfo?['rssi'] ?? dp.rssi ?? device.rssi ?? '--'} dBm',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 24),
          // ── Device Action Buttons ────────────────────────────
          if (!isDemo) ...[
            Row(
              children: [
                // Device Settings button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.brandOrange.withValues(alpha: 0.15),
                        foregroundColor: AppColors.brandOrange,
                        side: BorderSide(
                          color: AppColors.brandOrange.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text('DEVICE',
                          style: GoogleFonts.changa(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              fontSize: 12)),
                      onPressed: () => DeviceSettingsDialog.show(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Remove device button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('REMOVE DEVICE',
                          style: GoogleFonts.changa(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              fontSize: 12)),
                      onPressed: () =>
                        _confirmRemoveDevice(context, device, dp),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 24),
          // ── Chip Info ───────────────────────────────────────
          Text('CHIP INFO',
              style: TextStyle(
                  color: AppColors.brandOrange,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brandOrange)),
                SizedBox(width: 12),
                Text('Fetching chip info...',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
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
        ],
      ),
    );
  }

  List<Widget> _chipFields(Map<String, String> fields) {
    return fields.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.key,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(e.value,
                  style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        )).toList();
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

// ── Filesystem Tab Content ───────────────────────────────────────────────────

class _FsTabContent extends StatefulWidget {
  @override
  State<_FsTabContent> createState() => _FsTabContentState();
}

class _FsTabContentState extends State<_FsTabContent> {
  final FileEditorCache _editorCache = FileEditorCache();
  DeviceFsService? _fs;
  List<FsEntry> _entries = [];
  FsInfo? _fsInfo;
  String _currentPath = '/';
  bool _loading = false;
  bool _initTriggered = false;
  String? _statusMessage;
  String? _errorMessage;
  double? _progress;
  DateTime? _transferStartTime;
  int _currentTransferBytes = 0;
  bool _isMultiSelect = false;
  final Set<String> _selectedPaths = {};
  final Set<String> _loadingPaths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFs());
  }

  void _initFs() {
    if (!mounted || _initTriggered) return;
    final dp = context.read<DeviceProvider>();
    if (!dp.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initFs());
      return;
    }
    _initTriggered = true;
    _fs = createDeviceFsService(dp);
    if (dp.fsCacheReady) {
      final cached = dp.fsTreeCache!['/']!;
      setState(() {
        _entries = cached;
        _statusMessage = '${cached.length} entries (cached)';
      });
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FsInfoStrip(
          info: _fsInfo,
          loading: _loading && _fsInfo == null,
          speedBytesPerSec: _transferStartTime != null &&
                  _transferStartTime != null
              ? _currentTransferBytes /
                  (DateTime.now()
                          .difference(_transferStartTime!)
                          .inMilliseconds /
                      1000.0)
              : null,
        ),
        FsBreadcrumbs(
          currentPath: _currentPath,
          onJumpTo: (idx) {
            final segs = ['/', ...pathSegments(_currentPath)];
            _navigateTo(idx == 0 ? '/' : segs.take(idx + 1).join('/'));
          },
        ),
        const Divider(height: 1),
        Expanded(child: _buildList()),
        if (_statusMessage != null || _errorMessage != null || _progress != null)
          _buildStatusBar(),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Listing files…'),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.folder_open_rounded, size: 64,
                color: Colors.white38),
            const SizedBox(height: 16),
            const Center(
                child: Text('Empty directory',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Upload or create'),
                onPressed: _showUploadMenu,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = List<FsEntry>.from(_entries);
    sorted.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, i) {
                final entry = sorted[i];
                final path = joinPath(_currentPath, entry.name);
                return FsFileTile(
                  entry: entry,
                  fullPath: path,
                  isSelected: _selectedPaths.contains(path),
                  isMultiSelect: _isMultiSelect,
                  onTap: () => _onTileTap(entry, path),
                  onLongPress: () => _onTileLongPress(entry, path),
                  onSecondaryAction: () => _openActionSheet(entry, path),
                  onEdit: isEditableFile(entry.name)
                      ? () => _editFile(entry, path)
                      : null,
                  isLoading: _loadingPaths.contains(path),
                );
              },
            ),
          ),
        ),
        // Upload / Create FAB row
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isMultiSelect)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedPaths.clear();
                          _isMultiSelect = false;
                        });
                      },
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.select_all_rounded,
                      tooltip: 'Select all',
                      onPressed: _selectedPaths.length == _entries.length
                          ? _deselectAll
                          : _selectAll,
                    ),
                    const SizedBox(width: 4),
                    _actionButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete selected',
                      onPressed:
                          _selectedPaths.isEmpty ? null : _deleteSelected,
                    ),
                  ],
                )
              else ...[
                _actionButton(
                  icon: Icons.create_new_folder_outlined,
                  tooltip: 'New folder',
                  onPressed: _createFolder,
                ),
                const SizedBox(width: 8),
                _actionButton(
                  icon: Icons.upload_file_rounded,
                  tooltip: 'Upload file',
                  onPressed: () => _uploadFile(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: AppColors.brandOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(icon, color: AppColors.brandOrange, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final hasError = _errorMessage != null;
    final color = hasError ? Colors.redAccent : Colors.white54;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: const Color(0xFF252525),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(children: [
            Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage ?? _statusMessage ?? '',
                style: TextStyle(color: color, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasError)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _errorMessage = null),
              ),
          ]),
        ],
      ),
    );
  }

  // ── FS Operations ────────────────────────────────────────────────────

  void _showUploadMenu() {
    showModalBottomSheet<_NewChoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Upload file'),
              subtitle: const Text('Pick a file from this device'),
              onTap: () => Navigator.of(ctx).pop(_NewChoice.upload),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              subtitle: const Text('Create a directory here'),
              onTap: () => Navigator.of(ctx).pop(_NewChoice.mkdir),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((choice) {
      switch (choice) {
        case _NewChoice.upload: _uploadFile(); break;
        case _NewChoice.mkdir: _createFolder(); break;
        default: break;
      }
    });
  }

  void _onTileTap(FsEntry entry, String path) {
    HapticFeedback.selectionClick();
    if (_isMultiSelect) {
      setState(() {
        if (_selectedPaths.contains(path)) {
          _selectedPaths.remove(path);
        } else {
          _selectedPaths.add(path);
        }
      });
      return;
    }
    if (entry.isDirectory) {
      _navigateTo(path);
    } else {
      _openActionSheet(entry, path);
    }
  }

  void _onTileLongPress(FsEntry entry, String path) {
    HapticFeedback.mediumImpact();
    if (_isMultiSelect) {
      _onTileTap(entry, path);
    } else {
      setState(() {
        _isMultiSelect = true;
        _selectedPaths.add(path);
      });
    }
  }

  Future<void> _openActionSheet(FsEntry entry, String path) async {
    if (_isMultiSelect) {
      _onTileTap(entry, path);
      return;
    }
    final action = await FsActionSheet.show(context,
        entry: entry, fullPath: path);
    if (!mounted || action == null) return;
    switch (action) {
      case FsAction.edit:
        await _editFile(entry, path);
        break;
      case FsAction.download:
        await _downloadFile(entry, path);
        break;
      case FsAction.rename:
        await _renameEntry(path);
        break;
      case FsAction.copyPath:
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Copied: $path')));
        }
        break;
      case FsAction.info:
        _showInfoDialog(entry, path);
        break;
      case FsAction.delete:
        await _deleteEntry(entry, path);
        break;
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path == '' ? '/' : path;
      _entries = [];
      _selectedPaths.clear();
    });
    _refresh();
  }

  Future<void> _refresh() async {
    if (_fs == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = 'Listing $_currentPath…';
    });
    try {
      final entries = await _fs!.listDir(_currentPath);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _statusMessage = '${entries.length} entries';
      });
      unawaited(_fetchInfo());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'List error: $e';
        _statusMessage = null;
      });
    }
  }

  Future<void> _fetchInfo() async {
    if (_fs == null) return;
    try {
      final info = await _fs!.getInfo();
      if (mounted) setState(() => _fsInfo = info);
    } catch (_) {}
  }

  Future<void> _uploadFile() async {
    if (_fs == null) return;
    try {
      final picked = await pickUploadFile(context);
      if (picked == null || !mounted) return;
      final remotePath = joinPath(_currentPath, picked.name);
      _transferStartTime = DateTime.now();
      setState(() {
        _statusMessage = 'Uploading ${picked.name}…';
        _progress = 0;
      });
      final res = await _fs!.writeFile(remotePath, picked.bytes,
          onProgress: (w, t) {
        if (!mounted) return;
        setState(() {
          _currentTransferBytes = w;
          _progress = t == 0 ? null : w / t;
          _statusMessage =
              'Uploading ${picked.name}  ${formatBytes(w)} / ${formatBytes(t)}';
        });
      });
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      if (res.success) {
        setState(() {
          _statusMessage = 'Uploaded ${picked.name}';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Upload failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      setState(() {
        _errorMessage = 'Upload error: $e';
        _progress = null;
      });
    }
  }

  Future<void> _downloadFile(FsEntry entry, String path) async {
    if (_fs == null) return;
    _transferStartTime = DateTime.now();
    setState(() {
      _statusMessage = 'Reading ${entry.name}…';
      _progress = 0;
    });
    try {
      final bytes = await _fs!.readFile(path, onProgress: (r, t) {
        if (!mounted) return;
        setState(() {
          _currentTransferBytes = r;
          _progress = t == 0 ? null : r / t;
          _statusMessage =
              'Reading ${entry.name}  ${formatBytes(r)} / ${formatBytes(t)}';
        });
      });
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Download failed';
          _progress = null;
        });
        return;
      }
      final savePath = await promptSaveFile(context,
          fileName: entry.name, bytes: bytes);
      if (!mounted) return;
      setState(() {
        _statusMessage = savePath != null
            ? 'Saved ${entry.name} → $savePath'
            : 'Cancelled save';
        _progress = null;
      });
    } catch (e) {
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      setState(() {
        _errorMessage = 'Download error: $e';
        _progress = null;
      });
    }
  }

  Future<void> _deleteEntry(FsEntry entry, String path) async {
    if (_fs == null) return;
    final ok = await confirmDelete(context, entry);
    if (!ok || !mounted) return;
    setState(() {
      _statusMessage = 'Deleting ${entry.name}…';
      _progress = 0;
    });
    try {
      final res = await _fs!.delete(path, recursive: entry.isDirectory);
      if (!mounted) return;
      if (res.success) {
        setState(() {
          _statusMessage = 'Deleted ${entry.name}';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Delete failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Delete error: $e';
        _progress = null;
      });
    }
  }

  Future<void> _editFile(FsEntry entry, String path) async {
    if (_fs == null || !mounted) return;
    setState(() {
      _loadingPaths.add(path);
      _statusMessage = 'Opening ${entry.name}…';
      _progress = 0;
    });
    try {
      // Check cache first
      Uint8List? content = _editorCache.get(path);
      if (content != null) {
        final crc = await _fs!.getFileCrc32(path);
        if (crc != null && crc.found) {
          final valid = _editorCache.isValid(
            path,
            crc32: crc.crc32,
            size: crc.size,
          );
          if (valid != true) {
            content = null;
          }
        } else {
          content = null;
        }
      }

      setState(() {
        _loadingPaths.remove(path);
        _progress = null;
        _statusMessage = null;
      });

      final result = await FileEditorDialog.show(
        context,
        fs: _fs!,
        path: path,
        fileName: entry.name,
        cachedContent: content,
      );
      if (!mounted) return;
      if (result != null && result.saved && result.newContent != null) {
        final crc = await _fs!.getFileCrc32(path);
        if (crc != null && crc.found) {
          _editorCache.put(path, result.newContent!,
              crc32: crc.crc32, size: crc.size);
        } else {
          _editorCache.put(path, result.newContent!);
        }
        setState(() {
          _statusMessage = 'Saved ${entry.name}';
          _progress = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPaths.remove(path);
        _errorMessage = 'Edit error: $e';
        _progress = null;
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (_fs == null || _selectedPaths.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedPaths.length} items?'),
        content: const Text(
            'This will permanently delete the selected files and folders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final paths = _selectedPaths.toList();
    int okCount = 0, failCount = 0;
    setState(() {
      _statusMessage = 'Deleting ${paths.length} items…';
      _progress = 0;
    });
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      try {
        final res = await _fs!.delete(p, recursive: true);
        if (res.success) { okCount++; } else { failCount++; }
      } catch (_) { failCount++; }
      if (mounted) setState(() => _progress = (i + 1) / paths.length);
    }
    if (!mounted) return;
    _exitMultiSelect();
    setState(() {
      _statusMessage = failCount == 0
          ? 'Deleted $okCount items'
          : 'Deleted $okCount, $failCount failed';
      _progress = null;
    });
    await _refresh();
  }

  Future<void> _renameEntry(String oldPath) async {
    if (_fs == null) return;
    final newPath = await promptRename(context, oldPath);
    if (newPath == null || !mounted) return;
    setState(() {
      _statusMessage = 'Renaming…';
      _progress = 0;
    });
    try {
      final res = await _fs!.rename(oldPath, newPath);
      if (!mounted) return;
      if (res.success) {
        setState(() { _statusMessage = 'Renamed'; _progress = null; });
      } else {
        setState(() { _errorMessage = 'Rename failed: ${res.errorName}'; _statusMessage = null; _progress = null; });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'Rename error: $e'; _progress = null; });
    }
  }

  Future<void> _createFolder() async {
    if (_fs == null) return;
    final newPath = await promptNewFolder(context, _currentPath);
    if (newPath == null || !mounted) return;
    setState(() {
      _statusMessage = 'Creating folder…';
      _progress = 0;
    });
    try {
      final res = await _fs!.mkdir(newPath);
      if (!mounted) return;
      if (res.success) {
        setState(() { _statusMessage = 'Created folder'; _progress = null; });
      } else {
        setState(() { _errorMessage = 'Create failed: ${res.errorName}'; _statusMessage = null; _progress = null; });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'Create error: $e'; _progress = null; });
    }
  }

  void _selectAll() {
    setState(() {
      for (final e in _entries) {
        _selectedPaths.add(joinPath(_currentPath, e.name));
      }
    });
  }

  void _deselectAll() => setState(() => _selectedPaths.clear());
  void _exitMultiSelect() => setState(() { _isMultiSelect = false; _selectedPaths.clear(); });

  void _showInfoDialog(FsEntry entry, String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.name),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv('Type', entry.isDirectory ? 'Folder' : 'File'),
          _kv('Path', path),
          if (!entry.isDirectory) _kv('Size', formatBytes(entry.size)),
          if (!entry.isDirectory) _kv('Bytes', entry.size.toString()),
        ]),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 60,
              child: Text(k,
                  style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(
              child: SelectableText(v,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        ]),
      );
}

enum _NewChoice { upload, mkdir }

// ── Firmware Tab Content ─────────────────────────────────────────────────────

class _FirmwareTabContent extends StatefulWidget {
  final DeviceInfo device;

  const _FirmwareTabContent({required this.device});

  @override
  State<_FirmwareTabContent> createState() => _FirmwareTabContentState();
}

class _FirmwareTabContentState extends State<_FirmwareTabContent> {
  int _received = 0;
  int _total = 0;
  String _status = 'Ready';
  bool _uploading = false;
  bool _complete = false;
  bool _error = false;
  String? _errorMessage;
  DateTime? _started;
  bool _cancelled = false;

  // ── Confirm upload state ──────────────────────────────────────────
  String? _selectedFileName;
  Uint8List? _selectedFirmwareBytes;
  bool _eraseAll = false;

  Future<void> _selectFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected file.')),
        );
      }
      return;
    }

    Uint8List firmware;
    try {
      firmware = await File(file.path!).readAsBytes();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _status = 'Failed to read file';
          _errorMessage = '$e';
        });
      }
      return;
    }

    // Store file for confirm step instead of starting upload immediately
    setState(() {
      _selectedFileName = file.name;
      _selectedFirmwareBytes = firmware;
      _error = false;
      _errorMessage = null;
      _status = 'Ready';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFileName = null;
      _selectedFirmwareBytes = null;
      _eraseAll = false;
    });
  }

  Future<void> _confirmAndUpload() async {
    final firmware = _selectedFirmwareBytes;
    if (firmware == null) return;
    _startUpload(firmware);
  }

  Future<void> _startUpload(Uint8List firmware) async {
    final dp = context.read<DeviceProvider>();
    final eraseAll = _eraseAll;
    setState(() {
      _uploading = true;
      _complete = false;
      _error = false;
      _status = 'Initializing...';
      _received = 0;
      _total = firmware.length;
      _started = DateTime.now();
      _cancelled = false;
      _errorMessage = null;
      _selectedFileName = null;
      _selectedFirmwareBytes = null;
    });

    try {
      await dp.uploadFirmware(firmware, eraseAll: eraseAll, onProgress: (received, total) {
        if (!mounted || _cancelled) return;
        setState(() {
          _received = received;
          _total = total;
          _status = _formatSpeed(received, total);
        });
      });
      if (!mounted) return;
      setState(() {
        _status = 'Verifying...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _complete = true;
        _uploading = false;
        _status = 'Update complete — device rebooting...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _uploading = false;
        _status = 'Update failed';
        _errorMessage = 'Error: $e';
      });
    }
  }

  String _formatSpeed(int received, int total) {
    final elapsed = DateTime.now().difference(_started ?? DateTime.now());
    final ms = elapsed.inMilliseconds;
    final speed = ms > 0 ? (received / ms * 1000 / 1024).toStringAsFixed(1) : '0';
    final pct = total > 0 ? (received * 100 / total).toStringAsFixed(0) : '0';
    return 'Uploading... $pct% ($speed KB/s)';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  Future<void> _cancel() async {
    _cancelled = true;
    try {
      await context.read<DeviceProvider>().abortOta();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _uploading = false;
        _status = 'Cancelled';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final configName = dp.configName ?? 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Device info header ───────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.memory_rounded,
                  color: AppColors.brandOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(configName.toUpperCase(),
                      style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('FIRMWARE UPDATE',
                      style: TextStyle(
                          color: AppColors.brandOrange.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 24),

          // ── Firmware info ────────────────────────────────────
          _infoRow('DEVICE', configName),
          _infoRow('VERSION', dp.connectedDevice?.id ?? '--'),
          const SizedBox(height: 24),

          if (!_uploading && !_complete && !_error) ...[
            // ── Confirm upload phase (file selected) ────────────
            if (_selectedFileName != null && _selectedFirmwareBytes != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.brandOrange.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECTED FILE',
                        style: TextStyle(
                            color: AppColors.brandOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.insert_drive_file_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedFileName!,
                                style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                _formatBytes(
                                    _selectedFirmwareBytes!.length),
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white38),
                        onPressed: _clearSelection,
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Erase all toggle ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 18,
                        color: _eraseAll
                            ? Colors.redAccent
                            : Colors.white38),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ERASE ALL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text('Reset to factory defaults after reboot (NVS + filesystem)',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _eraseAll,
                      onChanged: (v) => setState(() => _eraseAll = v),
                      activeColor: Colors.redAccent,
                      activeThumbColor: Colors.redAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Confirm upload button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: Text('CONFIRM UPLOAD',
                      style: GoogleFonts.changa(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          fontSize: 12)),
                  onPressed: _confirmAndUpload,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ── Select file button (always visible when idle) ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.file_open_rounded, size: 20),
                label: Text('SELECT FIRMWARE FILE',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 12)),
                onPressed: _selectFile,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a compiled firmware (.bin) file to update the device.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],

          // ── Upload progress ──────────────────────────────────
          if (_uploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total > 0 ? _received / _total : null,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.brandOrange),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_status,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                Text('${(_received * 100 ~/ _total)}%',
                    style: GoogleFonts.jetBrainsMono(
                        color: AppColors.brandOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _cancel,
                child: const Text('CANCEL'),
              ),
            ),
          ],

          // ── Error state ──────────────────────────────────────
          if (_error) ...[
            Row(children: [
              const Icon(Icons.error_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_errorMessage ?? 'Unknown error',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandOrange,
                  side: BorderSide(
                      color: AppColors.brandOrange.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => setState(() {
                  _error = false;
                  _status = 'Ready';
                  _errorMessage = null;
                }),
                child: const Text('RETRY'),
              ),
            ),
          ],

          // ── Complete state ───────────────────────────────────
          if (_complete) ...[
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Device is rebooting with new firmware.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Shared Auth Dialog ─────────────────────────────────────────────────────

/// Shows a reusable authentication dialog for both connection (password gate)
/// and admin (admin upgrade) authentication.
/// 
/// [isAdminAuth]: false → connection auth via [DeviceProvider.authenticate],
///                 true  → admin auth via [DeviceProvider.authenticateAdmin].
/// Both modes support "Remember password" via [SecureStorageService].
/// Returns true if auth succeeded, false if cancelled or failed.
Future<bool> _showAuthDialog(
    BuildContext context, DeviceInfo device, {
  bool isAdminAuth = false,
}) async {
  final dp = context.read<DeviceProvider>();
  bool obscure = true;
  bool loading = false;
  bool remember = isAdminAuth ? false : true;
  String? error;
  String password = '';

  // Load saved password
  final saved = isAdminAuth
      ? await SecureStorageService.loadAdminPassword(device.id)
      : await SecureStorageService.loadPassword(device.id);
  if (saved != null && saved.isNotEmpty) {
    password = saved;
  }

  if (!context.mounted) return false;

  final success = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          // Shared submit handler
          Future<void> submit() async {
            if (loading) return;
            setDialogState(() {
              loading = true;
              error = null;
            });
            final pwd = password.trim();
            if (pwd.isEmpty) {
              setDialogState(() {
                loading = false;
                error = 'Please enter a password';
              });
              return;
            }
            final ok = isAdminAuth
                ? await dp.authenticateAdmin(pwd)
                : await dp.authenticate(pwd);
            if (!context.mounted) return;
            if (ok) {
              if (remember) {
                if (isAdminAuth) {
                  SecureStorageService.saveAdminPassword(device.id, pwd);
                } else {
                  SecureStorageService.savePassword(device.id, pwd);
                }
              }
              Navigator.of(ctx).pop(true);
            } else {
              setDialogState(() {
                loading = false;
                error = 'Incorrect password';
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(
                    isAdminAuth
                        ? Icons.admin_panel_settings_outlined
                        : Icons.lock_rounded,
                    color: AppColors.brandOrange,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      device.displayName.toUpperCase(),
                      style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isAdminAuth)
                    const _AuthCountdown(initialSeconds: 60),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    device.id.startsWith('demo_')
                        ? 'DEMO'
                        : device.id.startsWith('COM') ||
                                device.id.contains('serial')
                            ? 'SERIAL'
                            : 'BLUETOOTH LE',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    isAdminAuth
                        ? 'Enter admin password to unlock full access.'
                        : 'Enter the device password to connect.',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    onChanged: (v) => password = v,
                    initialValue: password,
                    obscureText: obscure,
                    autofocus: true,
                    style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      hintText: isAdminAuth
                          ? 'Enter admin password'
                          : 'Enter device password',
                      hintStyle: const TextStyle(color: Colors.white24),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: Colors.white38),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: error != null
                                ? Colors.redAccent
                                : Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: error != null
                                ? Colors.redAccent
                                : Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: error != null
                                ? Colors.redAccent
                                : AppColors.brandOrange
                                    .withValues(alpha: 0.5)),
                      ),
                    ),
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(error!,
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: Checkbox(
                        value: remember,
                        onChanged: (v) => setDialogState(
                            () => remember = v ?? false),
                        activeColor: AppColors.brandOrange,
                        checkColor: Colors.black,
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setDialogState(
                          () => remember = !remember),
                      child: const Text('Remember password',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('CANCEL',
                    style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: loading ? null : () => submit(),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('AUTHENTICATE'),
              ),
            ],
          );
        },
      );
    },
  );

  return success ?? false;
}

// ── Auth Countdown Widget ──────────────────────────────────────────────────

/// Live countdown timer for the auth dialog.
/// Self-contained — uses [Timer.periodic] internally, NO [Provider] or
/// [InheritedWidget] dependency. Takes a snapshot of remaining seconds
/// at construction and counts down independently.
class _AuthCountdown extends StatefulWidget {
  final int initialSeconds;
  const _AuthCountdown({required this.initialSeconds});

  @override
  State<_AuthCountdown> createState() => _AuthCountdownState();
}

class _AuthCountdownState extends State<_AuthCountdown> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSeconds.clamp(0, 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      setState(() {
        _secondsRemaining = (_secondsRemaining - 1).clamp(0, 60);
      });
      if (_secondsRemaining <= 0) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _secondsRemaining <= 10 && _secondsRemaining > 0;
    final hideTimer = _secondsRemaining > 55;
    if (hideTimer) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (urgent ? Colors.red : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (urgent ? Colors.red : Colors.orange).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: urgent ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            '${_secondsRemaining}s',
            style: TextStyle(
              color: urgent ? Colors.red : Colors.orange,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Remove Device Confirmation ───────────────────────────────────────────────

/// Standalone confirmation function for removing a device.
/// Disconnects, removes from paired history, and closes the bottom sheet.
Future<void> _confirmRemoveDevice(
    BuildContext context, DeviceInfo device, DeviceProvider dp) async {
  final history = context.read<HistoryProvider>();
  final deviceId = device.id;
  final deviceName = device.displayName;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.warning_rounded,
          color: Colors.redAccent, size: 32),
      title: const Text('Remove Device?',
          style: TextStyle(color: Colors.white)),
      content: Text('Disconnect and remove "$deviceName" from paired devices.',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('CANCEL',
              style: TextStyle(color: Colors.white54)),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
            foregroundColor: Colors.redAccent,
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

// ── Pair Bottom Sheet ──────────────────────────────────────────────────────

void _showPairBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => const _PairBottomSheet(),
  );
}

class _PairBottomSheet extends StatefulWidget {
  const _PairBottomSheet();

  @override
  State<_PairBottomSheet> createState() => _PairBottomSheetState();
}

class _PairBottomSheetState extends State<_PairBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBaud = '1000000';
  final Set<String> _connectingIds = {};
  final Map<String, String> _failedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _startScan();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _startScan();
    }
  }

  void _startScan() {
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    ble.startScan();
    serial.startScan();
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

  void _dismissError(String id) {
    setState(() => _failedIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
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
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          flex: 1,
          child: ConsoleLogView(height: double.infinity),
        ),
      ],
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
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: onRetry,
                        child: const Icon(Icons.refresh_rounded, size: 14),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white38,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: onDismissError,
                        child: const Icon(Icons.close_rounded, size: 14),
                      ),
                    ),
                  ],
                )
              else if (trailing != null)
                trailing!,
            ],
          ),
        ),
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
                mainAxisSize: MainAxisSize.min,
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
                            : 'READY TO CONNECT',
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
            // Baud rate or retry
            if (isConnecting)
              const SizedBox.shrink()
            else if (hasError)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: onRetry,
                      child: const Icon(Icons.refresh_rounded, size: 14),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white38,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: onDismissError,
                      child: const Icon(Icons.close_rounded, size: 14),
                    ),
                  ),
                ],
              )
            else ...[
              // Baud rate dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedBaud,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    isDense: true,
                    items: _baudRates.map((b) {
                      return DropdownMenuItem(
                        value: b,
                        child: Text('$b baud',
                            style: GoogleFonts.jetBrainsMono(
                                color: Colors.white, fontSize: 10)),
                      );
                    }).toList(),
                    onChanged: (String? v) {
                      if (v != null) onBaudChanged(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Connect button
              SizedBox(
                height: 28,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: onConnect,
                  child: Text('CONNECT',
                      style: GoogleFonts.changa(
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
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
// ── Shared bottom widgets ───────────────────────────────────────────────────

Widget _buildSectionTag(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 8, height: 8, color: AppColors.brandOrange),
      const SizedBox(width: 12),
      Text(title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.brandOrange, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _TelemetryItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _TelemetryItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: GoogleFonts.exo2(
                    color: AppColors.brandOrange,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Text(unit,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

// ── Paired Models List ───────────────────────────────────────────────────────

class _PairedModelConnectionState {
  final PairedDevice device;
  final String status; // 'idle', 'scanning', 'connecting', 'connected', 'failed'
  final String? message;

  const _PairedModelConnectionState({
    required this.device,
    this.status = 'idle',
    this.message,
  });

  _PairedModelConnectionState copyWith({
    PairedDevice? device,
    String? status,
    String? message,
  }) {
    return _PairedModelConnectionState(
      device: device ?? this.device,
      status: status ?? this.status,
      message: message,
    );
  }
}

class _PairedModelsList extends StatefulWidget {
  @override
  State<_PairedModelsList> createState() => _PairedModelsListState();
}

class _PairedModelsListState extends State<_PairedModelsList> {
  final Map<String, _PairedModelConnectionState> _connectionStates = {};

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final useWide = MediaQuery.of(context).size.width > 600;
    final connectedId =
        deviceProvider.isConnected ? deviceProvider.connectedDevice?.id : null;
    final allDevices = history.pairedDevices;
    final filteredDevices =
        allDevices.where((d) => d.id != connectedId).toList();

    if (filteredDevices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTag(context, 'PAIRED_MODELS'),
        if (useWide)
          _buildLandscapeGrid(filteredDevices)
        else
          ...filteredDevices.map((device) => _buildCard(device)),
      ],
    );
  }

  Widget _buildCard(PairedDevice device) {
    final connectionState = _connectionStates[device.id] ??
        _PairedModelConnectionState(device: device);
    return _PairedModelCard(
      state: connectionState,
      onReconnect: () => _handleReconnect(device),
      onDismissError: () => _clearStatus(device.id),
      onTap: () => _handleReconnect(device),
    );
  }

  Widget _buildLandscapeGrid(List<PairedDevice> devices) {
    final rows = <Widget>[];
    for (int i = 0; i < devices.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCard(devices[i])),
            const SizedBox(width: 12),
            if (i + 1 < devices.length)
              Expanded(child: _buildCard(devices[i + 1]))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  void _updateStatus(String deviceId, String status, {String? message}) {
    setState(() {
      final current = _connectionStates[deviceId] ??
          _PairedModelConnectionState(device: _findDevice(deviceId)!);
      _connectionStates[deviceId] = current.copyWith(
        status: status,
        message: message,
      );
    });
  }

  void _clearStatus(String deviceId) {
    setState(() {
      _connectionStates.remove(deviceId);
    });
  }

  PairedDevice? _findDevice(String id) {
    return context.read<HistoryProvider>().pairedDevices
        .where((d) => d.id == id).firstOrNull;
  }

  Future<void> _handleReconnect(PairedDevice device) async {
    final console = context.read<ConsoleProvider>();
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    _updateStatus(device.id, 'scanning', message: 'Scanning...');

    console.log('RE-INITIALIZING SOURCE: ${device.type.toUpperCase()}',
        level: ConsoleLogLevel.info);

    if (device.type == 'ble') {
      deviceProvider.setTransport(ble.bleService);
    } else {
      deviceProvider.setTransport(serial.serialService);
    }

    // Check availability
    bool isLive = false;
    if (device.type == 'ble') {
      await ble.startScan();
      await Future.delayed(const Duration(milliseconds: 2500));
      await ble.stopScan();
      isLive = ble.devices.any((d) => d.id == device.id);
    } else if (device.type == 'serial') {
      await serial.startScan();
      isLive = serial.ports.any((p) => p.id == device.id);
    } else {
      isLive = true;
    }

    if (!isLive) {
      if (!mounted) return;
      console.log(
          'RECONNECT FAILED: Device "${device.name}" is not reachable.',
          level: ConsoleLogLevel.error);
      _updateStatus(device.id, 'failed',
          message: ble.errorMessage ?? 'Device is offline or out of range.');
      return;
    }

    if (!mounted) return;
    _updateStatus(device.id, 'connecting', message: 'Connecting...');

    try {
      await deviceProvider.connectToDevice(device.toDeviceInfo());
      if (!mounted) return;
      if (deviceProvider.isConnected) {
        console.log('RESYNC SUCCESSFUL: ${device.name}',
            level: ConsoleLogLevel.success);
        _updateStatus(device.id, 'connected', message: 'Connected!');
        // Clear status after a brief delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _clearStatus(device.id);
        });
      } else {
        final error = deviceProvider.errorMessage ?? 'Connection failed';
        console.log('RESYNC FAILED: $error', level: ConsoleLogLevel.error);
        _updateStatus(device.id, 'failed', message: error);
      }
    } catch (e) {
      if (!mounted) return;
      console.log('RUNTIME ERROR: $e', level: ConsoleLogLevel.error);
      _updateStatus(device.id, 'failed', message: '$e');
    }
  }
}

class _PairedModelCard extends StatelessWidget {
  final _PairedModelConnectionState state;
  final VoidCallback onReconnect;
  final VoidCallback onDismissError;
  final VoidCallback? onTap;

  const _PairedModelCard({
    required this.state,
    required this.onReconnect,
    required this.onDismissError,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final device = state.device;
    final connectionIcon = device.type == 'ble'
        ? Icons.bluetooth_rounded
        : Icons.usb_rounded;
    final status = state.status;
    final isBusy = status == 'scanning' || status == 'connecting';
    final isFailed = status == 'failed';
    final isConnected = status == 'connected';

    return ModelCard(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(4),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(connectionIcon,
              color: AppColors.brandOrange.withValues(alpha: 0.7), size: 36),
        ),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          (device.configName?.isNotEmpty == true
                  ? device.configName!
                  : device.name)
              .toUpperCase(),
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            fontSize: 18,
          ),
        ),
      ),
      subtitle: state.message != null
          ? Text(
              state.message!,
              style: TextStyle(
                color: AppColors.brandOrange.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              device.description?.isNotEmpty == true
                  ? device.description!.toUpperCase()
                  : 'NO_DESCRIPTION_PROVIDED',
              style: TextStyle(
                color: AppColors.brandOrange.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isFailed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.replay_rounded, size: 18, color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      onPressed: onReconnect,
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      onPressed: onDismissError,
                    ),
                  ],
                )
              : Icon(connectionIcon,
                  size: 18,
                  color: AppColors.connected),
    );
  }
  }

// ── Interactive Demo Section ─────────────────────────────────────────────────

class _InteractiveDemoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final useWide = MediaQuery.of(context).size.width > 600;

    final demos = [
      _DemoTile(
        icon: Icons.widgets_rounded,
        title: 'WIDGETS_DEMO',
        subtitle: 'Explore all available widget types',
        onTap: () async {
          final dp = context.read<DeviceProvider>();
          await dp.loadDemo('WIDGETS_DEMO');
          if (context.mounted) context.go('/control');
        },
      ),
      _DemoTile(
        icon: Icons.sports_esports_rounded,
        title: 'RC_CONTROLLER',
        subtitle: 'Simulated remote control interface',
        onTap: () async {
          final dp = context.read<DeviceProvider>();
          await dp.loadDemo('RC_CONTROLLER');
          if (context.mounted) context.go('/control');
        },
      ),
      _DemoTile(
        icon: Icons.dashboard_rounded,
        title: 'IOT_DASHBOARD',
        subtitle: 'IoT monitoring and control panel',
        onTap: () async {
          final dp = context.read<DeviceProvider>();
          await dp.loadDemo('IOT_DASHBOARD');
          if (context.mounted) context.go('/control');
        },
      ),
    ];

    if (useWide)
      return _buildLandscapeGrid(demos);
    else
      return Column(children: demos.map((demo) => _buildCard(demo)).toList());
  }

  Widget _buildCard(_DemoTile demo) {
    return ModelCard(
      leading: Container(
        padding: const EdgeInsets.all(4),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(demo.icon, color: AppColors.brandOrange, size: 36),
        ),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(demo.title.toUpperCase(),
            style: GoogleFonts.exo2(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                fontSize: 18)),
      ),
      subtitle: Text(demo.subtitle.toUpperCase(),
          style: TextStyle(
              color: AppColors.brandOrange.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: demo.onTap,
    );
  }

  Widget _buildLandscapeGrid(List<_DemoTile> demos) {
    final rows = <Widget>[];
    for (int i = 0; i < demos.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCard(demos[i])),
            const SizedBox(width: 12),
            if (i + 1 < demos.length)
              Expanded(child: _buildCard(demos[i + 1]))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _DemoTile {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
