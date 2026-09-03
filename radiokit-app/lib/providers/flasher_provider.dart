import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flserial/flserial.dart';
import 'package:flutter_esptool/flutter_esptool.dart';

import '../services/flserial_port_adapter.dart';
import '../models/firmware_bundle.dart';
import '../services/firmware_bundle_parser.dart';

/// State management for the Flasher tab.
///
/// Uses [FlserialPortAdapter] to bridge flserial's event-driven API into
/// [EspTransport], enabling proper DTR/RTS control on both Linux and Android.
class FlasherProvider extends ChangeNotifier {
  // ── flutter_esptool services ─────────────────────────────────
  EspTransport? _transport;
  ConnectionService? _connectionService;
  ChipDetectionService? _chipDetector;
  FlashService? _flashService;

  // ── Logging ─────────────────────────────────────────────────
  final List<String> _logEntries = [];
  bool _isLogExpanded = false;
  bool _isOperationActive = false;

  // ── Port scanning ────────────────────────────────────────────
  List<PortInfo> _availablePorts = [];
  bool _isScanning = false;
  Timer? _autoScanTimer;

  // ── Connection ───────────────────────────────────────────────
  bool _isConnected = false;
  String? _portName;
  int _baudRate = 115200;
  String? _errorMessage;

  // ── Chip info ────────────────────────────────────────────────
  EspConfig? _espConfig;
  EspChipInfo? _detectedChip;
  ChipInfo? _chipInfo;
  bool _isLoadingChipInfo = false;

  // ── Firmware Bundle ──────────────────────────────────────────
  FirmwareBundle? _selectedBundle;
  bool _eraseAll = false;

  // ── Flashing ─────────────────────────────────────────────────
  bool _isFlashing = false;
  double _flashProgress = 0.0;
  String _flashStatus = '';

  // ── Retained adapter reference for lifecycle management ──────
  FlserialPortAdapter? _adapter;

  /// The last successfully connected port ID, preserved for handoff
  /// to the RadioKit serial transport after flashing completes.
  String? get lastPortId => _portName;

  // ── Getters ──────────────────────────────────────────────────

  List<PortInfo> get availablePorts => List.unmodifiable(_availablePorts);
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get portName => _portName;
  int get baudRate => _baudRate;
  ChipInfo? get chipInfo => _chipInfo;
  EspChipInfo? get detectedChip => _detectedChip;
  bool get isLoadingChipInfo => _isLoadingChipInfo;
  FirmwareBundle? get selectedBundle => _selectedBundle;

  /// Backward-compatible adapter for UI/API status consumers.
  SelectedFirmware? get selectedFirmware {
    final b = _selectedBundle;
    if (b == null) return null;
    return SelectedFirmware(
      name: b.originalFileName ?? '${b.name} v${b.version}.zip',
      size: _formatBytes(b.totalBinaryBytes),
      path: b.originalFileName ?? 'bundle.zip',
      bytes: b.totalBinaryBytes,
      chipFamily: b.chipFamily,
      version: b.version,
      partsCount: b.parts.length,
    );
  }

  bool get eraseAll => _eraseAll;
  bool get isFlashing => _isFlashing;
  double get flashProgress => _flashProgress;
  String get flashStatus => _flashStatus;
  List<String> get logEntries => List.unmodifiable(_logEntries);
  bool get isLogExpanded => _isLogExpanded;
  bool get isOperationActive => _isOperationActive;
  String? get errorMessage => _errorMessage;

  // ── Port scanning ──────────────────────────────────────────────

  /// Scan for available serial ports using flserial's [FlSerial.availablePorts].
  Future<void> scanPorts() async {
    if (_isScanning) return;
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ports = await FlSerial.availablePorts();
      _availablePorts = ports.map((p) => PortInfo(
        id: p.path,
        name: p.path.split('/').last,
        description: p.description.isNotEmpty ? p.description : null,
      )).toList();
      if (_availablePorts.isEmpty) {
        _addLogEntry('No serial ports found.');
      } else {
        _addLogEntry('Found ${_availablePorts.length} port(s): '
            '${_availablePorts.map((p) => p.id).join(', ')}');
      }
    } catch (e) {
      _errorMessage = 'Failed to scan ports: $e';
      _addLogEntry('[ERROR] Scan failed: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Start periodic auto-scan that refreshes available ports every second.
  void startAutoScan() {
    if (_autoScanTimer != null || _isConnected || _isOperationActive) return;
    scanPorts();
    _autoScanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isConnected && !_isOperationActive && !_isLoadingChipInfo) {
        scanPorts();
      }
    });
  }

  /// Stop the periodic auto-scan.
  void stopAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  // ── Connection ─────────────────────────────────────────────────

  /// Enter ESP32 download mode via standard DTR/RTS transistor toggling.
  /// Standard ESP32 auto-reset circuit:
  /// Enter ROM download bootloader mode using esptool's USB-JTAG-Serial sequence.
  Future<void> _enterBootloaderMode() async {
    final adapter = _adapter;
    if (adapter == null) {
      _addLogEntry('[WARN] No adapter available for boot mode');
      _addLogEntry('Tip: Hold BOOT, tap RESET, release BOOT manually.');
      return;
    }

    _addLogEntry('Putting ESP32 into download mode...');

    try {
      // 1. Idle state (DTR=0, RTS=0)
      await adapter.setRts(false);
      await adapter.setDtr(false);
      await Future.delayed(const Duration(milliseconds: 100));

      // 2. Set IO0 (DTR=1, RTS=0)
      await adapter.setDtr(true);
      await adapter.setRts(false);
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Reset pulse (RTS=1, DTR=0)
      await adapter.setRts(true);
      await adapter.setDtr(false);
      await Future.delayed(const Duration(milliseconds: 100));

      // 4. Chip out of reset (DTR=0, RTS=0)
      await adapter.setDtr(false);
      await adapter.setRts(false);
      await Future.delayed(const Duration(milliseconds: 250));

      // 5. Flush stale boot logs from serial buffer
      await adapter.resetBuffers();
      await Future.delayed(const Duration(milliseconds: 100));

      _addLogEntry('Download mode engaged.');
    } catch (e) {
      _addLogEntry('[WARN] Auto boot mode: $e');
      _addLogEntry('Tip: For Native USB boards, hold BOOT, tap RESET, release BOOT.');
    }
  }

  /// Connect to the selected serial port using an [FlserialPortAdapter],
  /// enter bootloader mode, sync with the ESP32 ROM bootloader,
  /// and detect chip info.
  Future<void> connect(String portId) async {
    if (_adapter != null || _connectionService != null || _transport != null) {
      await disconnect();
    }
    stopAutoScan();
    _errorMessage = null;
    _isLoadingChipInfo = true;
    _isOperationActive = true;
    _isLogExpanded = true;
    _portName = portId;
    _addLogEntry('Connecting to $portId...');
    notifyListeners();

    try {
      final adapter = FlserialPortAdapter(portId);
      _adapter = adapter;
      _transport = EspTransport(serial: adapter);
      _connectionService = ConnectionService(_transport!);

      final config = EspConfig(
        portName: portId,
        initialBaudRate: 115200,
        flashBaudRate: 921600,
        syncRetries: 15,
        timeout: const Duration(milliseconds: 1000),
        resetMode: EspResetMode.none,
      );
      _espConfig = config;

      await _transport!.open(config);
      _addLogEntry('[OK] Port opened at 115200 baud');

      await _enterBootloaderMode();

      final syncResult = await _connectionService!.connect(config);
      final syncOk = syncResult.fold<bool>(
        (_) => true,
        (f) {
          _addLogEntry('[ERROR] Sync failed: ${f.message}');
          return false;
        },
      );

      if (!syncOk) {
        _addLogEntry('Could not synchronize with ESP32 bootloader.');
        _addLogEntry('Tip: If using ESP32-S3 Native USB, hold BOOT, tap RESET, release BOOT.');
        _errorMessage = 'Sync failed. Check connection and boot mode.';
        _isLoadingChipInfo = false;
        _isOperationActive = false;
        _isConnected = false;
        notifyListeners();
        return;
      }

      _addLogEntry('[OK] Synchronized with ESP32 ROM bootloader');
      await Future.delayed(const Duration(milliseconds: 200));

      _chipDetector = ChipDetectionService(_transport!);
      EspChipInfo? detectedChip;
      for (var attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) {
          _addLogEntry('[WARN] Chip detection attempt ${attempt + 1}...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
        final detectResult = await _chipDetector!.detect();
        if (detectResult.isSuccess) {
          detectedChip = (detectResult as Success<EspChipInfo>).value;
          break;
        }
        final f = (detectResult as Failure<EspChipInfo>).error;
        _addLogEntry('[WARN] Attempt ${attempt + 1}: ${f.message}');
      }

      _detectedChip = detectedChip;

      if (detectedChip != null) {
        _isConnected = true;
        notifyListeners();
        final info = detectedChip;
        _addLogEntry('Chip is ${info.description}');
        _addLogEntry('MAC: ${info.macAddress}');
        _baudRate = 115200;

        final flashBytes = info.flashSizeBytes ?? info.embeddedFlashBytes;
        final flashStr = flashBytes != null && flashBytes > 0
            ? '${_formatBytes(flashBytes)}${info.flashVendor != null ? " (${info.flashVendor})" : ""}'
            : 'Unknown';

        final psramBytes = info.psramCapacityBytes;
        final psramStr = psramBytes != null && psramBytes > 0
            ? '${_formatBytes(psramBytes)}${info.psramType != null ? " ${info.psramType}" : ""}'
            : (info.psramCapacityBytes != null ? 'None' : 'None');

        final chipModel = info.description;
        final revStr = info.chipRevision ?? 'v${_parseRevision(chipModel)}';

        if (flashBytes != null && flashBytes > 0) {
          _addLogEntry('Flash: $flashStr');
        }
        if (psramBytes != null && psramBytes > 0) {
          _addLogEntry('PSRAM: $psramStr');
        }

        _chipInfo = ChipInfo(
          model: chipModel,
          revision: revStr,
          mac: info.macAddress,
          flashSize: flashStr,
          psramSize: psramStr,
          cores: _coresForFamily(info.family),
        );
      } else {
        _addLogEntry('[ERROR] Chip detection failed after retries');
        _chipInfo = const ChipInfo(
          model: 'ESP (unidentified)',
          revision: '--',
          mac: '--',
          flashSize: '--',
          psramSize: '--',
          cores: '--',
        );
        _isConnected = true;
        notifyListeners();
        _baudRate = 115200;
      }

      _flashService = await _createFlashService();
      _addLogEntry('[OK] Device ready for flashing');
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _addLogEntry('[ERROR] $e');
      _isConnected = false;
    } finally {
      _isLoadingChipInfo = false;
      _isOperationActive = false;
      if (!_isConnected) {
        startAutoScan();
      }
      notifyListeners();
    }
  }

  /// Disconnect from the serial port and clean up all services.
  Future<void> disconnect() async {
    _addLogEntry('Disconnecting...');
    try {
      await _connectionService?.disconnect();
    } catch (_) {}
    try {
      await _transport?.close();
    } catch (_) {}
    _adapter?.dispose();
    _adapter = null;
    _transport = null;
    _connectionService = null;
    _chipDetector = null;
    _flashService = null;
    _isConnected = false;
    _portName = null;
    _chipInfo = null;
    _detectedChip = null;
    _selectedBundle = null;
    _flashProgress = 0.0;
    _flashStatus = '';
    _addLogEntry('Disconnected.');
    notifyListeners();
  }

  /// Release the serial port for RadioKit protocol handoff.
  Future<String?> handoffSerial() async {
    final port = _portName;
    await disconnect();
    _portName = port;
    notifyListeners();
    return port;
  }

  // ── Firmware Bundle Management ────────────────────────────────

  /// Open file picker and select a .zip firmware bundle.
  Future<void> selectFirmwareFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );
      if (result.isEmpty) return;

      final file = result.first;
      if (file.path == null) {
        _addLogEntry('[ERROR] Could not access the selected file.');
        return;
      }

      final bytes = await File(file.path!).readAsBytes();

      final bundle = FirmwareBundleParser.parseZip(bytes, fileName: file.name);

      _selectedBundle = bundle;
      _addLogEntry('Loaded bundle: ${bundle.name} v${bundle.version} '
          '(${bundle.chipFamily}, ${bundle.parts.length} parts, '
          '${_formatBytes(bundle.totalBinaryBytes)})');

      for (final p in bundle.parts) {
        _addLogEntry('  - ${p.path} @ 0x${p.offset.toRadixString(16).toUpperCase()} (${_formatBytes(p.size)})');
      }

      // Chip compatibility warning
      if (_detectedChip != null) {
        final compatible = FirmwareBundleParser.isChipFamilyCompatible(
          _detectedChip!.family,
          bundle.chipFamily,
        );
        if (!compatible) {
          _addLogEntry('[WARN] Chip mismatch: bundle is for ${bundle.chipFamily}, '
              'connected device is ${_detectedChip!.family.name}');
        }
      }

      notifyListeners();
    } on FirmwareBundleException catch (e) {
      _addLogEntry('[ERROR] Bundle validation failed: $e');
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _addLogEntry('[ERROR] File selection failed: $e');
      _errorMessage = '$e';
      notifyListeners();
    }
  }

  /// Directly set firmware bundle bytes from remote API / marketplace.
  void setSelectedBundleDirect({
    required Uint8List bytes,
    String? name,
  }) {
    final bundle = FirmwareBundleParser.parseZip(bytes, fileName: name);
    _selectedBundle = bundle;
    _addLogEntry('Bundle set via API: ${bundle.name} v${bundle.version} '
        '(${bundle.parts.length} parts, ${_formatBytes(bundle.totalBinaryBytes)})');
    notifyListeners();
  }

  void clearFirmwareSelection() {
    _selectedBundle = null;
    notifyListeners();
  }

  void setEraseAll(bool value) {
    _eraseAll = value;
    notifyListeners();
  }

  // ── Flashing ──────────────────────────────────────────────────

  /// Start the multi-part flashing operation.
  Future<void> startFlashing() async {
    final bundle = _selectedBundle;
    if (bundle == null || !_isConnected) return;
    if (_flashService == null) return;

    // Check chip compatibility
    if (_detectedChip != null) {
      final compatible = FirmwareBundleParser.isChipFamilyCompatible(
        _detectedChip!.family,
        bundle.chipFamily,
      );
      if (!compatible) {
        final msg = 'Target chip mismatch: bundle is for ${bundle.chipFamily} '
            'but connected chip is ${_detectedChip!.family.name}';
        _addLogEntry('[ERROR] $msg');
        _errorMessage = msg;
        notifyListeners();
        return;
      }
    }

    _isFlashing = true;
    _flashProgress = 0.0;
    _isOperationActive = true;
    _isLogExpanded = true;
    _addLogEntry('Preparing release binary (${bundle.parts.length} parts)...');
    notifyListeners();

    try {
      if (_eraseAll) {
        _flashStatus = 'Erasing flash memory...';
        _flashProgress = 0.0;
        _addLogEntry('Performing full chip erase (this may take 15–30s)...');
        notifyListeners();

        final eraseResult = await _flashService!.eraseFlash();
        final eraseOk = eraseResult.fold<bool>(
          (_) => true,
          (f) {
            _addLogEntry('[ERROR] Flash erase failed: ${f.message}');
            return false;
          },
        );

        if (!eraseOk) {
          _errorMessage = 'Full flash erase failed';
          _isFlashing = false;
          _isOperationActive = false;
          notifyListeners();
          return;
        }
        _addLogEntry('[OK] Flash erased completely (NVS, OTA slots, and LittleFS wiped).');
      }

      final mergedData = bundle.buildMergedImage();
      _addLogEntry(
          'Flashing unified binary (${_formatBytes(mergedData.length)} across ${bundle.parts.length} partitions)...');

      var lastNotify = DateTime.now();
      final params = FlashParameters(
        data: mergedData,
        offset: 0x0,
        compress: false,
        verify: false,
        onProgress: (p) {
          _flashProgress = p.fraction.clamp(0.0, 1.0);
          _flashStatus = 'Flashing ${(_flashProgress * 100).toInt()}%';
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds >= 250 || _flashProgress >= 1.0) {
            lastNotify = now;
            notifyListeners();
          }
          return Stream<EspProgress>.empty();
        },
      );

      final writeResult = await _flashService!.writeFlash(params);
      final writeOk = writeResult.fold<bool>(
        (_) => true,
        (f) {
          _addLogEntry('[ERROR] Failed writing flash image: ${f.message}');
          return false;
        },
      );

      if (!writeOk) {
        _errorMessage = 'Flash write failed';
        _isFlashing = false;
        _isOperationActive = false;
        notifyListeners();
        return;
      }

      _flashProgress = 1.0;
      _flashStatus = 'Complete';
      _addLogEntry('[OK] All ${bundle.parts.length} partition(s) written successfully.');
      _addLogEntry('[OK] Flashing complete. Resetting device to run application...');

      // Execute hardware reset so the ESP32 boots into user code
      await _resetToApplicationMode();

      notifyListeners();
    } catch (e) {
      _addLogEntry('[ERROR] Flash failed: $e');
      _errorMessage = 'Flash failed: $e';
    } finally {
      _isFlashing = false;
      _isOperationActive = false;
      notifyListeners();
    }
  }

  /// Reset the ESP32 into normal application mode by pulsing EN with BOOT high.
  Future<void> _resetToApplicationMode() async {
    final adapter = _adapter;
    if (adapter == null) return;
    try {
      // 1. Release BOOT (GPIO0 = HIGH, so DTR = false)
      await adapter.setDtr(false);
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Pulse EN (Reset = LOW, so RTS = true)
      await adapter.setRts(true);
      await Future.delayed(const Duration(milliseconds: 150));

      // 3. Release EN (Reset = HIGH, so RTS = false)
      await adapter.setRts(false);
      await Future.delayed(const Duration(milliseconds: 200));

      _addLogEntry('[OK] Hardware reset pulse sent. Firmware booted.');
    } catch (e) {
      _addLogEntry('[WARN] Hardware reset signal failed: $e');
    }
  }

  /// Create a new [FlashService], preferring the flasher stub.
  ///
  /// The ESP32-S3 ROM loader silently fails to persist flash writes when
  /// connected via its native USB-Serial-JTAG: write commands ACK but never
  /// land, and the full-chip erase command (0xD0) hangs ~5 min with no effect.
  /// The flasher stub is the esptool-standard path — it erases each sector as
  /// it writes and supports reliable full-chip erase and verification. Falls
  /// back to the ROM loader when the stub is unavailable or fails to load.
  Future<FlashService> _createFlashService() async {
    final detected = _detectedChip;
    if (detected != null && detected.family == ChipFamily.esp32s3) {
      try {
        final stubLoader = StubLoaderService(transport: _transport!);
        final result = await stubLoader.loadStub(detected.family);
        if (result is Success<void>) {
          _addLogEntry('[OK] Flasher stub loaded (ESP32-S3)');
          return FlashService(transport: _transport!, stubLoader: stubLoader);
        }
        final failure = result as Failure<void>;
        _addLogEntry(
            '[WARN] Stub load failed (${failure.error.message}); using ROM loader');
      } catch (e) {
        _addLogEntry('[WARN] Stub load error: $e; using ROM loader');
      }
    }
    return FlashService(transport: _transport!);
  }

  // ── Log ───────────────────────────────────────────────────────

  void _addLogEntry(String message) {
    final ts = DateTime.now();
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    _logEntries.add('[$h:$m:$s] $message');
  }

  void toggleLog() {
    _isLogExpanded = !_isLogExpanded;
    notifyListeners();
  }

  void clearLog() {
    _logEntries.clear();
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  String _parseRevision(String description) {
    if (description.contains('rev')) {
      final idx = description.indexOf('rev');
      return description.substring(idx + 3).trim();
    }
    return '1.0';
  }

  String _coresForFamily(ChipFamily family) {
    switch (family) {
      case ChipFamily.esp32:
        return '2';
      case ChipFamily.esp32s2:
        return '1';
      case ChipFamily.esp32s3:
        return '2';
      case ChipFamily.esp32c3:
        return '1';
      case ChipFamily.esp8266:
        return '1';
      default:
        return '?';
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _adapter?.dispose();
    super.dispose();
  }
}

// ── Model classes ──────────────────────────────────────────────────────────

class PortInfo {
  final String id;
  final String name;
  final String? description;
  const PortInfo({
    required this.id,
    required this.name,
    this.description,
  });

  bool get isPreferred {
    if (description == null) return false;
    final lower = description!.toLowerCase();
    return lower.contains('espressif') ||
        lower.contains('esp32') ||
        lower.contains('esp8266') ||
        lower.contains('esp32-s') ||
        lower.contains('esp32-c') ||
        lower.contains('esp32-h') ||
        lower.contains('esp32-p') ||
        lower.contains('esp') ||
        lower.contains('wemos') ||
        lower.contains('lolin') ||
        lower.contains('tinypico') ||
        lower.contains('adafruit') ||
        lower.contains('m5stack') ||
        lower.contains('heltec');
  }
}

class ChipInfo {
  final String model;
  final String revision;
  final String mac;
  final String flashSize;
  final String psramSize;
  final String cores;

  const ChipInfo({
    required this.model,
    required this.revision,
    required this.mac,
    required this.flashSize,
    required this.psramSize,
    required this.cores,
  });
}

class SelectedFirmware {
  final String name;
  final String size;
  final String path;
  final int bytes;
  final String chipFamily;
  final String version;
  final int partsCount;

  const SelectedFirmware({
    required this.name,
    required this.size,
    required this.path,
    required this.bytes,
    this.chipFamily = 'ESP32',
    this.version = '1.0.0',
    this.partsCount = 1,
  });
}
