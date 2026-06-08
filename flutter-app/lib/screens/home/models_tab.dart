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
import '../../models/console_entry.dart';
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

// ── Active Link Section ──────────────────────────────────────────────────────

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
                child: Icon(Icons.local_shipping_rounded,
                    size: 160, color: Colors.white.withValues(alpha: 0.03)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(device),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1, color: Colors.white12),
                    ),
                    _telemetryRow(deviceProvider, device),
                    const SizedBox(height: 24),
                    _buildActionRow(context, deviceProvider, device),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow(DeviceInfo device) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            border: Border.all(
                color: AppColors.brandOrange.withValues(alpha: 0.3)),
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
                  Text('TELEMETRY_LIVE',
                      style: GoogleFonts.inter(
                          color: AppColors.connected,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1.0)),
                  const SizedBox(width: 8),
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.connected,
                          shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(height: 4),
              Text(device.displayName.toUpperCase(),
                  style: GoogleFonts.exo2(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('6X6_OFF-ROAD_CHASSIS',
                      style: TextStyle(
                          color: AppColors.brandOrange.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: AppColors.brandOrange.withValues(alpha: 0.3)),
                    ),
                    child: const Text('UNIT 02',
                        style: TextStyle(
                            color: AppColors.brandOrange,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _telemetryRow(DeviceProvider dp, DeviceInfo device) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _TelemetryItem(
            label: 'LATENCY',
            value: dp.latencyMs?.toString() ?? '--',
            unit: 'ms'),
        _TelemetryItem(
            label: 'SIGNAL',
            value: (dp.rssi ?? device.rssi) != 0
                ? '${dp.rssi ?? device.rssi}'
                : '--',
            unit: 'dBm'),
      ],
    );
  }

  Widget _buildActionRow(
      BuildContext context, DeviceProvider dp, DeviceInfo device) {
    const segmentHeight = 52.0;
    const borderColor = Colors.white24;

    return Container(
      height: segmentHeight,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildSegment(
              icon: Icons.tune_rounded,
              onTap: () => _showDeviceInfoSheet(context, dp, device),
              isFirst: true,
              height: segmentHeight),
          _verticalDivider(segmentHeight),
          Expanded(
            child: _buildSegment(
                label: 'OPEN_CONTROLLER',
                onTap: () => context.go('/control'),
                height: segmentHeight),
          ),
          _verticalDivider(segmentHeight),
          _buildSegment(
              icon: Icons.link_off_rounded,
              onTap: () => dp.disconnect(),
              isLast: true,
              height: segmentHeight),
        ],
      ),
    );
  }

  Widget _buildSegment({
    IconData? icon,
    String? label,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: Material(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? const Radius.circular(5) : Radius.zero,
          bottomLeft: isFirst ? const Radius.circular(5) : Radius.zero,
          topRight: isLast ? const Radius.circular(5) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(5) : Radius.zero,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(5) : Radius.zero,
            bottomLeft: isFirst ? const Radius.circular(5) : Radius.zero,
            topRight: isLast ? const Radius.circular(5) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(5) : Radius.zero,
          ),
          hoverColor: AppColors.brandOrange.withValues(alpha: 0.15),
          highlightColor: AppColors.brandOrange.withValues(alpha: 0.25),
          child: Center(
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 20)
                : Text(label ?? '',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 13,
                        color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Container _verticalDivider(double height) {
    return Container(width: 1, height: height, color: Colors.white12);
  }

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
    final hasFs = widget.device.hasFs;
    final hasOta = dp.hasOta;
    _tabCount = 1; // Info always present
    if (hasFs) _tabCount++;
    if (hasOta) _tabCount++;
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

    if (!showTabs) {
      // Only Info — no tabs
      return _InfoTabContent(
        device: device,
        bleInfo: _bleInfo,
        loadingBleInfo: _loadingBleInfo,
      );
    }

    // Build tabs list
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
          SizedBox(
            width: 200,
            child: TabBar(
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

  Future<void> _selectAndUpdate() async {
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

    _startUpload(firmware);
  }

  Future<void> _startUpload(Uint8List firmware) async {
    final dp = context.read<DeviceProvider>();
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
    });

    try {
      await dp.uploadFirmware(firmware, onProgress: (received, total) {
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
                onPressed: _selectAndUpdate,
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
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
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

// ── Shared bottom widgets ───────────────────────────────────────────────────

Widget _buildSectionTag(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
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

class _PairedModelsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
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
        ...filteredDevices.map((device) {
          final connectionIcon = device.type == 'ble'
              ? Icons.bluetooth_rounded
              : Icons.usb_rounded;

          return Card(
            color: Colors.white.withValues(alpha: 0.05),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(connectionIcon,
                    color: AppColors.brandOrange.withValues(alpha: 0.7)),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (device.configName?.isNotEmpty == true
                            ? device.configName!
                            : device.name)
                        .toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(width: 8),
                  Icon(connectionIcon,
                      size: 14,
                      color: AppColors.brandOrange.withValues(alpha: 0.5)),
                ],
              ),
              subtitle: Text(
                device.description?.isNotEmpty == true
                    ? device.description!
                    : 'NO_DESCRIPTION_PROVIDED',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white38),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _handleReconnect(context, device),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _handleReconnect(
      BuildContext context, PairedDevice device) async {
    final console = context.read<ConsoleProvider>();
    final ble = context.read<BleProvider>();
    final serial = context.read<SerialProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    console.log('RE-INITIALIZING SOURCE: ${device.type.toUpperCase()}',
        level: ConsoleLogLevel.info);

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
      if (!context.mounted) return;
      console.log(
          'RECONNECT FAILED: Device "${device.name}" is not reachable.',
          level: ConsoleLogLevel.error);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ble.errorMessage ?? 'Device is offline or out of range.'),
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
      if (!context.mounted) return;
      if (deviceProvider.isConnected) {
        console.log('RESYNC SUCCESSFUL: ${device.name}',
            level: ConsoleLogLevel.success);
      } else {
        final error = deviceProvider.errorMessage ?? 'Connection failed';
        console.log('RESYNC FAILED: $error', level: ConsoleLogLevel.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $error'),
              backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      console.log('RUNTIME ERROR: $e', level: ConsoleLogLevel.error);
    }
  }
}

// ── Interactive Demo Section ─────────────────────────────────────────────────

class _InteractiveDemoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      _DemoModelTile(
          icon: Icons.widgets_rounded,
          demoId: 'WIDGETS_DEMO',
          title: 'WIDGETS_DEMO',
          subtitle: 'Explore all available widget types'),
      _DemoModelTile(
          icon: Icons.sports_esports_rounded,
          demoId: 'RC_CONTROLLER',
          title: 'RC_CONTROLLER',
          subtitle: 'Simulated remote control interface'),
      _DemoModelTile(
          icon: Icons.dashboard_rounded,
          demoId: 'IOT_DASHBOARD',
          title: 'IOT_DASHBOARD',
          subtitle: 'IoT monitoring and control panel'),
    ]);
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.brandOrange),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(width: 8),
            const Icon(Icons.wifi_tethering_rounded,
                size: 14, color: AppColors.brandOrange),
          ],
        ),
        subtitle: Text(subtitle,
            style: Theme.of(context).textTheme.labelSmall),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () async {
          final dp = context.read<DeviceProvider>();
          await dp.loadDemo(demoId);
          if (context.mounted) context.go('/control');
        },
      ),
    );
  }
}
