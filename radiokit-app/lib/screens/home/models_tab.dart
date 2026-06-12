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
import '../../models/device_info.dart';
import '../../models/fs_entry.dart';
import '../../models/fs_info.dart';
import '../../models/protocol.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../services/device_fs_service.dart';
import '../designer/widgets/inspector_field_builders.dart';
import 'package:radiokit_widgets/src/utils/icon_registry.dart';
import '../devtools/filesystem/fs_helpers.dart';
import '../devtools/filesystem/fs_breadcrumbs.dart';
import '../devtools/filesystem/fs_file_tile.dart';
import '../devtools/filesystem/fs_info_strip.dart';
import '../devtools/filesystem/fs_action_sheet.dart';
import '../devtools/filesystem/file_editor_cache.dart';
import '../devtools/filesystem/file_editor_dialog.dart';
import '../../widgets/model_card.dart';
import '../../services/websocket_service.dart';
import '../../services/ble_service_impl.dart';
import '../../services/serial_service_native.dart';
import '../../services/serial_service_linux.dart';
import '../../services/cloud_identity.dart';
import 'pair_sheet.dart';

class ModelsTab extends StatelessWidget {
  const ModelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // In landscape mode, don't use Scaffold (parent provides it)
    if (isLandscape) {
      return _buildContent(context, isLandscape);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: 0,
        onConnect: () => showPairBottomSheet(context),
      ),
      body: _buildContent(context, isLandscape),
    );
  }

  Widget _buildContent(BuildContext context, bool isLandscape) {
    return isLandscape
        ? _buildLandscapeBody(context)
        : _buildPortraitBody(context);
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
/// Returns (transport label, icon) for a device based on its current transport type.
(String, IconData) _transportDisplay(DeviceInfo device) {
  switch (device.currentTransport) {
    case TransportType.ble:
      return ("BLUETOOTH LE", Icons.bluetooth_rounded);
    case TransportType.wifi:
      return ("WiFi", Icons.wifi_rounded);
    case TransportType.cloud:
      return ("CLOUD", Icons.cloud_rounded);
    case TransportType.serial:
      return ("SERIAL", Icons.usb_rounded);
    case TransportType.demo:
      return ("DEMO", Icons.wifi_tethering_rounded);
  }
}


/// Returns the active link card layout — stacks transport info on the right
/// side above the telemetry divider.
Widget _buildActiveLinkCard(
    BuildContext context, DeviceProvider dp, DeviceInfo device) {
  final (transportType, transportIcon) = _transportDisplay(device);
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
                                      color: AppColors.connected
                                          .withValues(alpha: 0.6)),
                                  const SizedBox(width: 2),
                                  Text('${latencyMs}ms',
                                      style: GoogleFonts.jetBrainsMono(
                                          color: AppColors.connected
                                              .withValues(alpha: 0.8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
                                ],
                                const SizedBox(width: 10),
                                Icon(Icons.signal_cellular_alt_rounded,
                                    size: 9,
                                    color: AppColors.connected
                                        .withValues(alpha: 0.6)),
                                const SizedBox(width: 2),
                                Text('${signal} dBm',
                                    style: GoogleFonts.jetBrainsMono(
                                        color: AppColors.connected
                                            .withValues(alpha: 0.8),
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
                          if (description?.isNotEmpty == true)
                            Text(
                              description!.toUpperCase(),
                              style: TextStyle(
                                  color: AppColors.brandOrange
                                      .withValues(alpha: 0.7),
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
                    // Device icon (from NVS config) or transport icon fallback
                    _DeviceIconWidget(
                      deviceIcon: device.deviceIcon,
                      fallbackIcon: transportIcon,
                      size: 60,
                      iconSize: 36,
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange.withValues(alpha: 0.15),
              foregroundColor: AppColors.brandOrange,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => showPairBottomSheet(context),
            child: Text('+ New device',
                style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontSize: 15,
                    color: AppColors.brandOrange)),
          ),
        ),
      );
    }

    final device = deviceProvider.connectedDevice!;
    final needAuth =
        deviceProvider.hasPassword && !deviceProvider.isAuthenticated;

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSectionTag(context, 'ACTIVE_LINKS'),
        ),
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
      Flexible(
          child:
              _TelemetryItem(label: 'BATTERY', value: '$battery', unit: '%')),
      Flexible(
          child: _TelemetryItem(label: 'SPEED', value: '$speed', unit: 'km/h')),
      Flexible(
          child: _TelemetryItem(label: 'TEMP', value: '$temp', unit: '°C')),
    ],
  );
}

Widget _buildActiveLinkActions(
    BuildContext context, DeviceProvider dp, DeviceInfo device) {
  const buttonHeight = 40.0;
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
          label: 'CONTROLLER',
          shortLabel: 'CTRL',
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
                  final displayLabel =
                      showShort ? (shortLabel ?? label) : label;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(displayLabel ?? '',
                          style: GoogleFonts.changa(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                              fontSize: 20,
                              color:
                                  isDisconnect ? Colors.white : Colors.black)),
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
  bool _sheetAutoClosed = false;

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
    _tabCount = 2; // Info + Settings always present
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

    // Close the sheet automatically when the device disconnects
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
    if (dp.isConnected && _sheetAutoClosed) {
      _sheetAutoClosed = false;
    }

    final hasFs = device.hasFs;
    final hasOta = dp.hasOta;

    final isUserMode = dp.isUserMode;

    // Build tabs list (admin mode — show all available tabs)
    final tabs = <Tab>[];
    final tabWidgets = <Widget>[];

    tabs.add(const Tab(text: 'INFO'));
    tabWidgets.add(_InfoTabContent(
      device: device,
      bleInfo: _bleInfo,
      loadingBleInfo: _loadingBleInfo,
    ));

    tabs.add(const Tab(text: 'SETTINGS'));
    tabWidgets.add(_SettingsTabContent());

    if (hasFs && !isUserMode) {
      tabs.add(const Tab(text: 'FILESYSTEM'));
      tabWidgets.add(_FsTabContent());
    }

    if (hasOta && !isUserMode) {
      tabs.add(const Tab(text: 'FIRMWARE'));
      tabWidgets.add(_FirmwareTabContent(
        device: device,
      ));
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Transform.translate(
        offset: const Offset(0, -18),
        child: Column(
          children: [
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
      ),
    );
  }
}

// ── Info Tab Content ─────────────────────────────────────────────────────────

class _InfoTabContent extends StatefulWidget {
  final DeviceInfo device;
  final Map<String, dynamic>? bleInfo;
  final bool loadingBleInfo;

  const _InfoTabContent({
    required this.device,
    required this.bleInfo,
    required this.loadingBleInfo,
  });

  @override
  State<_InfoTabContent> createState() => _InfoTabContentState();
}

class _InfoTabContentState extends State<_InfoTabContent> {
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
    final dp = context.read<DeviceProvider>();
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
    final dp = context.watch<DeviceProvider>();

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

    // Determine transport states from actual current transport
    final isConnected = dp.isConnected;
    final trans = dp.currentTransport;
    final isBleConnected = trans is BleService;
    final isWifiConnected = trans is WebSocketService;
    final isCloudConnected = false; // cloud detection TBD

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
                        _transportLabel(device.id),
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
          if (widget.loadingBleInfo)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Fetching connection info...',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            )
          else ...[
            const SizedBox(height: 12),
            Text(
              'Connection: ${widget.bleInfo?['connIntervalMs'] ?? dp.latencyMs ?? '--'}ms '
              '| MTU: ${widget.bleInfo?['negotiatedMtu'] ?? '--'}'
              ' | Signal: ${widget.bleInfo?['rssi'] ?? dp.rssi ?? device.rssi ?? '--'} dBm',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
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
                // BLE badge — shown only if NVS-enabled
                if (_nvsBleOn)
                  _TransportBadge(
                    type: 'BLE',
                    icon: Icons.bluetooth_rounded,
                    connected: isConnected && isBleConnected,
                    available: true,
                    rssi: (isConnected && isBleConnected) ? (dp.rssi ?? device.rssi) : null,
                    onTap: isConnected && !isBleConnected
                        ? () => _onTransportTap(context, dp, device, TransportType.ble)
                        : null,
                  ),
                if (_nvsBleOn) const SizedBox(width: 8),
                // WiFi badge — shown only if NVS-enabled and device has WiFi feature
                if (_nvsWifiOn && (hasWifi || isWifiConnected))
                  _TransportBadge(
                    type: 'WiFi',
                    icon: Icons.wifi_rounded,
                    connected: isConnected && isWifiConnected,
                    available: hasWifi || isWifiConnected,
                    rssi: (isConnected && isWifiConnected) ? (dp.rssi ?? device.rssi) : null,
                    onTap: hasWifi && isConnected && !isWifiConnected
                        ? () => _onTransportTap(context, dp, device, TransportType.wifi)
                        : null,
                  ),
                if (_nvsWifiOn && (hasWifi || isWifiConnected)) const SizedBox(width: 8),
                // Cloud badge — shown only if NVS-enabled and device has Cloud feature
                if (_nvsCloudOn && (hasCloud || isCloudConnected))
                  _TransportBadge(
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
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _transportSwitchMessage!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 24),
          // ── Device Action Buttons ────────────────────────────
          if (!isDemo) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.4)),
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
                onPressed: () => _confirmRemoveDevice(context, device, dp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onTransportTap(BuildContext context, DeviceProvider dp, DeviceInfo device, TransportType targetTransport) async {
    // Determine current transport label for dialog message
    final currentTransportObj = dp.currentTransport;
    String currentLabel;
    if (currentTransportObj is BleService) {
      currentLabel = 'BLE';
    } else if (currentTransportObj is WebSocketService) {
      currentLabel = 'WiFi';
    } else {
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
        icon: const Icon(Icons.swap_horiz_rounded,
            color: AppColors.brandOrange, size: 32),
        title: Text('Switch to $targetLabel?'),
        content: Text(
          'Connected via $currentLabel. Switching to $targetLabel '
          'connects the new transport first, then seamlessly disconnects '
          'the old one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange,
              foregroundColor: Colors.black,
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
          backgroundColor: Colors.greenAccent,
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
          backgroundColor: Colors.orangeAccent,
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
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(e.value,
                      style: GoogleFonts.jetBrainsMono(
                          color: Colors.white,
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

class _SettingsTabContent extends StatefulWidget {
  @override
  State<_SettingsTabContent> createState() => _SettingsTabContentState();
}

class _SettingsTabContentState extends State<_SettingsTabContent> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _pwdCtrl;
  late TextEditingController _adminPwdCtrl;

  String _originalName = '';
  String _originalDesc = '';
  bool _pwdVisible = false;
  bool _adminPwdVisible = false;
  bool _savingName = false;
  bool _savingDesc = false;
  bool _savingPwd = false;
  bool _savingAdminPwd = false;

  bool _bleEnabled = true;
  bool _wifiEnabled = false;
  bool _cloudEnabled = false;
  bool _cloudMatched = false;
  bool _transportChanged = false;
  String _deviceIcon = '';
  bool _iconChanged = false;

  @override
  void initState() {
    super.initState();
    final dp = context.read<DeviceProvider>();
    _originalName = dp.configName ?? '';
    _originalDesc = dp.description ?? '';
    _deviceIcon = dp.deviceIcon ?? '';
    _nameCtrl = TextEditingController(text: _originalName);
    _descCtrl = TextEditingController(text: _originalDesc);
    _pwdCtrl = TextEditingController();
    _adminPwdCtrl = TextEditingController();

    // Load NVS transport enable states
    _loadTransportNvsKeys(dp);
  }

  Future<void> _loadTransportNvsKeys(DeviceProvider dp) async {
    if (!dp.isConnected) return;
    final bleResult = await dp.readNvsRawKey('rk_ble_on');
    final wifiResult = await dp.readNvsRawKey('rk_wifi_on');
    final cloudResult = await dp.readNvsRawKey('rk_cloud_on');
    if (!mounted) return;
    setState(() {
      _bleEnabled = (bleResult.value ?? 1) != 0;
      _wifiEnabled = (wifiResult.value ?? 0) != 0;
      _cloudEnabled = (cloudResult.value ?? 0) != 0;
    });

    // Check cloud account match
    try {
      final cloudInfo = await dp.sendGetCloudInfo();
      if (cloudInfo != null && mounted) {
        final identityService = CloudIdentityService();
        await identityService.initialize();
        _cloudMatched =
            identityService.hasIdentity && identityService.account == cloudInfo.account;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _pwdCtrl.dispose();
    _adminPwdCtrl.dispose();
    super.dispose();
  }

  bool get _nameChanged => _nameCtrl.text.trim() != _originalName;
  bool get _descChanged => _descCtrl.text.trim() != _originalDesc;
  bool get _pwdChanged => _pwdCtrl.text.trim().isNotEmpty;
  bool get _adminPwdChanged => _adminPwdCtrl.text.trim().isNotEmpty;

  String? _connectedTransportName(DeviceProvider dp) {
    if (!dp.isConnected) return null;
    final t = dp.currentTransport;
    if (t is BleService) return 'BLE';
    if (t is WebSocketService) return 'WIFI';
    if (t is LinuxSerialService || t is SerialService) return 'Serial';
    return null;
  }

  /// Returns true if disabling this transport would leave NO transports enabled.
  bool _willAllTransportsDisabled(String transport) {
    final othersOn = switch (transport) {
      'BLE'   => _wifiEnabled || _cloudEnabled,
      'WIFI'  => _bleEnabled,  // cloud is also turned off when wifi is disabled
      'CLOUD' => _bleEnabled || _wifiEnabled,
      _       => true,
    };
    return !othersOn;
  }

  Future<bool> _confirmDisableTransport(
      DeviceProvider dp, String transport) async {
    final connectedVia = _connectedTransportName(dp);
    if (connectedVia != transport) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded,
            color: Colors.orangeAccent, size: 32),
        title: const Text('Disconnect Device?'),
        content: Text(
          'Connected via $transport. Disabling this will cause the device to disconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DISABLE'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<bool> _confirmDisableAllTransports(String transport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_rounded,
            color: Colors.redAccent, size: 32),
        title: const Text('All Transports Disabled?'),
        content: Text(
          'Disabling $transport will leave no transports enabled on this device. '
          'It will become unreachable until manually reconnected via a wired connection or factory reset.',
        ),
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
            child: const Text('DISABLE ANYWAY'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTag('MODEL_INFO'),
          const SizedBox(height: 16),
          _buildSaveField(
            label: 'NAME',
            ctrl: _nameCtrl,
            isChanged: _nameChanged,
            saving: _savingName,
            onSave: () => _saveField(dp, 'name'),
          ),
          const SizedBox(height: 16),
          _buildSaveField(
            label: 'DESCRIPTION',
            ctrl: _descCtrl,
            isChanged: _descChanged,
            saving: _savingDesc,
            onSave: () => _saveField(dp, 'description'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildIconPicker(dp),
          const SizedBox(height: 16),
          _buildSaveField(
            label: 'CONNECTION PASSWORD (leave empty to clear)',
            ctrl: _pwdCtrl,
            isChanged: _pwdChanged,
            saving: _savingPwd,
            onSave: () => _saveField(dp, 'password'),
            isPassword: true,
            pwdVisible: _pwdVisible,
            onTogglePwd: () => setState(() => _pwdVisible = !_pwdVisible),
          ),
          const SizedBox(height: 16),
          _buildSaveField(
            label: 'ADMIN PASSWORD (leave empty to clear)',
            ctrl: _adminPwdCtrl,
            isChanged: _adminPwdChanged,
            saving: _savingAdminPwd,
            onSave: () => _saveField(dp, 'adminPassword'),
            isPassword: true,
            pwdVisible: _adminPwdVisible,
            onTogglePwd: () =>
                setState(() => _adminPwdVisible = !_adminPwdVisible),
            isAdmin: true,
          ),
          const SizedBox(height: 32),
          _buildSectionTag('CONNECTION'),
          const SizedBox(height: 16),
          _buildTransportRow(
            icon: Icons.bluetooth_rounded,
            label: 'BLE',
            subtitle: 'Bluetooth Low Energy',
            enabled: _bleEnabled,
            onChanged: (v) async {
              if (!v) {
                if (_willAllTransportsDisabled('BLE')) {
                  final ok = await _confirmDisableAllTransports('BLE');
                  if (!ok) return;
                } else {
                  final ok = await _confirmDisableTransport(dp, 'BLE');
                  if (!ok) return;
                }
              }
              setState(() => _bleEnabled = v);
              await _writeTransportKey(dp, 'rk_ble_on', v ? 1 : 0);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_rounded,
                        size: 20,
                        color: _wifiEnabled
                            ? AppColors.brandOrange
                            : Colors.white38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WIFI',
                              style: TextStyle(
                                  color: _wifiEnabled
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Wireless network',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _wifiEnabled,
                      onChanged: (v) async {
                        if (!v) {
                          if (_willAllTransportsDisabled('WIFI')) {
                            final ok = await _confirmDisableAllTransports('WIFI');
                            if (!ok) return;
                          } else {
                            final ok = await _confirmDisableTransport(dp, 'WIFI');
                            if (!ok) return;
                          }
                        }
                        setState(() {
                          _wifiEnabled = v;
                          if (!v) _cloudEnabled = false;
                        });
                        await _writeTransportKey(dp, 'rk_wifi_on', v ? 1 : 0);
                      },
                      activeThumbColor: AppColors.brandOrange,
                    ),
                  ],
                ),
                if (_wifiEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Colors.white10),
                  ),
                  _buildSettingRow(
                    Icons.cloud_rounded,
                    'CLOUD',
                    _cloudMatched
                        ? 'Remote access over internet'
                        : 'Configure in Pairing',
                    Switch(
                      value: _cloudEnabled && _cloudMatched,
                      onChanged: _cloudMatched
                          ? (v) async {
                              if (!v && _willAllTransportsDisabled('CLOUD')) {
                                final ok = await _confirmDisableAllTransports('CLOUD');
                                if (!ok) return;
                              }
                              setState(() => _cloudEnabled = v);
                              await _writeTransportKey(dp, 'rk_cloud_on', v ? 1 : 0);
                            }
                          : null,
                      activeThumbColor: AppColors.brandOrange,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_transportChanged) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _applyTransportAndReboot(dp),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('CONFIRM TO APPLY',
                        style: GoogleFonts.changa(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontSize: 14,
                            color: Colors.black)),
                    Text('& REBOOT NOW',
                        style: GoogleFonts.changa(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Transport changes only take effect after reboot. '
              'Close without applying to keep current configuration.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          const SizedBox(height: 32),
          _buildSectionTag('REBOOT'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                side: BorderSide(
                    color: Colors.orangeAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              label: Text('REBOOT DEVICE',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 12)),
              onPressed: () => _confirmReboot(dp),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Restart the device without erasing any settings. '
            'Useful after changing transport configuration.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 32),
          _buildSectionTag('FACTORY_RESET'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side:
                    BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: Text('FACTORY RESET',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 12)),
              onPressed: () => _factoryReset(dp),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Erase all settings (name, description, password) '
            'and reboot the device. Compile-time defaults will be restored.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTag(String title) {
    return Row(
      children: [
        Container(width: 6, height: 6, color: AppColors.brandOrange),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.changa(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.5,
                color: AppColors.brandOrange)),
      ],
    );
  }

  Widget _buildTransportRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: enabled ? AppColors.brandOrange : Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: enabled ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.brandOrange),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
      IconData icon, String label, String value, Widget trailing) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: AppColors.brandOrange.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildSaveField({
    required String label,
    required TextEditingController ctrl,
    required bool isChanged,
    required bool saving,
    required VoidCallback onSave,
    int maxLines = 1,
    bool isPassword = false,
    bool pwdVisible = false,
    VoidCallback? onTogglePwd,
    bool isAdmin = false,
  }) {
    final borderColor =
        isAdmin ? AppColors.brandOrange.withValues(alpha: 0.3) : Colors.white12;
    final focusBorderColor = isAdmin
        ? AppColors.brandOrange.withValues(alpha: 0.7)
        : AppColors.brandOrange.withValues(alpha: 0.5);
    final labelColor =
        isAdmin ? AppColors.brandOrange.withValues(alpha: 0.7) : Colors.white54;
    final labelIcon = isAdmin
        ? Icon(Icons.admin_panel_settings_outlined,
            size: 12, color: AppColors.brandOrange.withValues(alpha: 0.5))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          if (labelIcon != null) ...[const SizedBox(width: 6), labelIcon],
        ]),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: maxLines,
                obscureText: isPassword && !pwdVisible,
                style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: isPassword && onTogglePwd != null
                      ? IconButton(
                          icon: Icon(
                              pwdVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: Colors.white38),
                          onPressed: onTogglePwd,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: focusBorderColor),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (isChanged) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.save_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildIconPicker(DeviceProvider dp) {
    final iconData = _deviceIcon.isNotEmpty && kDesignerIcons.containsKey(_deviceIcon)
        ? kDesignerIcons[_deviceIcon]!
        : Icons.memory_rounded;
    final iconChanged = _deviceIcon != (dp.deviceIcon ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('ICON',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickIcon(context, dp),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(iconData,
                            color: AppColors.brandOrange, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _deviceIcon.isNotEmpty ? _deviceIcon : 'Tap to select',
                              style: GoogleFonts.jetBrainsMono(
                                color: _deviceIcon.isNotEmpty
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _deviceIcon.isNotEmpty
                                  ? 'Tap to change'
                                  : 'Choose a device icon',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: Colors.white24),
                    ],
                  ),
                ),
              ),
            ),
            if (iconChanged) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => _saveIcon(dp),
                  child: const Icon(Icons.save_rounded, size: 18),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickIcon(BuildContext context, DeviceProvider dp) async {
    IconFieldBuilder.openIconPickerDialog(
      context,
      currentIconName: _deviceIcon.isNotEmpty ? _deviceIcon : null,
      onChanged: (newIcon) {
        if (!mounted) return;
        setState(() => _deviceIcon = newIcon ?? '');
      },
    );
  }

  Future<void> _saveIcon(DeviceProvider dp) async {
    final icon = _deviceIcon.isNotEmpty ? _deviceIcon : null;
    final ok = await dp.sendSetConf(icon: icon, clearIcon: icon == null);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device icon saved'),
          backgroundColor: Colors.greenAccent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save icon'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveField(DeviceProvider dp, String field) async {
    setState(() {
      if (field == 'name') _savingName = true;
      if (field == 'description') _savingDesc = true;
      if (field == 'password') _savingPwd = true;
      if (field == 'adminPassword') _savingAdminPwd = true;
    });

    final name = field == 'name' ? _nameCtrl.text.trim() : null;
    final desc = field == 'description' ? _descCtrl.text.trim() : null;
    final pwd = field == 'password' ? _pwdCtrl.text.trim() : null;
    final adminPwd =
        field == 'adminPassword' ? _adminPwdCtrl.text.trim() : null;

    final ok = await dp.sendSetConf(
      name: name,
      description: desc,
      password: pwd,
      adminPassword: adminPwd,
    );

    if (!mounted) return;
    setState(() {
      _savingName = false;
      _savingDesc = false;
      _savingPwd = false;
      _savingAdminPwd = false;
      if (ok) {
        if (field == 'name') _originalName = name ?? _originalName;
        if (field == 'description') _originalDesc = desc ?? _originalDesc;
        if (field == 'password') _pwdCtrl.clear();
        if (field == 'adminPassword') _adminPwdCtrl.clear();
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Field saved to device' : 'Failed to save'),
        backgroundColor: ok ? Colors.greenAccent : Colors.redAccent,
      ),
    );
  }

  Future<void> _writeTransportKey(DeviceProvider dp, String key, int value) async {
    final status = await dp.writeNvsRawKey(key, value);
    if (!mounted) return;

    if (status != kSettingsNvsRawOk) {
      // Show error — likely auth issue (NVS_RAW_WRITE requires device-level auth)
      final isDevMode = dp.isDeviceMode;
      final msg = isDevMode
          ? 'Failed to write to device NVS (status=$status).'
          : 'Device-level access required. Authenticate with the device password '
              'before changing transport settings. ';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Mark transport as changed — show Apply & Reboot button instead of dialog
    setState(() => _transportChanged = true);
  }

  Future<void> _applyTransportAndReboot(DeviceProvider dp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded,
            color: Colors.orangeAccent, size: 32),
        title: const Text('Reboot to Apply Changes?'),
        content: const Text(
          'The device will reboot to apply the transport changes. '
          'After reboot, you may need to reconnect via the new transport.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('REBOOT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await dp.sendReboot();
    if (!mounted) return;
    dp.disconnect();
    if (context.mounted) context.go('/models');
  }

  Future<void> _confirmReboot(DeviceProvider dp) async {
    if (!dp.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device connected'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded,
            color: Colors.orangeAccent, size: 32),
        title: const Text('Reboot Device?'),
        content: const Text(
          'Restart the device without erasing any settings. '
          'The device will disconnect and reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('REBOOT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await dp.sendReboot();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Reboot sent — device restarting...'
            : 'Failed to send reboot command'),
        backgroundColor: ok ? Colors.orangeAccent : Colors.redAccent,
      ),
    );
  }

  Future<void> _factoryReset(DeviceProvider dp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded,
            color: Colors.redAccent, size: 32),
        title: const Text('Factory Reset?'),
        content: const Text(
            'This will erase all device settings (name, description, password) '
            'and reboot the device.\n\n'
            'After reboot, compile-time defaults will be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ERASE & REBOOT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await dp.sendFactoryReset();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Factory reset sent — device rebooting...'
            : 'Failed to send factory reset'),
        backgroundColor: ok ? Colors.orangeAccent : Colors.redAccent,
      ),
    );

    if (ok) {
      dp.disconnect();
      if (context.mounted) context.go('/models');
    }
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
          speedBytesPerSec:
              _transferStartTime != null && _transferStartTime != null
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
        if (_statusMessage != null ||
            _errorMessage != null ||
            _progress != null)
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
            const Icon(Icons.folder_open_rounded,
                size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Center(
                child: Text('Empty directory',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
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

    return Stack(
      children: [
        Column(
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
          ],
        ),
        // Floating action buttons
        if (_isMultiSelect)
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _floatingActionButton(
                  icon: Icons.select_all_rounded,
                  tooltip: 'Select all',
                  onPressed: _selectedPaths.length == _entries.length
                      ? _deselectAll
                      : _selectAll,
                ),
                const SizedBox(width: 8),
                _floatingActionButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete selected',
                  onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
                ),
                const SizedBox(width: 8),
                _floatingActionButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  onPressed: () {
                    setState(() {
                      _selectedPaths.clear();
                      _isMultiSelect = false;
                    });
                  },
                ),
              ],
            ),
          )
        else
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _floatingActionButton(
                  icon: Icons.create_new_folder_outlined,
                  tooltip: 'New folder',
                  onPressed: _createFolder,
                ),
                const SizedBox(width: 8),
                _floatingActionButton(
                  icon: Icons.upload_file_rounded,
                  tooltip: 'Upload file',
                  onPressed: () => _uploadFile(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _floatingActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: FloatingActionButton(
          backgroundColor: AppColors.brandOrange.withValues(alpha: 0.9),
          foregroundColor: Colors.black,
          onPressed: onPressed,
          child: Icon(icon, size: 20),
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
        case _NewChoice.upload:
          _uploadFile();
          break;
        case _NewChoice.mkdir:
          _createFolder();
          break;
        default:
          break;
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
    final action =
        await FsActionSheet.show(context, entry: entry, fullPath: path);
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
      final res =
          await _fs!.writeFile(remotePath, picked.bytes, onProgress: (w, t) {
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
      final savePath =
          await promptSaveFile(context, fileName: entry.name, bytes: bytes);
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
        if (res.success) {
          okCount++;
        } else {
          failCount++;
        }
      } catch (_) {
        failCount++;
      }
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
        setState(() {
          _statusMessage = 'Renamed';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Rename failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Rename error: $e';
        _progress = null;
      });
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
        setState(() {
          _statusMessage = 'Created folder';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Create failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Create error: $e';
        _progress = null;
      });
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
  void _exitMultiSelect() => setState(() {
        _isMultiSelect = false;
        _selectedPaths.clear();
      });

  void _showInfoDialog(FsEntry entry, String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.name),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Type', entry.isDirectory ? 'Folder' : 'File'),
              _kv('Path', path),
              if (!entry.isDirectory) _kv('Size', formatBytes(entry.size)),
              if (!entry.isDirectory) _kv('Bytes', entry.size.toString()),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'))
        ],
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
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12))),
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
      await dp.uploadFirmware(firmware, eraseAll: eraseAll,
          onProgress: (received, total) {
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
    final speed =
        ms > 0 ? (received / ms * 1000 / 1024).toStringAsFixed(1) : '0';
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
            if (_selectedFileName != null &&
                _selectedFirmwareBytes != null) ...[
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
                            Text(_formatBytes(_selectedFirmwareBytes!.length),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 18,
                        color: _eraseAll ? Colors.redAccent : Colors.white38),
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
                          Text(
                              'Reset to factory defaults after reboot (NVS + filesystem)',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _eraseAll,
                      onChanged: (v) => setState(() => _eraseAll = v),
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
                valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
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
              const Icon(Icons.error_rounded,
                  color: Colors.redAccent, size: 20),
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

// ── Transport Badge Widget ──────────────────────────────────────────────────

/// Compact transport status pill shown in the Info tab.
/// Shows an icon, label, green dot if connected, gray if available, dimmed if not.
class _TransportBadge extends StatelessWidget {
  final String type;
  final IconData icon;
  final bool connected;
  final bool available;
  final int? rssi;
  final VoidCallback? onTap;

  const _TransportBadge({
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
              ? AppColors.connected.withValues(alpha: 0.15)
              : available
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: connected
                ? AppColors.connected.withValues(alpha: 0.3)
                : available
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.04),
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
                    ? AppColors.connected
                    : available
                        ? Colors.white38
                        : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon,
                size: 14,
                color: connected
                    ? Colors.white
                    : available
                        ? Colors.white54
                        : Colors.white.withValues(alpha: 0.15)),
            const SizedBox(width: 4),
            Text(type.toUpperCase(),
                style: TextStyle(
                    color: connected
                        ? Colors.white
                        : available
                            ? Colors.white54
                            : Colors.white.withValues(alpha: 0.15),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            if (rssi != null) ...[
              const SizedBox(width: 4),
              Text('${rssi}dBm',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 8,
                      fontFamily: 'monospace')),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz_rounded,
                  size: 12,
                  color: AppColors.brandOrange.withValues(alpha: 0.6)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared Auth Dialog ─────────────────────────────────────────────────────

/// Shows a reusable authentication dialog for both connection (password gate)
/// and upgrade (user→device) authentication.
///
/// Uses the single [DeviceProvider.authenticate] method. The device returns
/// the granted auth level (device or user) based on which password was entered.
/// "Remember password" is saved via [SecureStorageService.savePassword].
/// Returns true if auth succeeded, false if cancelled or failed.
Future<bool> _showAuthDialog(
  BuildContext context,
  DeviceInfo device, {
  bool isAdminAuth = false,
}) async {
  final dp = context.read<DeviceProvider>();
  bool obscure = true;
  bool loading = false;
  bool remember = true;
  String? error;
  String password = '';

  // Load saved password
  final saved = await SecureStorageService.loadPassword(device.id);
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
          // Auto-dismiss when auth happens externally (e.g., via remote API)
          final authDp = context.watch<DeviceProvider>();
          if (authDp.isAuthenticated) {
            Future.microtask(() {
              if (context.mounted) Navigator.of(ctx).pop(true);
            });
          }

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
            final ok = await dp.authenticate(pwd);
            if (!context.mounted) return;
            if (ok) {
              if (remember) {
                SecureStorageService.savePassword(device.id, pwd);
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.lock_rounded,
                      color: AppColors.brandOrange, size: 22),
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
                  const _AuthCountdown(initialSeconds: 30),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    _transportLabel(device.id),
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
                    const Text(
                      'Enter the device password to connect.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
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
                        hintText: 'Enter device password',
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
                          onChanged: (v) =>
                              setDialogState(() => remember = v ?? false),
                          activeColor: AppColors.brandOrange,
                          checkColor: Colors.black,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setDialogState(() => remember = !remember),
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
      icon:
          const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 32),
      title:
          const Text('Remove Device?', style: TextStyle(color: Colors.white)),
      content: Text('Disconnect and remove "$deviceName" from paired devices.',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
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

// ── Shared bottom widgets ───────────────────────────────────────────────────

/// Returns a human-readable transport label for the given device ID.
String _transportLabel(String id) {
  if (id.startsWith('demo_')) return 'DEMO';
  final isWs = id.startsWith('ws://') || id.startsWith('wss://');
  if (isWs && id.contains('relay')) return 'CLOUD';
  if (isWs) return 'WiFi';
  if (id.startsWith('COM') || id.contains('serial')) return 'SERIAL';
  return 'BLUETOOTH LE';
}

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
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
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
  final String
      status; // 'idle', 'scanning', 'connecting', 'connected', 'failed'
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
        allDevices.where((d) => d.uid != connectedId).toList();

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
    final connectionState = _connectionStates[device.uid] ??
        _PairedModelConnectionState(device: device);
    return _PairedModelCard(
      state: connectionState,
      onReconnect: () => _handleReconnect(device),
      onDismissError: () => _clearStatus(device.uid),
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
    return context
        .read<HistoryProvider>()
        .pairedDevices
        .where((d) => d.uid == id)
        .firstOrNull;
  }

  Future<void> _handleReconnect(PairedDevice device) async {
    final console = context.read<ConsoleProvider>();
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    _updateStatus(device.uid, 'scanning', message: 'Scanning...');

    console.log('RE-INITIALIZING SOURCE: ${device.type.toUpperCase()}',
        level: ConsoleLogLevel.info);

    if (device.type == 'ble') {
      deviceProvider.setTransport(ble.bleService);
    } else if (device.type == 'wifi') {
      final ws = WebSocketService();
      deviceProvider.setTransport(ws);
    } else {
      deviceProvider.setTransport(serial.serialService);
    }

    // Check availability
    bool isLive = false;
    if (device.type == 'ble') {
      await ble.startScan();
      await Future.delayed(const Duration(milliseconds: 2500));
      await ble.stopScan();
      isLive = ble.devices.any((d) => d.id == (device.bleAddress ?? device.uid));
    } else if (device.type == 'serial') {
      await serial.startScan();
      isLive = serial.ports.any((p) => p.id == (device.serialAddress ?? device.uid));
    } else if (device.type == 'wifi') {
      // WiFi: try a quick TCP connection to verify the device is reachable.
      final uri = Uri.tryParse(device.wifiAddress ?? device.uid);
      if (uri != null && (uri.scheme == 'ws' || uri.scheme == 'wss')) {
        try {
          final socket = await Socket.connect(
            uri.host,
            uri.port,
            timeout: const Duration(seconds: 3),
          );
          socket.destroy();
          isLive = true;
        } catch (_) {
          isLive = false;
        }
      }
    } else {
      isLive = true;
    }

    if (!isLive) {
      if (!mounted) return;
      console.log('RECONNECT FAILED: Device "${device.name}" is not reachable.',
          level: ConsoleLogLevel.error);
      final errMsg = device.type == 'ble'
          ? (ble.errorMessage ?? 'Device is offline or out of range.')
          : device.type == 'serial'
              ? (serial.errorMessage ?? 'Device is offline or out of range.')
              : 'Device is offline or out of range.';
      _updateStatus(device.uid, 'failed',
          message: errMsg);

      return;
    }
    if (!mounted) return;
    _updateStatus(device.uid, 'connecting', message: 'Connecting...');

    try {
      await deviceProvider.connectToDevice(device.toDeviceInfo());
      if (!mounted) return;
      if (deviceProvider.isConnected) {
        console.log('RESYNC SUCCESSFUL: ${device.name}',
            level: ConsoleLogLevel.success);
        _updateStatus(device.uid, 'connected', message: 'Connected!');
        // Clear status after a brief delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _clearStatus(device.uid);
        });
      } else {
        final error = deviceProvider.errorMessage ?? 'Connection failed';
        console.log('RESYNC FAILED: $error', level: ConsoleLogLevel.error);
        _updateStatus(device.uid, 'failed', message: error);
      }
    } catch (e) {
      if (!mounted) return;
      console.log('RUNTIME ERROR: $e', level: ConsoleLogLevel.error);
      _updateStatus(device.uid, 'failed', message: '$e');
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
        : device.type == 'wifi'
            ? Icons.wifi_rounded
            : Icons.usb_rounded;
    final status = state.status;
    final isBusy = status == 'scanning' || status == 'connecting';
    final isFailed = status == 'failed';

    // Device icon from history (or default memory icon)
    final iconName = device.deviceIcon;
    final deviceIconData = iconName != null && iconName.isNotEmpty && kDesignerIcons.containsKey(iconName)
        ? kDesignerIcons[iconName]!
        : null;

    return ModelCard(
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                deviceIconData ?? connectionIcon,
                color: AppColors.brandOrange.withValues(alpha: deviceIconData != null ? 1.0 : 0.7),
                size: 36,
              ),
            ),
          ),
          // Transport badge overlay (small icon in corner)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Icon(
                  connectionIcon,
                  size: 12,
                  color: AppColors.brandOrange.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
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
          : device.description?.isNotEmpty == true
              ? Text(
                  device.description!.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.brandOrange.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : const SizedBox.shrink(),
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
                      icon: Icon(Icons.replay_rounded,
                          size: 18, color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      onPressed: onReconnect,
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 14, color: Colors.redAccent),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      onPressed: onDismissError,
                    ),
                  ],
                )
              : Icon(connectionIcon, size: 18, color: AppColors.connected),
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

// ── Device Icon Widget ───────────────────────────────────────────────────────

/// A square container showing the device icon (from kDesignerIcons) or a
/// fallback transport icon when no custom icon is set.
class _DeviceIconWidget extends StatelessWidget {
  final String? deviceIcon;
  final IconData fallbackIcon;
  final double size;
  final double iconSize;

  const _DeviceIconWidget({
    required this.deviceIcon,
    required this.fallbackIcon,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = deviceIcon != null &&
            deviceIcon!.isNotEmpty &&
            kDesignerIcons.containsKey(deviceIcon)
        ? kDesignerIcons[deviceIcon!]!
        : null;

    return Container(
      padding: const EdgeInsets.all(4),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        iconData ?? fallbackIcon,
        color: AppColors.brandOrange,
        size: iconSize,
      ),
    );
  }
}
