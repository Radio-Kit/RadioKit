import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/device_info.dart';
import '../../services/esp_fs_service.dart';
import '../../services/raw_serial_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';

/// ESP32 Filesystem Browser and Manager.
///
/// Features:
///   - Browse directories on ESP32 SPIFFS/LittleFS
///   - Upload files from host computer
///   - Download files to host computer
///   - Delete files and directories
///   - Create directories
///   - View filesystem info (total/used/free space)
///
/// Protocol: Uses [EspFsService] over a raw serial connection.
class Esp32FilesystemScreen extends StatefulWidget {
  const Esp32FilesystemScreen({super.key});

  @override
  State<Esp32FilesystemScreen> createState() => _Esp32FilesystemScreenState();
}

class _Esp32FilesystemScreenState extends State<Esp32FilesystemScreen> {
  final RawSerialService _serial = RawSerialService();
  late final EspFsService _espFs;

  List<EspFsEntry> _entries = [];
  String _currentPath = '/';
  List<String> _breadcrumbs = ['/'];

  bool _connected = false;
  bool _connecting = false;
  bool _loading = false;
  String? _errorMessage;
  String? _statusMessage;

  DeviceInfo? _selectedPort;
  List<DeviceInfo> _ports = [];
  bool _scanning = false;

  // Filesystem info
  int _totalBytes = 0;
  int _usedBytes = 0;
  int _freeBytes = 0;
  String _fsType = '--';

  final TextEditingController _baudController =
      TextEditingController(text: '115200');
  final List<String> _baudRates = [
    '9600',
    '19200',
    '38400',
    '57600',
    '115200',
    '230400',
    '460800',
    '921600',
    '1000000',
  ];

  @override
  void initState() {
    super.initState();

    _espFs = EspFsService(
      writeFn: (data) => _serial.write(data),
      dataStream: _serial.dataStream,
    );
    _scanPorts();
  }

  @override
  void dispose() {
    _espFs.dispose();
    _serial.disconnect();
    _serial.dispose();
    _baudController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Port scanning
  // ---------------------------------------------------------------------------

  Future<void> _scanPorts() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _errorMessage = null;
    });

    try {
      final ports = <DeviceInfo>[];
      await for (final port in _serial.listPorts()) {
        ports.add(port);
      }
      if (mounted) {
        setState(() {
          _ports = ports;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Scan error: $e';
          _scanning = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Connect / Disconnect
  // ---------------------------------------------------------------------------

  Future<void> _toggleConnection() async {
    if (_connected) {
      await _serial.disconnect();
      if (mounted) {
        setState(() {
          _connected = false;
          _entries = [];
          _statusMessage = null;
        });
      }
      return;
    }

    if (_selectedPort == null) return;

    setState(() {
      _connecting = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final baud = int.tryParse(_baudController.text) ?? 115200;
      await _serial.connect(_selectedPort!.id, baudRate: baud);

      if (mounted) {
        setState(() {
          _connected = true;
          _connecting = false;
          _statusMessage = 'Connected — loading filesystem...';
        });
        _refreshDirectory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _errorMessage = 'Connection failed: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Filesystem operations
  // ---------------------------------------------------------------------------

  Future<void> _refreshDirectory() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = 'Listing ${_currentPath}...';
    });

    try {
      final entries = await _espFs.listDirectory(_currentPath);
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          _statusMessage =
              '${entries.length} entries in ${_currentPath}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'List error: $e';
          _statusMessage = null;
        });
      }
    }

    // Also try to refresh info
    _refreshInfo();
  }

  Future<void> _refreshInfo() async {
    try {
      final info = await _espFs.getInfo();
      if (info != null && mounted) {
        setState(() {
          _totalBytes = info['totalBytes'] as int? ?? 0;
          _usedBytes = info['usedBytes'] as int? ?? 0;
          _freeBytes = info['freeBytes'] as int? ?? 0;
          _fsType = info['fsType'] as String? ?? '--';
        });
      }
    } catch (_) {
      // Info is optional
    }
  }

  void _enterDirectory(EspFsEntry entry) {
    if (!entry.isDirectory) return;
    final newPath = _currentPath == '/'
        ? '/${entry.name}'
        : '$_currentPath/${entry.name}';
    setState(() {
      _currentPath = newPath;
      _breadcrumbs.add(entry.name);
      _entries = [];
    });
    _refreshDirectory();
  }

  void _navigateToBreadcrumb(int index) {
    if (index == 0) {
      setState(() {
        _currentPath = '/';
        _breadcrumbs.clear();
        _breadcrumbs.add('/');
        _entries = [];
      });
    } else {
      final path =
          '/' + _breadcrumbs.sublist(1, index + 1).join('/');
      setState(() {
        _currentPath = path;
        _breadcrumbs = [..._breadcrumbs.sublist(0, index + 1)];
        _entries = [];
      });
    }
    _refreshDirectory();
  }

  // ---------------------------------------------------------------------------
  // File operations
  // ---------------------------------------------------------------------------

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.pickFiles(
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) return;

      final remotePath = _currentPath == '/'
          ? '/$fileName'
          : '$_currentPath/$fileName';

      setState(() => _statusMessage = 'Uploading $fileName...');

      final res = await _espFs.writeFile(remotePath, bytes);
      if (mounted) {
        if (res.success) {
          setState(() => _statusMessage = 'Uploaded $fileName (${bytes.length} B)');
        } else {
          setState(() {
            _errorMessage = 'Upload failed: ${res.message}';
            _statusMessage = null;
          });
        }
        _refreshDirectory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Upload error: $e';
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _downloadFile(EspFsEntry entry, String path) async {
    if (entry.isDirectory) return;

    setState(() => _statusMessage = 'Downloading ${entry.name}...');

    try {
      final fileBytes = await _espFs.readFile(path);
      if (fileBytes != null && mounted) {
        // Prompt to save to a file
        final savePath = await FilePicker.saveFile(
          fileName: entry.name,
          bytes: fileBytes,
        );
        if (savePath != null && mounted) {
          setState(() => _statusMessage =
              'Downloaded ${entry.name} (${fileBytes.length} B)');
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Download failed: file is empty or not found';
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Download error: $e';
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _deleteEntry(EspFsEntry entry, String path) async {
    final isDir = entry.isDirectory;
    final label = isDir ? 'directory "${entry.name}"' : '"${entry.name}"';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirm Delete',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete $label?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.brandRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _statusMessage = 'Deleting ${entry.name}...');

    try {
      final EspFsResult res;
      if (isDir) {
        res = await _espFs.removeDirectory(path);
      } else {
        res = await _espFs.deleteFile(path);
      }

      if (mounted) {
        if (res.success) {
          setState(() => _statusMessage = 'Deleted $label');
        } else {
          setState(() {
            _errorMessage = 'Delete failed: ${res.message}';
            _statusMessage = null;
          });
        }
        _refreshDirectory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Delete error: $e';
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _createDirectory() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('New Directory',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'folder_name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final remotePath = _currentPath == '/'
        ? '/$name'
        : '$_currentPath/$name';

    setState(() => _statusMessage = 'Creating directory $name...');

    try {
      final res = await _espFs.createDirectory(remotePath);
      if (mounted) {
        if (res.success) {
          setState(() => _statusMessage = 'Created directory $name');
        } else {
          setState(() {
            _errorMessage = 'Create failed: ${res.message}';
            _statusMessage = null;
          });
        }
        _refreshDirectory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Create error: $e';
          _statusMessage = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: RadioKitAppBar(title: 'ESP32_FS'),
      body: Column(
        children: [
          _buildConnectionBar(),
          if (_connected) _buildInfoStrip(),
          if (_connected) _buildNavigationBar(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: _buildFileList()),
          if (_connected) _buildActionBar(),
          const Divider(height: 1, color: Colors.white10),
          _buildStatusBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Connection Bar
  // ---------------------------------------------------------------------------

  Widget _buildConnectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF181818),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DeviceInfo>(
                  value: _selectedPort,
                  isExpanded: true,
                  hint: const Text('Select port',
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
                  dropdownColor: const Color(0xFF222222),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  icon: _scanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(LucideIcons.chevronDown,
                          size: 16, color: Colors.white54),
                  items: _ports
                      .map((port) => DropdownMenuItem(
                            value: port,
                            child: Text(port.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (port) {
                    if (port != null) setState(() => _selectedPort = port);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _baudController.text,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF222222),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFamily: 'monospace'),
                  icon: Icon(LucideIcons.chevronDown,
                      size: 16, color: Colors.white54),
                  items: _baudRates
                      .map((rate) => DropdownMenuItem(
                            value: rate,
                            child: Text(rate,
                                style: const TextStyle(fontSize: 11)),
                          ))
                      .toList(),
                  onChanged: (rate) {
                    if (rate != null) {
                      _baudController.text = rate;
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _connected
                    ? AppColors.brandRed.withValues(alpha: 0.2)
                    : AppColors.connected.withValues(alpha: 0.2),
                foregroundColor:
                    _connected ? AppColors.brandRed : AppColors.connected,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _connected
                        ? AppColors.brandRed.withValues(alpha: 0.5)
                        : AppColors.connected.withValues(alpha: 0.5),
                  ),
                ),
              ),
              icon: _connecting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _connected ? LucideIcons.plugZap : LucideIcons.plug,
                      size: 16,
                    ),
              label: Text(
                _connecting ? '...' : _connected ? 'DISCONNECT' : 'CONNECT',
                style: GoogleFonts.changa(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: _connecting ? null : _toggleConnection,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Info Strip
  // ---------------------------------------------------------------------------

  Widget _buildInfoStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF121212),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brandOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _fsType,
              style: const TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: AppColors.brandOrange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_totalBytes > 0) ...[
            _InfoSegment(
              label: 'USED',
              value: '${(_usedBytes / 1024).toStringAsFixed(1)} KB',
              color: AppColors.brandOrange,
            ),
            const SizedBox(width: 12),
            _InfoSegment(
              label: 'FREE',
              value: '${(_freeBytes / 1024).toStringAsFixed(1)} KB',
              color: AppColors.connected,
            ),
            const SizedBox(width: 12),
            _InfoSegment(
              label: 'TOTAL',
              value: '${(_totalBytes / 1024).toStringAsFixed(1)} KB',
              color: Colors.white54,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation Bar
  // ---------------------------------------------------------------------------

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF111111),
      child: Row(
        children: [
          // Back button (only if not at root)
          if (_currentPath != '/')
            GestureDetector(
              onTap: () => _navigateToBreadcrumb(_breadcrumbs.length - 2 >= 0
                  ? _breadcrumbs.length - 2
                  : 0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white54),
              ),
            ),
          if (_currentPath != '/') const SizedBox(width: 8),
          // Breadcrumbs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_breadcrumbs.length, (i) {
                  final isLast = i == _breadcrumbs.length - 1;
                  return GestureDetector(
                    onTap: isLast ? null : () => _navigateToBreadcrumb(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: isLast
                            ? AppColors.brandOrange.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i == 0)
                            Icon(LucideIcons.home, size: 12, color: isLast ? AppColors.brandOrange : Colors.white38)
                          else
                            Text(
                              _breadcrumbs[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: isLast
                                    ? AppColors.brandOrange
                                    : Colors.white54,
                                fontWeight:
                                    isLast ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          if (i < _breadcrumbs.length - 1) ...[
                            const SizedBox(width: 2),
                            Icon(LucideIcons.chevronRight,
                                size: 12, color: Colors.white24),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: () => _refreshDirectory(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _loading ? LucideIcons.loader : LucideIcons.refreshCcw,
                size: 16,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // File List
  // ---------------------------------------------------------------------------

  Widget _buildFileList() {
    if (!_connected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.hardDrive, size: 56,
                  color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              Text(
                'ESP32 Filesystem',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect via USB Serial to browse files',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white24,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_loading && _entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.brandOrange, strokeWidth: 2),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.folderOpen, size: 48,
                  color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              Text(
                'Empty directory',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to create a folder or upload a file',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort: directories first, then files (alphabetical)
    final sorted = List<EspFsEntry>.from(_entries);
    sorted.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final path = _currentPath == '/'
            ? '/${entry.name}'
            : '$_currentPath/${entry.name}';
        return _FileEntryTile(
          entry: entry,
          path: path,
          onTap: () => _enterDirectory(entry),
          onDownload: () => _downloadFile(entry, path),
          onDelete: () => _deleteEntry(entry, path),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Action Bar
  // ---------------------------------------------------------------------------

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF181818),
      child: Row(
        children: [
          _ActionBtn(
            icon: LucideIcons.upload,
            label: 'UPLOAD',
            onTap: _uploadFile,
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: LucideIcons.folderPlus,
            label: 'NEW DIR',
            onTap: _createDirectory,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0xFF111111),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _connected ? AppColors.connected : Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage ?? (_connected ? 'Connected' : 'Disconnected'),
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: _statusMessage != null
                    ? Colors.white54
                    : _connected
                        ? AppColors.connected
                        : Colors.white38,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_errorMessage != null)
            GestureDetector(
              onTap: () => setState(() => _errorMessage = null),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.brandRed,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Sub-widgets
// ===========================================================================

class _FileEntryTile extends StatelessWidget {
  final EspFsEntry entry;
  final String path;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _FileEntryTile({
    required this.entry,
    required this.path,
    required this.onTap,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: entry.isDirectory ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: entry.isDirectory
                      ? AppColors.brandOrange.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  entry.isDirectory
                      ? (entry.name == '..'
                          ? LucideIcons.arrowUpFromLine
                          : LucideIcons.folder)
                      : _fileIcon(entry.name),
                  size: 18,
                  color: entry.isDirectory
                      ? AppColors.brandOrange
                      : Colors.white54,
                ),
              ),
              const SizedBox(width: 12),
              // Name + size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!entry.isDirectory)
                      Text(
                        entry.formattedSize,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
              if (!entry.isDirectory)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconBtn(
                      icon: LucideIcons.download,
                      color: AppColors.connected.withValues(alpha: 0.7),
                      onTap: onDownload,
                    ),
                    const SizedBox(width: 4),
                    _IconBtn(
                      icon: LucideIcons.trash2,
                      color: AppColors.brandRed.withValues(alpha: 0.7),
                      onTap: onDelete,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'json':
        return LucideIcons.fileJson;
      case 'html':
      case 'htm':
        return LucideIcons.fileType;
      case 'css':
        return LucideIcons.fileType;
      case 'js':
        return LucideIcons.fileType;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
        return LucideIcons.image;
      case 'txt':
      case 'md':
        return LucideIcons.fileText;
      case 'bin':
        return LucideIcons.binary;
      case 'gz':
      case 'zip':
      case 'tar':
        return LucideIcons.archive;
      default:
        return LucideIcons.file;
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandOrange.withValues(alpha: 0.1),
          foregroundColor: AppColors.brandOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
                color: AppColors.brandOrange.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.changa(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _InfoSegment extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
