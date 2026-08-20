import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/device_provider.dart';
import '../../providers/multi_device_provider.dart';
import '../../providers/history_provider.dart';
import 'starter_templates_section.dart';
import '../../providers/ble_provider.dart';
import '../../providers/serial_provider.dart';
import '../device_config/device_config.dart';
import '../../providers/console_provider.dart';
import '../../services/secure_storage_service.dart';
import '../../models/console_entry.dart';
import '../../models/device_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/themed_bottom_sheet.dart';
import '../../widgets/radiokit_app_bar.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../../services/transport_service.dart';
import '../../widgets/model_card.dart';
import '../../services/websocket_service.dart';
import '../../services/cloud_identity.dart';
import '../../models/tab_index.dart';
import 'pair_sheet.dart';
import '../../services/ble_transport.dart';

class _DeviceAvailability {
  final bool? wifiAvailable;
  final bool? bleAvailable;
  final bool? serialAvailable;
  final bool? cloudAvailable;

  const _DeviceAvailability({
    this.wifiAvailable,
    this.bleAvailable,
    this.serialAvailable,
    this.cloudAvailable,
  });

  bool? get anyAvailable {
    if (wifiAvailable == true || bleAvailable == true ||
        serialAvailable == true || cloudAvailable == true) return true;
    if (wifiAvailable == null && bleAvailable == null &&
        serialAvailable == null && cloudAvailable == null) return null;
    return false;
  }

  _DeviceAvailability copyWith({
    bool? wifiAvailable,
    bool? bleAvailable,
    bool? serialAvailable,
    bool? cloudAvailable,
  }) {
    return _DeviceAvailability(
      wifiAvailable: wifiAvailable ?? this.wifiAvailable,
      bleAvailable: bleAvailable ?? this.bleAvailable,
      serialAvailable: serialAvailable ?? this.serialAvailable,
      cloudAvailable: cloudAvailable ?? this.cloudAvailable,
    );
  }
}

class ModelsTab extends StatefulWidget {
  const ModelsTab({super.key});

  @override
  State<ModelsTab> createState() => _ModelsTabState();
}

class _ModelsTabState extends State<ModelsTab> {
  bool _sheetOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sheetOpened) return;
      _sheetOpened = true;
      final sheet = GoRouterState.of(context).uri.queryParameters['sheet'];
      if (sheet == 'pair') {
        showPairBottomSheet(context);
      } else if (sheet == 'deviceSettings') {
        final multiDevice = context.read<MultiDeviceProvider>();
        final dp = multiDevice.focusedDevice;
        if (dp != null && dp.isConnected) {
          DeviceSettingsDialog.show(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildContent(context, isLandscape);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: TabIndex.models,
        onConnect: () => showPairBottomSheet(context),
        accentColor: context.tokens.primary,
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
        _buildStarterTemplatesSection(context),
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
        _buildStarterTemplatesSection(context),
      ],
    );
  }

  Widget _buildStarterTemplatesSection(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        if (history.pairedDevices.isNotEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildSectionTag(context, 'STARTER_TEMPLATES'),
              const StarterTemplatesSection(
                showHeader: false,
                openInPreview: true,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

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
        final isNarrow = width < 400;
        final paddingSize = (width / 15).clamp(8.0, 16.0);
        final nameFontSize = (width / 14).clamp(16.0, 26.0);
        final actionGap = (width / 15).clamp(12.0, 24.0);
        final gapIconName = isNarrow ? 8.0 : 12.0;

        return Card(
          clipBehavior: Clip.antiAlias,
          color: context.tokens.onSurface.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.tokens.borderRadius.clamp(0, 32)),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: EdgeInsets.all(paddingSize),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(transportIcon, size: isNarrow ? 10 : 12, color: context.tokens.success),
                                const SizedBox(width: 4),
                                Text(transportType,
                                    style: GoogleFonts.inter(
                                        color: context.tokens.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isNarrow ? 10 : 12,
                                        letterSpacing: 1.2)),
                                if (latencyMs != null) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.timer_outlined, size: 9, color: context.tokens.success.withValues(alpha: 0.6)),
                                  const SizedBox(width: 2),
                                  Text('${latencyMs}ms',
                                      style: GoogleFonts.martianMono(
                                          color: context.tokens.success.withValues(alpha: 0.8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
                                ],
                                const SizedBox(width: 10),
                                Icon(Icons.signal_cellular_alt_rounded, size: 9, color: context.tokens.success.withValues(alpha: 0.6)),
                                const SizedBox(width: 2),
                                Text('${signal} dBm',
                                    style: GoogleFonts.martianMono(
                                        color: context.tokens.success.withValues(alpha: 0.8),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
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
                          if (description?.isNotEmpty == true)
                            Text(
                              description!.toUpperCase(),
                              style: TextStyle(
                                  color: context.tokens.primary.withValues(alpha: 0.7),
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
                    _DeviceIconWidget(
                      deviceIcon: device.deviceIcon,
                      fallbackIcon: transportIcon,
                      size: 60,
                      iconSize: 36,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildActiveLinkTelemetry(dp, device),
                SizedBox(height: actionGap),
                _buildActiveLinkActions(context, dp, device),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// -- Active Link Section ------------------------------------------------------

class _ActiveLinkSection extends StatefulWidget {
  @override
  State<_ActiveLinkSection> createState() => _ActiveLinkSectionState();
}

class _ActiveLinkSectionState extends State<_ActiveLinkSection> {
  final Map<String, bool> _authDialogShown = {};

  @override
  Widget build(BuildContext context) {
    final multiDevice = context.watch<MultiDeviceProvider>();
    final devices = multiDevice.devices;
    final activeDevices = devices.where((dp) {
      return dp.isConnected;
    }).toList();
    final useWide = MediaQuery.of(context).size.width > 600;

    if (activeDevices.isEmpty) {
      // Reset all auth dialog flags when all devices disconnect
      if (_authDialogShown.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _authDialogShown.clear());
        });
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: context.tokens.primary.withValues(alpha: 0.15),
              foregroundColor: context.tokens.primary,
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
                    color: context.tokens.primary)),
          ),
        ),
      );
    }

    final cardWidgets = [
      for (final dp in activeDevices)
        _ActiveLinkCardWithAuth(
          deviceProvider: dp,
          authDialogShown: _authDialogShown,
        )
    ];

    Widget body;
    if (useWide) {
      final rows = <Widget>[];
      for (int i = 0; i < cardWidgets.length; i += 2) {
        final left = cardWidgets[i];
        final right = (i + 1 < cardWidgets.length) ? cardWidgets[i + 1] : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                if (right != null)
                  Expanded(child: right)
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
      }
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in cardWidgets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: w,
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSectionTag(context, 'ACTIVE_LINKS'),
        ),
        body,
      ],
    );
  }
}

/// Wraps an active link card with per-device auth dialog logic.
class _ActiveLinkCardWithAuth extends StatefulWidget {
  final DeviceProvider deviceProvider;
  final Map<String, bool> authDialogShown;

  const _ActiveLinkCardWithAuth({
    required this.deviceProvider,
    required this.authDialogShown,
  });

  @override
  State<_ActiveLinkCardWithAuth> createState() => _ActiveLinkCardWithAuthState();
}

class _ActiveLinkCardWithAuthState extends State<_ActiveLinkCardWithAuth> {
  @override
  void initState() {
    super.initState();
    widget.deviceProvider.addListener(_handleProviderChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAuth();
    });
  }

  @override
  void didUpdateWidget(covariant _ActiveLinkCardWithAuth oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deviceProvider != oldWidget.deviceProvider) {
      oldWidget.deviceProvider.removeListener(_handleProviderChange);
      widget.deviceProvider.addListener(_handleProviderChange);
      _checkAuth();
    }
  }

  @override
  void dispose() {
    widget.deviceProvider.removeListener(_handleProviderChange);
    super.dispose();
  }

  void _handleProviderChange() {
    if (mounted) {
      setState(() {});
      _checkAuth();
    }
  }

  void _checkAuth() {
    final dp = widget.deviceProvider;
    final device = dp.connectedDevice;
    if (device == null || !dp.isConnected) return;

    final isSerial = device.currentTransport == TransportType.serial;
    final needAuth = !isSerial && dp.hasPassword && !dp.isAuthenticated;
    final deviceId = device.id;

    if (needAuth && !(widget.authDialogShown[deviceId] ?? false)) {
      widget.authDialogShown[deviceId] = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        // Try auto-auth with saved password first
        final saved = await SecureStorageService.loadPassword(device.id);
        if (saved != null && saved.isNotEmpty) {
          final ok = await dp.authenticate(saved);
          if (ok && mounted) return;
        }

        if (!mounted) return;
        final ok = await _showAuthDialog(context, device, dp);
        if (!mounted) return;
        if (!ok) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) dp.disconnect();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = widget.deviceProvider;
    final device = dp.connectedDevice;
    if (device == null) return const SizedBox.shrink();

    final isSerial = device.currentTransport == TransportType.serial;
    final needAuth = !isSerial && dp.hasPassword && !dp.isAuthenticated;

    // Don't show card if auth is needed (dialog handles it)
    if (needAuth) return const SizedBox.shrink();

    return _buildActiveLinkCard(context, dp, device);
  }
}

// -- Active link helpers ------------------------------------------------------

void _showDeviceInfoSheet(
    BuildContext context, DeviceProvider dp, DeviceInfo device) {
  dp.requestChipInfo();
  showThemedBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => _DeviceInfoTabs(device: device, deviceProvider: dp),
  );
}

Widget _buildActiveLinkTelemetry(DeviceProvider dp, DeviceInfo device) {
  // Read configured telemetry from the device's config JSON
  final configJson = dp.deviceConfigJson;
  final telemetry = configJson?['telemetry'];
  if (telemetry is! List || telemetry.isEmpty) {
    return const SizedBox.shrink();
  }

  // The widgets list provides typeId + widgetId for telemetry widgets
  final widgets = configJson?['widgets'] as List? ?? [];
  final telemetryWidgets = widgets.where((w) {
    final wMap = w as Map?;
    return (wMap?['type'] as String? ?? '') == 'telemetry';
  }).toList();

  final items = <Widget>[];
  for (int i = 0; i < telemetry.length; i++) {
    final t = telemetry[i] as Map;
    final label = (t['label'] as String?) ?? '';
    if (label.isEmpty) continue;
    final iconName = t['icon'] as String?;
    final unit = (t['unit'] as String?) ?? '';

    // Find widgetId for this telemetry slot (index-based)
    String value = '--';
    if (i < telemetryWidgets.length) {
      final wMap = telemetryWidgets[i] as Map;
      final widgetId = (wMap['id'] as num?)?.toInt() ?? -1;
      value = dp.telemetryValues[widgetId] ?? '--';
    }

    items.add(
      Flexible(
        child: _TelemetryItem(
          label: label,
          iconName: iconName,
          value: value,
          unit: unit,
        ),
      ),
    );
  }

  if (items.isEmpty) return const SizedBox.shrink();

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: items,
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
          onTap: () => context.go('/control/${device.id}'),
          height: buttonHeight,
          borderRadius: borderRadius,
        ),
      ),
      const SizedBox(width: 8),
      _ActiveLinkButton(
        icon: Icons.link_off_rounded,
        onTap: () async {
          final multiDevice = context.read<MultiDeviceProvider>();
          await multiDevice.disconnectDevice(device.id);
        },
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
              isDisconnect ? context.tokens.error : context.tokens.primary,
          foregroundColor: isDisconnect ? context.tokens.onError : context.tokens.onPrimary,
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
                              color: isDisconnect ? context.tokens.onError : context.tokens.onPrimary)),
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
                        color: isDisconnect ? context.tokens.onError : context.tokens.onPrimary)),
      ),
    );
  }
}

// -- Device Info Tabs ---------------------------------------------------------

class _DeviceInfoTabs extends StatefulWidget {
  final DeviceInfo device;
  final DeviceProvider deviceProvider;
  const _DeviceInfoTabs({required this.device, required this.deviceProvider});

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
    final dp = widget.deviceProvider;
    final isUserMode = dp.isUserMode;
    final hasFs = dp.hasFs || (dp.connectedDevice?.hasFs ?? false) || widget.device.hasFs;
    final hasOta = dp.hasOta;
    _tabCount = 2;
    if (hasFs && !isUserMode) _tabCount++;
    if (hasOta && !isUserMode) _tabCount++;
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  Future<void> _fetchBleInfo() async {
    if (widget.device.currentTransport != TransportType.ble) {
      if (mounted) setState(() => _loadingBleInfo = false);
      return;
    }
    final info = await widget.deviceProvider.sendGetBleInfo();
    if (mounted) {
      setState(() {
        _bleInfo = info;
        _loadingBleInfo = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = widget.deviceProvider;
    final device = widget.device;

    if (!dp.isConnected && !_sheetAutoClosed) {
      _sheetAutoClosed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
          Navigator.of(context).maybePop();
        }
      });
    }
    if (dp.isConnected && _sheetAutoClosed) {
      _sheetAutoClosed = false;
    }

    final hasFs = dp.hasFs || (dp.connectedDevice?.hasFs ?? false) || device.hasFs;
    final hasOta = dp.hasOta;
    final isUserMode = dp.isUserMode;

    int expectedTabCount = 2;
    if (hasFs && !isUserMode) expectedTabCount++;
    if (hasOta && !isUserMode) expectedTabCount++;

    if (_tabController == null || _tabController!.length != expectedTabCount) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabController = TabController(
        length: expectedTabCount,
        initialIndex: oldIndex.clamp(0, expectedTabCount - 1),
        vsync: this,
      );
      _tabCount = expectedTabCount;
    }

    final tabs = <Tab>[];
    final tabWidgets = <Widget>[];

    tabs.add(const Tab(text: 'INFO'));
    tabWidgets.add(InfoTabContent(device: device, deviceProvider: dp, bleInfo: _bleInfo, loadingBleInfo: _loadingBleInfo));

    tabs.add(const Tab(text: 'SETTINGS'));
    tabWidgets.add(SettingsTabContent(deviceProvider: dp));

    if (hasFs && !isUserMode) {
      tabs.add(const Tab(text: 'FILESYSTEM'));
      tabWidgets.add(FsTabContent(deviceProvider: dp));
    }

    if (hasOta && !isUserMode) {
      tabs.add(const Tab(text: 'FIRMWARE'));
      tabWidgets.add(FirmwareTabContent(device: device, deviceProvider: dp));
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Transform.translate(
        offset: const Offset(0, -18),
        child: Column(
          children: [
            TabBar(
              controller: _tabController!,
              indicatorColor: context.tokens.primary,
              labelColor: context.tokens.onSurface,
              unselectedLabelColor: context.tokens.onSurface.withValues(alpha: 0.54),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1),
              tabs: tabs,
            ),
            Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
            Expanded(
              child: TabBarView(controller: _tabController!, children: tabWidgets),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Shared Auth Dialog -------------------------------------------------------

Future<bool> _showAuthDialog(
  BuildContext context,
  DeviceInfo device,
  DeviceProvider dp,
) async {
  bool obscure = true;
  bool loading = false;
  bool remember = true;
  String? error;
  String password = '';
  bool _autoPopHandled = false;

  final saved = await SecureStorageService.loadPassword(device.id);
  if (saved != null && saved.isNotEmpty) {
    password = saved;
  }

  if (!context.mounted) return false;

  final success = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
          return ListenableBuilder(
            listenable: dp,
            builder: (context, _) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          // Watch the per-device provider for auth state changes
          // dp is the per-device DeviceProvider passed to the dialog
          if (dp.isAuthenticated && !_autoPopHandled) {
            _autoPopHandled = true;
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
              _autoPopHandled = true;
              if (remember) {
                await SecureStorageService.savePassword(device.id, pwd);
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
            backgroundColor: context.tokens.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.lock_rounded, color: context.tokens.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(device.displayName.toUpperCase(),
                        style: GoogleFonts.exo2(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: context.tokens.onSurface),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const _AuthCountdown(initialSeconds: 30),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(transportLabel(device.currentTransport),
                      style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11, fontWeight: FontWeight.w500)),
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
                    Text('Enter the device password to connect.',
                        style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                    const SizedBox(height: 16),
                    TextFormField(
                      onChanged: (v) => password = v,
                      initialValue: password,
                      obscureText: obscure,
                      autofocus: true,
                      style: GoogleFonts.martianMono(color: context.tokens.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.tokens.onSurface.withValues(alpha: 0.05),
                        hintText: 'Enter device password',
                        hintStyle: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: context.tokens.onSurface.withValues(alpha: 0.38)),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: error != null ? context.tokens.error : context.tokens.onSurface.withValues(alpha: 0.12))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: error != null ? context.tokens.error : context.tokens.onSurface.withValues(alpha: 0.12))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.tokens.primary.withValues(alpha: 0.5))),
                      ),
                      onFieldSubmitted: (_) => submit(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.error_outline_rounded, size: 14, color: context.tokens.error),
                        const SizedBox(width: 6),
                        Text(error!, style: TextStyle(color: context.tokens.error, fontSize: 12, fontWeight: FontWeight.w500)),
                      ]),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(
                        height: 28, width: 28,
                        child: Checkbox(value: remember, onChanged: (v) => setDialogState(() => remember = v ?? false), activeColor: context.tokens.primary, checkColor: context.tokens.onPrimary, side: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.24))),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setDialogState(() => remember = !remember),
                        child: Text('Remember password', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: context.tokens.primary, foregroundColor: context.tokens.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                onPressed: loading ? null : () => submit(),
                child: loading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.tokens.onPrimary))
                    : const Text('AUTHENTICATE'),
              ),
            ],
          );
        },
      );
    },
      );
    },
  );

  return success ?? false;
}

// -- Auth Countdown -----------------------------------------------------------

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
        color: (urgent ? context.tokens.error : context.tokens.warning).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (urgent ? context.tokens.error : context.tokens.warning).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: urgent ? context.tokens.error : context.tokens.warning),
          const SizedBox(width: 4),
          Text('${_secondsRemaining}s',
              style: TextStyle(color: urgent ? context.tokens.error : context.tokens.warning, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

Widget _buildSectionTag(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 8, height: 8, color: context.tokens.primary),
      const SizedBox(width: 12),
      Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.tokens.primary, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _TelemetryItem extends StatelessWidget {
  final String label;
  final String? iconName;
  final String value;
  final String unit;

  const _TelemetryItem({required this.label, this.iconName, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (iconName != null && kDesignerIcons.containsKey(iconName))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  kDesignerIcons[iconName]!,
                  color: context.tokens.primary,
                  size: 16,
                ),
              ),
            Text(value, style: GoogleFonts.exo2(color: context.tokens.primary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38), fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

// -- Paired Models List -------------------------------------------------------

class _PairedModelConnectionState {
  final PairedDevice device;
  final String status;
  final String? message;

  const _PairedModelConnectionState({required this.device, this.status = 'idle', this.message});

  _PairedModelConnectionState copyWith({PairedDevice? device, String? status, String? message}) {
    return _PairedModelConnectionState(device: device ?? this.device, status: status ?? this.status, message: message);
  }
}

class _PairedModelsList extends StatefulWidget {
  @override
  State<_PairedModelsList> createState() => _PairedModelsListState();
}

class _PairedModelsListState extends State<_PairedModelsList> {
  final Map<String, _PairedModelConnectionState> _connectionStates = {};
  final Map<String, _DeviceAvailability> _availabilityCache = {};
  Timer? _scanTimer;
  int _scanTick = 0;
  bool _hasCheckedCloud = false;

  bool _isTabActive() {
    try {
      final shell = StatefulNavigationShell.of(context);
      return shell.currentIndex == TabIndex.models.index;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isTabActive()) _onTabActivated();
    });
  }

  void _onTabActivated() {
    _startPeriodicScan();
    if (!_hasCheckedCloud) {
      _hasCheckedCloud = true;
      _checkCloudDevices();
    }
  }

  void _startPeriodicScan() {
    _scanTimer?.cancel();
    _scanTick = 0;
    _runAvailabilityCheck();
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isTabActive()) return;
      _scanTick++;
      _runAvailabilityCheck();
    });
  }

  void _stopPeriodicScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  Future<void> _runAvailabilityCheck() async {
    if (!mounted || !_isTabActive()) return;
    final runBle = _scanTick % 2 == 0;
    final ble = context.read<BleProvider>();
    final serialProv = context.read<SerialProvider>();
    final history = context.read<HistoryProvider>();
    final multiDevice = context.read<MultiDeviceProvider>();

    for (final device in history.pairedDevices) {
      if (!mounted) return;
      final uid = device.uid;
      // Skip devices that are currently connected
      if (multiDevice.isDeviceConnected(uid)) continue;
      final currentAvail = _availabilityCache[uid] ?? const _DeviceAvailability();

      if (device.wifiAddress != null && device.wifiAddress!.isNotEmpty) {
        await _probeWifi(device, currentAvail);
      }
      if (runBle && device.bleAddress != null && device.bleAddress!.isNotEmpty) {
        await _probeBle(device, currentAvail, ble);
      }
      if (_scanTick == 0 && device.serialAddress != null && device.serialAddress!.isNotEmpty) {
        await _probeSerial(device, currentAvail, serialProv);
      }
      if (!mounted) return;
    }
  }

  Future<void> _probeWifi(PairedDevice device, _DeviceAvailability current) async {
    final uri = Uri.tryParse(device.wifiAddress ?? '');
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) return;
    try {
      final socket = await Socket.connect(uri.host, uri.port, timeout: const Duration(seconds: 2));
      socket.destroy();
      _updateAvailability(device.uid, current.copyWith(wifiAvailable: true));
    } catch (_) {
      if (mounted) _updateAvailability(device.uid, current.copyWith(wifiAvailable: false));
    }
  }

  Future<void> _probeBle(PairedDevice device, _DeviceAvailability current, BleProvider ble) async {
    final address = device.bleAddress;
    if (address == null || address.isEmpty) return;
    try {
      final found = ble.devices.any((d) => d.id == address);
      _updateAvailability(device.uid, current.copyWith(bleAvailable: found));
    } catch (_) {
      if (mounted) _updateAvailability(device.uid, current.copyWith(bleAvailable: false));
    }
  }

  Future<void> _probeSerial(PairedDevice device, _DeviceAvailability current, SerialProvider serialProv) async {
    final address = device.serialAddress;
    if (address == null || address.isEmpty) return;
    try {
      await serialProv.startScan();
      if (!mounted) return;
      final found = serialProv.ports.any((p) => p.id == address);
      _updateAvailability(device.uid, current.copyWith(serialAvailable: found));
    } catch (_) {
      if (mounted) _updateAvailability(device.uid, current.copyWith(serialAvailable: false));
    }
  }

  Future<void> _checkCloudDevices() async {
    if (!mounted) return;
    final history = context.read<HistoryProvider>();
    final multiDevice = context.read<MultiDeviceProvider>();
    final cloudDevices = history.pairedDevices.where((d) => d.cloudAddress != null && d.cloudAddress!.isNotEmpty);
    for (final device in cloudDevices) {
      if (!mounted) return;
      if (multiDevice.isDeviceConnected(device.uid)) continue;
      final currentAvail = _availabilityCache[device.uid] ?? const _DeviceAvailability();
      final cloudAvailable = await _probeCloud(device);
      if (mounted) _updateAvailability(device.uid, currentAvail.copyWith(cloudAvailable: cloudAvailable));
    }
  }

  Future<bool> _probeCloud(PairedDevice device) async {
    final address = device.cloudAddress;
    final account = device.cloudAccount;
    if (address == null || address.isEmpty) return false;
    try {
      final ws = WebSocketService();
      if (account != null && account.isNotEmpty) {
        ws.account = account;
        final identity = CloudIdentityService();
        await identity.initialize();
        if (identity.hasIdentity) ws.identity = identity;
      }
      final completer = Completer<bool>();
      ws.onAuthOkDevices = (devices) {
        if (!completer.isCompleted) completer.complete(devices.contains(device.name));
      };
      ws.onAuthFailed = (_) {
        if (!completer.isCompleted) completer.complete(false);
      };
      try {
        await ws.connect(address).timeout(const Duration(seconds: 5));
        return await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => false);
      } finally {
        await ws.disconnect();
      }
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void _updateAvailability(String deviceId, _DeviceAvailability availability) {
    if (!mounted) return;
    setState(() {
      _availabilityCache[deviceId] = availability;
    });
  }

  @override
  void dispose() {
    _stopPeriodicScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final multiDevice = context.watch<MultiDeviceProvider>();
    final useWide = MediaQuery.of(context).size.width > 600;
    final allDevices = history.pairedDevices;
    final filteredDevices = allDevices.where((d) {
      final isCurrentlyConnected = multiDevice.devices.any((dp) {
        if (!dp.isConnected) {
          return false;
        }
        if (dp.connectedDevice?.id == d.uid) return true;

        final mapKey = multiDevice.deviceEntries
            .firstWhere((e) => e.$2 == dp, orElse: () => ('', dp))
            .$1;
        if (mapKey == d.uid) return true;

        if (d.bleAddress != null && d.bleAddress!.isNotEmpty) {
          if (dp.connectedDevice?.bleAddress == d.bleAddress) return true;
          if (dp.connectedDevice?.transportAddress == d.bleAddress) return true;
          if (mapKey == d.bleAddress) return true;
        }
        if (d.wifiAddress != null && d.wifiAddress!.isNotEmpty) {
          if (dp.connectedDevice?.wifiAddress == d.wifiAddress) return true;
          if (dp.connectedDevice?.transportAddress == d.wifiAddress) return true;
          if (mapKey == d.wifiAddress) return true;
        }
        if (d.serialAddress != null && d.serialAddress!.isNotEmpty) {
          if (dp.connectedDevice?.transportAddress == d.serialAddress) return true;
          if (mapKey == d.serialAddress) return true;
        }
        return false;
      });
      return !isCurrentlyConnected;
    }).toList();

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
    final connectionState = _connectionStates[device.uid] ?? _PairedModelConnectionState(device: device);
    final availability = _availabilityCache[device.uid];
    return _PairedModelCard(
      state: connectionState,
      availability: availability,
      onReconnect: () => _handleReconnect(device),
      onDismissError: () => _clearStatus(device.uid),
      onTap: () => _handleReconnect(device),
      onRemove: () => _confirmRemoveDevice(context, device),
      onContextMenu: (pos) => _showPairedContextMenu(context, pos, device, onConnect: () => _handleReconnect(device), onRemove: () => _confirmRemoveDevice(context, device)),
    );
  }

  Widget _buildLandscapeGrid(List<PairedDevice> devices) {
    final rows = <Widget>[];
    for (int i = 0; i < devices.length; i += 2) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildCard(devices[i])),
          const SizedBox(width: 12),
          if (i + 1 < devices.length)
            Expanded(child: _buildCard(devices[i + 1]))
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ));
    }
    return Column(children: rows);
  }

  void _updateStatus(String deviceId, String status, {String? message}) {
    setState(() {
      final current = _connectionStates[deviceId] ?? _PairedModelConnectionState(device: _findDevice(deviceId)!);
      _connectionStates[deviceId] = current.copyWith(status: status, message: message);
    });
  }

  void _clearStatus(String deviceId) {
    setState(() {
      _connectionStates.remove(deviceId);
    });
  }

  PairedDevice? _findDevice(String id) {
    return context.read<HistoryProvider>().pairedDevices.where((d) => d.uid == id).firstOrNull;
  }

  Future<Set<TransportType>> _checkAllAvailabilities({
    required PairedDevice device,
    required BleProvider ble,
    required SerialProvider serial,
  }) async {
    final results = <TransportType, bool>{};
    final futures = <Future<void>>[];

    final wifiAddr = device.wifiAddress ?? (device.type == 'wifi' ? device.uid : null);
    if (wifiAddr != null && wifiAddr.isNotEmpty) {
      futures.add(Future(() async {
        final uri = Uri.tryParse(wifiAddr);
        if (uri != null && (uri.scheme == 'ws' || uri.scheme == 'wss')) {
          try {
            final socket = await Socket.connect(uri.host, uri.port, timeout: const Duration(seconds: 2));
            socket.destroy();
            results[TransportType.wifi] = true;
            return;
          } catch (_) {}
        }
        results[TransportType.wifi] = false;
      }));
    }

    final bleAddr = device.bleAddress ?? (device.type == 'ble' ? device.uid : null);
    if (bleAddr != null && bleAddr.isNotEmpty) {
      futures.add(Future(() async {
        await ble.startScan();
        await Future.delayed(const Duration(milliseconds: 2500));
        await ble.stopScan();
        results[TransportType.ble] = ble.devices.any((d) => d.id == bleAddr);
      }));
    }

    final serialAddr = device.serialAddress ?? (device.type == 'serial' ? device.uid : null);
    if (serialAddr != null && serialAddr.isNotEmpty) {
      futures.add(Future(() async {
        await serial.startScan();
        results[TransportType.serial] = serial.ports.any((p) => p.id == serialAddr);
      }));
    }

    await Future.wait(futures);
    return results.entries.where((e) => e.value).map((e) => e.key).toSet();
  }

  Future<void> _handleReconnect(PairedDevice device) async {
    final console = context.read<ConsoleProvider>();
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    final multiDevice = context.read<MultiDeviceProvider>();

    _updateStatus(device.uid, 'scanning', message: 'Scanning...');
    console.log('RECONNECTING: ${device.name}', level: ConsoleLogLevel.info);

    final seen = <String>{};
    CloudIdentityService? cloudIdentity;
    if (device.cloudAccount != null && device.cloudAccount!.isNotEmpty) {
      final id = CloudIdentityService();
      await id.initialize();
      if (id.hasIdentity && id.account == device.cloudAccount) {
        cloudIdentity = id;
      }
    }

    final attempts = <_ReconnectAttempt>[];

    void addIf(String key, String label, String? address, TransportType type, TransportService Function() factory) {
      if (address == null || address.isEmpty || seen.contains(key)) return;
      seen.add(key);
      attempts.add(_ReconnectAttempt(label: label, type: type, address: address, makeService: factory));
    }

    final effectiveBle = device.bleAddress ?? (device.type == 'ble' ? device.uid : null);
    final effectiveWifi = device.wifiAddress ?? (device.type == 'wifi' ? device.uid : null);
    final effectiveSerial = device.serialAddress ?? (device.type == 'serial' ? device.uid : null);

    if (device.lastUsedTransport == 'wifi') addIf('wifi', 'WiFi', effectiveWifi, TransportType.wifi, () => WebSocketService());
    if (device.lastUsedTransport == 'ble') addIf('ble', 'BLE', effectiveBle, TransportType.ble, () => BleTransport(ble.bleService));
    if (device.lastUsedTransport == 'cloud' && cloudIdentity != null) { final ci = cloudIdentity; addIf('cloud', 'Cloud', device.cloudAddress, TransportType.cloud, () { final ws = WebSocketService()..account = ci.account..identity = ci; return ws; }); }
    if (device.lastUsedTransport == 'serial') addIf('serial', 'Serial', effectiveSerial, TransportType.serial, () => serial.serialService);

    addIf('wifi', 'WiFi', effectiveWifi, TransportType.wifi, () => WebSocketService());
    addIf('ble', 'BLE', effectiveBle, TransportType.ble, () => BleTransport(ble.bleService));
    addIf('serial', 'Serial', effectiveSerial, TransportType.serial, () => serial.serialService);

    if (cloudIdentity != null && device.cloudAddress != null && device.cloudAddress!.isNotEmpty) {
      final ci = cloudIdentity;
      addIf('cloud', 'Cloud', device.cloudAddress, TransportType.cloud, () { final ws = WebSocketService()..account = ci.account..identity = ci; return ws; });
    }

    if (attempts.isEmpty) {
      TransportService Function() fallbackService;
      TransportType fallbackType;
      String? fallbackAddr;
      if (device.type == 'ble') {
        fallbackService = () => BleTransport(ble.bleService);
        fallbackType = TransportType.ble;
        fallbackAddr = device.bleAddress ?? device.uid;
      } else if (device.type == 'wifi') {
        fallbackService = () => WebSocketService();
        fallbackType = TransportType.wifi;
        fallbackAddr = device.wifiAddress ?? device.uid;
      } else {
        fallbackService = () => serial.serialService;
        fallbackType = TransportType.serial;
        fallbackAddr = device.serialAddress ?? device.uid;
      }
      final ok = await _tryConnect(device: device, label: fallbackType.name, type: fallbackType, address: fallbackAddr, makeService: fallbackService, multiDevice: multiDevice, console: console);
      if (!ok && mounted) {
        console.log('RECONNECT FAILED: "${device.name}" is not reachable.', level: ConsoleLogLevel.error);
        _updateStatus(device.uid, 'failed', message: 'Device is offline or out of range.');
      }
      return;
    }

    _updateStatus(device.uid, 'connecting', message: 'Connecting...');

    // Try each transport in priority order (last used transport first)
    for (final attempt in attempts) {
      if (!mounted) return;
      final ok = await _tryConnect(
        device: device,
        label: attempt.label,
        type: attempt.type,
        address: attempt.address,
        makeService: attempt.makeService,
        multiDevice: multiDevice,
        console: console,
      );
      if (ok) return;
    }

    if (!mounted) return;
    console.log('RECONNECT FAILED: "${device.name}" is not reachable on any available transport.', level: ConsoleLogLevel.error);
    _updateStatus(device.uid, 'failed', message: 'Not reachable on any transport.');
  }

  Future<bool> _tryConnect({
    required PairedDevice device,
    required String label,
    required TransportType type,
    required String address,
    required TransportService Function() makeService,
    required MultiDeviceProvider multiDevice,
    required ConsoleProvider console,
  }) async {
    if (!mounted) return false;
    _updateStatus(device.uid, 'connecting', message: 'Connecting via $label...');

    final info = DeviceInfo(
      id: device.uid,
      name: device.name,
      rssi: 0,
      hasFs: device.hasFs,
      bleAddress: type == TransportType.ble ? address : (device.bleAddress ?? (device.type == 'ble' ? device.uid : null)),
      wifiAddress: type == TransportType.wifi ? address : (device.wifiAddress ?? (device.type == 'wifi' ? device.uid : null)),
      transportAddress: address,
      currentTransport: type,
    );

    await multiDevice.connectDevice(
      device: info,
      transport: makeService(),
    );

    if (!mounted) return false;
    if (multiDevice.isDeviceConnected(device.uid)) {
      console.log('RECONNECTED: ${device.name} via $label', level: ConsoleLogLevel.success);
      _updateStatus(device.uid, 'connected', message: 'Connected via $label!');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _clearStatus(device.uid);
      });
      return true;
    }
    return false;
  }
}

class _ReconnectAttempt {
  final String label;
  final TransportType type;
  final String address;
  final TransportService Function() makeService;
  const _ReconnectAttempt({required this.label, required this.type, required this.address, required this.makeService});
}

class _PairedModelCard extends StatelessWidget {
  final _PairedModelConnectionState state;
  final _DeviceAvailability? availability;
  final VoidCallback onReconnect;
  final VoidCallback onDismissError;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final void Function(Offset?)? onContextMenu;

  const _PairedModelCard({required this.state, this.availability, required this.onReconnect, required this.onDismissError, this.onTap, this.onRemove, this.onContextMenu});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final device = state.device;
    final connectionIcon = device.type == 'ble' ? Icons.bluetooth_rounded : device.type == 'wifi' ? Icons.wifi_rounded : Icons.usb_rounded;
    final status = state.status;
    final isBusy = status == 'scanning' || status == 'connecting';
    final isFailed = status == 'failed';

    final a = availability;
    Color badgeColor;
    if (a == null) {
      badgeColor = tokens.primary.withValues(alpha: 0.7);
    } else if (a.anyAvailable == true) {
      badgeColor = tokens.success;
    } else if (a.anyAvailable == false) {
      badgeColor = tokens.onSurface.withValues(alpha: 0.38);
    } else {
      badgeColor = tokens.onSurface.withValues(alpha: 0.54);
    }

    final iconName = device.deviceIcon;
    final deviceIconData = iconName != null && iconName.isNotEmpty && kDesignerIcons.containsKey(iconName) ? kDesignerIcons[iconName]! : null;

    Widget trailingWidget;
    if (isBusy) {
      trailingWidget = const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (isFailed) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.replay_rounded, size: 18, color: tokens.error), visualDensity: VisualDensity.compact, constraints: const BoxConstraints(), onPressed: onReconnect),
          IconButton(icon: Icon(Icons.close_rounded, size: 14, color: tokens.error), visualDensity: VisualDensity.compact, constraints: const BoxConstraints(), onPressed: onDismissError),
        ],
      );
    } else {
      trailingWidget = PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, size: 18, color: tokens.onSurface.withValues(alpha: 0.5)),
        offset: const Offset(-120, 0),
        color: tokens.base300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder: (context) => [_menuItem('CONNECT'), _menuItem('REMOVE')],
        onSelected: (value) {
          if (value == 'CONNECT' && onTap != null) onTap!();
          if (value == 'REMOVE' && onRemove != null) onRemove!();
        },
      );
    }

    return ModelCard(
      onTap: onTap,
      trailing: trailingWidget,
      onLongPress: () => onContextMenu?.call(null),
      onSecondaryTap: (pos) => onContextMenu?.call(pos),
      leading: ModelCard.standardLeading(
        context: context,
        icon: deviceIconData ?? connectionIcon,
        badge: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(color: context.tokens.surface, borderRadius: BorderRadius.circular(3)),
          child: Center(child: Icon(connectionIcon, size: 12, color: badgeColor)),
        ),
      ),
      title: ModelCard.standardTitle((device.configName?.isNotEmpty == true ? device.configName! : device.name)),
      subtitle: state.message != null
          ? ModelCard.standardSubtitle(context, state.message!)
          : device.description?.isNotEmpty == true
              ? ModelCard.standardSubtitle(context, device.description!.toUpperCase())
              : const SizedBox.shrink(),
    );
  }
}

void _showPairedContextMenu(BuildContext context, Offset? position, PairedDevice device, {required VoidCallback onConnect, required VoidCallback onRemove}) {
  final tokens = context.tokens;
  showMenu<String>(
    context: context,
    position: position != null ? RelativeRect.fromLTRB(position.dx - 80, position.dy, 0, 0) : const RelativeRect.fromLTRB(100, 120, 0, 0),
    items: [_menuItem('CONNECT'), _menuItem('REMOVE')],
    color: tokens.base300,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ).then((value) {
    if (value == 'CONNECT') onConnect();
    if (value == 'REMOVE') onRemove();
  });
}

void _confirmRemoveDevice(BuildContext context, PairedDevice device) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.tokens.base300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Remove Model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      content: Text('Are you sure you want to remove ${device.configName?.isNotEmpty == true ? device.configName! : device.name}? This will delete all saved configuration for this device.',
          style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.7), fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('CANCEL', style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38)))),
        TextButton(
          onPressed: () {
            context.read<HistoryProvider>().removeDevice(device.uid);
            SecureStorageService.deletePassword(device.uid);
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Model removed'), duration: Duration(seconds: 2)));
          },
          child: const Text('REMOVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    ),
  );
}

PopupMenuItem<String> _menuItem(String label) {
  return PopupMenuItem<String>(value: label, height: 32, child: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)));
}

class _DeviceIconWidget extends StatelessWidget {
  final String? deviceIcon;
  final IconData fallbackIcon;
  final double size;
  final double iconSize;

  const _DeviceIconWidget({required this.deviceIcon, required this.fallbackIcon, required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final iconData = deviceIcon != null && deviceIcon!.isNotEmpty && kDesignerIcons.containsKey(deviceIcon) ? kDesignerIcons[deviceIcon!]! : null;
    return Container(
      padding: const EdgeInsets.all(4),
      width: size, height: size,
      decoration: BoxDecoration(color: context.tokens.base200, borderRadius: BorderRadius.circular(4)),
      child: Icon(iconData ?? fallbackIcon, color: context.tokens.primary, size: iconSize),
    );
  }
}
