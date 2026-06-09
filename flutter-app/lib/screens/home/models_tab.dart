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

class _ActiveLinkSection extends StatefulWidget {
  @override
  State<_ActiveLinkSection> createState() => _ActiveLinkSectionState();
}

class _ActiveLinkSectionState extends State<_ActiveLinkSection> {
  bool _authDialogShown = false;

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
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
        _buildConnectedCard(context, deviceProvider, device),
      ],
    );
  }

  Widget _buildConnectedCard(
      BuildContext context, DeviceProvider dp, DeviceInfo device) {
    return Card(
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
                _telemetryRow(dp, device),
                const SizedBox(height: 24),
                _buildActionRow(context, dp, device),
              ],
            ),
          ),
        ],
      ),
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
    const buttonHeight = 52.0;
    const borderRadius = 6.0;

    return Row(
      children: [
        // Config button (icon only)
        _buildButton(
          icon: Icons.tune_rounded,
          onTap: () => _showDeviceInfoSheet(context, dp, device),
          height: buttonHeight,
          borderRadius: borderRadius,
        ),
        const SizedBox(width: 8),
        // Open Controller button (text, fills remaining space)
        Expanded(
          child: _buildButton(
            label: 'OPEN_CONTROLLER',
            onTap: () => context.go('/control'),
            height: buttonHeight,
            borderRadius: borderRadius,
          ),
        ),
        const SizedBox(width: 8),
        // Disconnect button (icon only)
        _buildButton(
          icon: Icons.link_off_rounded,
          onTap: () => dp.disconnect(),
          height: buttonHeight,
          borderRadius: borderRadius,
        ),
      ],
    );
  }

  Widget _buildButton({
    IconData? icon,
    String? label,
    required VoidCallback? onTap,
    required double height,
    required double borderRadius,
  }) {
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
        child: icon != null
            ? Icon(icon, size: 20)
            : Text(label ?? '',
                style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 13,
                    color: isDisconnect ? Colors.white : Colors.black)),
      ),
    );
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
          // ── Device Settings (NVS-editable) ──────────────────
          // Device Settings is admin-only — hide in user mode
          if (dp.isUserMode) ...[
            _AdminRequiredPlaceholder(
              message: 'Admin access required to edit device settings',
            ),
          ] else ...[
            _DeviceSettingsSection(device: device),
          ],
          // ── Authenticate (user mode only) + Remove Device ──
          if (dp.isUserMode && !isDemo) ...[
            _AdminAccessButton(device: device),
            const SizedBox(height: 24),
          ],
          if (!isDemo) ...[
            _RemoveDeviceButton(device: device),
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
                          Text('Clear NVS config + entire flash after OTA',
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

// ── Admin Access Button (opens shared auth dialog in admin mode) ───────────

class _AdminAccessButton extends StatelessWidget {
  final DeviceInfo device;
  const _AdminAccessButton({required this.device});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          foregroundColor: Colors.orange,
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
        label: Text('AUTHENTICATE AS ADMIN',
            style: GoogleFonts.changa(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 12)),
        onPressed: () => _showAuthDialog(context, device, isAdminAuth: true),
      ),
    );
  }
}

// ── Remove Device Button ──────────────────────────────────────────────────

class _RemoveDeviceButton extends StatelessWidget {
  final DeviceInfo device;
  const _RemoveDeviceButton({required this.device});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: Text('REMOVE DEVICE',
            style: GoogleFonts.changa(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 12)),
        onPressed: () => _confirmRemove(context),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final dp = context.read<DeviceProvider>();
    final history = context.read<HistoryProvider>();
    final deviceId = device.id;
    final deviceName = device.displayName;

    // Confirm dialog
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

    // Disconnect
    await dp.disconnect();
    
    // Remove from paired devices
    history.removeDevice(deviceId);
    
    // Close the bottom sheet
    if (context.mounted) {
      Navigator.of(context).maybePop();
    }
  }
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

// ── Admin Required Placeholder ──────────────────────────────────────────────

class _AdminRequiredPlaceholder extends StatelessWidget {
  final String message;
  const _AdminRequiredPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      width: double.infinity,
      child: Row(children: [
        Icon(Icons.lock_rounded, size: 20, color: Colors.white38),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Device Settings Section (NVS-editable name/desc/password) ────────────

class _DeviceSettingsSection extends StatefulWidget {
  final DeviceInfo device;
  const _DeviceSettingsSection({required this.device});

  @override
  State<_DeviceSettingsSection> createState() => _DeviceSettingsSectionState();
}

class _DeviceSettingsSectionState extends State<_DeviceSettingsSection> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _pwdCtrl;
  late TextEditingController _adminPwdCtrl;
  bool _saving = false;
  bool _pwdVisible = false;
  bool _adminPwdVisible = false;

  @override
  void initState() {
    super.initState();
    final dp = context.read<DeviceProvider>();
    _nameCtrl = TextEditingController(text: dp.configName ?? '');
    _descCtrl = TextEditingController(text: dp.description ?? '');
    _pwdCtrl = TextEditingController();
    _adminPwdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _pwdCtrl.dispose();
    _adminPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final isDemo = widget.device.id.startsWith('demo_');
    if (isDemo) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DEVICE SETTINGS',
            style: TextStyle(
                color: AppColors.brandOrange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontFamily: 'monospace')),
        const SizedBox(height: 12),
        _settingsField('NAME', _nameCtrl),
        const SizedBox(height: 8),
        _settingsField('DESCRIPTION', _descCtrl, maxLines: 2),
        const SizedBox(height: 8),
        _pwdField(),
        const SizedBox(height: 8),
        _adminPwdField(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : Text('SAVE',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _factoryReset,
            child: Text('FACTORY RESET',
                style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _settingsField(String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.jetBrainsMono(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: AppColors.brandOrange.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pwdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PASSWORD (leave empty to clear)',
            style: TextStyle(
                color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _pwdCtrl,
          obscureText: !_pwdVisible,
          style: GoogleFonts.jetBrainsMono(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: Icon(
                  _pwdVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                  color: Colors.white38),
              onPressed: () => setState(() => _pwdVisible = !_pwdVisible),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: AppColors.brandOrange.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _adminPwdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('ADMIN PASSWORD (leave empty to clear)',
              style: TextStyle(
                  color: AppColors.brandOrange.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Icon(Icons.admin_panel_settings_outlined,
              size: 12, color: AppColors.brandOrange.withValues(alpha: 0.5)),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: _adminPwdCtrl,
          obscureText: !_adminPwdVisible,
          style: GoogleFonts.jetBrainsMono(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: Icon(
                  _adminPwdVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                  color: Colors.white38),
              onPressed: () => setState(() => _adminPwdVisible = !_adminPwdVisible),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: AppColors.brandOrange.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: AppColors.brandOrange.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: AppColors.brandOrange.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final dp = context.read<DeviceProvider>();
    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    final adminPwd = _adminPwdCtrl.text.trim();

    final ok = await dp.sendSetConf(
      name: name.isNotEmpty ? name : null,
      description: desc.isNotEmpty ? desc : null,
      password: pwd,
      adminPassword: adminPwd,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Settings saved to device' : 'Failed to save settings'),
        backgroundColor: ok ? Colors.greenAccent : Colors.redAccent,
      ),
    );
  }

  Future<void> _factoryReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 32),
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

    final dp = context.read<DeviceProvider>();
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
    }
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
                color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
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
