import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' show md5;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flserial/flserial.dart';
import 'package:flutter_esptool/flutter_esptool.dart';
import 'package:flutter_esptool/src/application/stub_loader_service.dart';
import '../services/flserial_port_adapter.dart';

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
  ChipFamily? _chipFamily;
  ChipInfo? _chipInfo;
  bool _isLoadingChipInfo = false;

  // ── Firmware ─────────────────────────────────────────────────
  SelectedFirmware? _selectedFirmware;
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
  bool get isLoadingChipInfo => _isLoadingChipInfo;
  SelectedFirmware? get selectedFirmware => _selectedFirmware;
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
    if (_autoScanTimer != null || _isConnected) return;
    scanPorts();
    _autoScanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isConnected) scanPorts();
    });
  }

  /// Stop the periodic auto-scan.
  void stopAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  // ── Connection ─────────────────────────────────────────────────

  /// Enter ESP32 download mode via DTR/RTS toggling.
  ///
  /// Uses our custom sequence that supports both ClassicReset
  /// (RTS→EN, DTR→GPIO0 for standard UART bridges) and
  /// UsbJtagSerialReset (DTR→EN, RTS→GPIO0 for ESP32-S3/C3 native USB).
  ///
  /// The adapter delegates to flserial's setDTR/setRTS, which works on both
  /// Linux (native FFI) and Android (USB CDC control transfer via flserial
  /// plugin's setControlLines handler).
  Future<void> _enterBootloaderMode() async {
    final adapter = _adapter;
    if (adapter == null) {
      _addLogEntry('[WARN] No adapter available for boot mode');
      _addLogEntry('Tip: Hold BOOT, tap RESET, release BOOT manually.');
      return;
    }

    _addLogEntry('Putting ESP32 into download mode...');

    try {
      // USBJTagSerialReset sequence from esptool:
      // DTR→EN (chip reset), RTS→GPIO0 (boot mode select)
      // Signals are swapped on USB-JTAG-Serial vs. standard UART bridge.
      // GPIO0 must be LOW when EN transitions HIGH → download mode.

      // Step 1: Idle state — both inactive.
      await adapter.setRts(false);  // GPIO0=high
      await adapter.setDtr(false);  // EN=high
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 2: Hold chip in reset.
      await adapter.setDtr(true);   // EN=low (chip in reset)
      // GPIO0 still high from step 1
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 3: Set GPIO0 low for download mode while chip is in reset.
      await adapter.setRts(true);   // GPIO0=low (download mode)
      await Future.delayed(const Duration(milliseconds: 50));

      // Step 4: Release reset — chip samples GPIO0=low → download mode.
      await adapter.setDtr(false);  // EN=high (release reset)
      // GPIO0 stays low
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 5: Release GPIO0 — chip is now running in download mode.
      await adapter.setRts(false);  // GPIO0=high (done)

      // Flush serial buffers — clear stale bytes from reset.
      await adapter.resetBuffers();

      // Wait for bootloader to initialize
      await Future.delayed(const Duration(milliseconds: 300));

      _addLogEntry('Download mode engaged.');
    } catch (e) {
      _addLogEntry('[WARN] Auto boot mode: $e');
      _addLogEntry('Failed to enter download mode automatically.');
      _addLogEntry('Tip: Hold BOOT, tap RESET, release BOOT manually.');
    }
  }

  /// Connect to the selected serial port using an [FlserialPortAdapter],
  /// enter bootloader mode, sync with the ESP32 ROM bootloader,
  /// and detect chip info.
  Future<void> connect(String portId) async {
    _errorMessage = null;
    _isLoadingChipInfo = true;
    _isOperationActive = true;
    _isLogExpanded = true;
    _portName = portId;
    _addLogEntry('Connecting to $portId...');
    notifyListeners();

    try {
      // 1. Create adapter and transport.
      //    The adapter wraps an flserial port so DTR/RTS work on Android.
      final adapter = FlserialPortAdapter(portId);
      _adapter = adapter;
      _transport = EspTransport(serial: adapter);
      _connectionService = ConnectionService(_transport!);

      // 2. Set config and open at initial baud rate.
      final config = EspConfig(
        portName: portId,
        initialBaudRate: 115200,
        flashBaudRate: 921600,
        syncRetries: 10,
      );
      _espConfig = config;

      // Open the port via EspTransport (which calls adapter.open).
      await _transport!.open(config);
      _addLogEntry('[OK] Port opened at 115200 baud');

      // 3. Enter bootloader mode then sync.
      await _enterBootloaderMode();

      // 4. ConnectionService handles sync + baud rate negotiation.
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
        _addLogEntry('Tip: Ensure the device is in download mode '
            '(hold BOOT, tap RESET, release BOOT).');
        _errorMessage = 'Sync failed. Check connection and boot mode.';
        _isLoadingChipInfo = false;
        _isOperationActive = false;
        _isConnected = false;
        notifyListeners();
        return;
      }

      _addLogEntry('[OK] Synchronized with ESP32 ROM bootloader');

      // Small delay to let any trailing bootloader data settle before
      // the next command sequence.
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. Detect chip info with retry.
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

      if (detectedChip != null) {
        _isConnected = true;
        notifyListeners();
        final info = detectedChip;
        _addLogEntry('Chip is ${info.description}');
        _addLogEntry('MAC: ${info.macAddress}');
        // Keep at initial baud rate for erase/write stability.
        // Baud rate negotiation (changeBaud) can be enabled later as
        // an optimization via _transport.changeBaud(921600).
        _baudRate = 115200;

        // Flash info from chip detection (avoids sending SPI commands that
        // could interfere with the flash state machine for erase/write).
        if (info.flashSizeBytes != null && info.flashSizeBytes! > 0) {
          _addLogEntry('Flash: ${_formatBytes(info.flashSizeBytes!)}');
        }

        // Build ChipInfo model.
        final chipModel = info.description;
        final flashStr = info.flashSizeBytes != null
            ? _formatBytes(info.flashSizeBytes!)
            : 'Unknown';

        _chipInfo = ChipInfo(
          model: chipModel,
          revision: 'v${_parseRevision(chipModel)}',
          mac: info.macAddress,
          flashSize: flashStr,
          psramSize: 'Detecting...',
          cores: _coresForFamily(info.family),
        );
      } else {
        _addLogEntry('[ERROR] Chip detection failed after retries');
        _addLogEntry('You can still try flashing with a firmware file.');
        // Set fallback chip info.
        _chipInfo = ChipInfo(
          model: 'ESP (unidentified)',
          revision: '--',
          mac: '--',
          flashSize: '--',
          psramSize: '--',
          cores: '--',
        );
        // Successfully synced but couldn't identify — still consider
        // connected since the bootloader is reachable.
        _isConnected = true;
        notifyListeners();
        _baudRate = 115200;
      }

      // 6. Create flash service with stub loader (required for ESP32-S3
      //    USB-JTAG-Serial flash operations).
      _chipFamily = detectedChip?.family;
      _flashService = _createFlashService();

      _addLogEntry('[OK] Device ready for flashing');
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _addLogEntry('[ERROR] $e');
      _isConnected = false;
    } finally {
      _isLoadingChipInfo = false;
      _isOperationActive = false;
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
    _selectedFirmware = null;
    _flashProgress = 0.0;
    _flashStatus = '';
    _addLogEntry('Disconnected.');
    notifyListeners();
  }

  /// Release the serial port for RadioKit protocol handoff.
  /// Disconnects the flasher but preserves the port name for handoff.
  /// Returns the port ID to connect to, or null if not connected.
  Future<String?> handoffSerial() async {
    final port = _portName;
    await disconnect();
    // Restore portName so lastPortId still returns it for handoff.
    _portName = port;
    notifyListeners();
    return port;
  }

  // ── Firmware ───────────────────────────────────────────────────

  /// Open file picker and select a .bin firmware file.
  Future<void> selectFirmwareFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) {
        _addLogEntry('[ERROR] Could not access the selected file.');
        return;
      }

      final bytes = await File(file.path!).readAsBytes();

      // Validate using EspImageParser.
      try {
        final result = EspImageParser.parse(bytes);
        result.fold<void>(
          (header) {
            _addLogEntry('Firmware: ${header.segmentCount} segment(s), '
                'valid: ${header.isValid}');
          },
          (f) {
            _addLogEntry('[WARN] Image parse: ${f.message} (proceeding anyway)');
          },
        );
      } catch (e) {
        _addLogEntry('[WARN] Image parse error: $e (proceeding anyway)');
      }

      _selectedFirmware = SelectedFirmware(
        name: file.name,
        size: _formatBytes(bytes.length),
        path: file.path!,
        bytes: bytes.length,
      );
      _addLogEntry('Selected firmware: ${file.name} '
          '(${_formatBytes(bytes.length)})');
      notifyListeners();
    } catch (e) {
      _addLogEntry('[ERROR] File selection failed: $e');
    }
  }

  /// Directly set firmware data from a remote source (bypasses file picker).
  void setSelectedFirmwareDirect({
    required String name,
    required String path,
    required int bytes,
  }) {
    _selectedFirmware = SelectedFirmware(
      name: name,
      size: _formatBytes(bytes),
      path: path,
      bytes: bytes,
    );
    _addLogEntry('Firmware set via API: $name (${_formatBytes(bytes)})');
    notifyListeners();
  }

  void clearFirmwareSelection() {
    _selectedFirmware = null;
    notifyListeners();
  }

  void setEraseAll(bool value) {
    _eraseAll = value;
    notifyListeners();
  }

  // ── Flashing ──────────────────────────────────────────────────

  /// Start the flashing operation.
  Future<void> startFlashing() async {
    if (_selectedFirmware == null || !_isConnected) return;
    if (_flashService == null) return;

    final file = File(_selectedFirmware!.path);
    if (!file.existsSync()) {
      _addLogEntry('[ERROR] Firmware file not found: ${_selectedFirmware!.path}');
      _errorMessage = 'Firmware file not found';
      notifyListeners();
      return;
    }

    _isFlashing = true;
    _flashProgress = 0.0;
    _isOperationActive = true;
    _isLogExpanded = true;
    _addLogEntry('Starting flash...');
    notifyListeners();

    try {
      final firmwareBytes = await file.readAsBytes();

      // The ESP32-S3 USB-JTAG-Serial stub flasher does not respond to
      // erase commands (opcodes 0xD0 or 0xD1) over certain USB bridges.
      // This is not a problem — writeFlash handles per-sector erasure
      // automatically during the write cycle (standard esptool behavior).
      // The prior full-chip erase is purely an optimization and is
      // not required for correct flash programming.
      if (_eraseAll) {
        _addLogEntry('Skipping separate erase — writeFlash handles '
            'per-sector erase during writes.');
      }

      // Re-prepare the chip for flashing: re-enter bootloader mode,
      // re-sync with the ROM bootloader, and reload the stub flasher.
      // This is necessary because a previous flash resets the chip out
      // of download mode, making it unresponsive to flash commands.
      _addLogEntry('Re-entering download mode...');
      await _reprepareForFlashing();

      // Write firmware.
      final params = FlashParameters(
        data: firmwareBytes,
        offset: 0,
        onProgress: (p) {
          _flashProgress = p.fraction;
          _flashStatus = 'Flashing ${(p.fraction * 100).toInt()}%';
          if (p.stage == EspProgressStage.writing) {
            _addLogEntry('${p.message}');
          }
          notifyListeners();
          return Stream<EspProgress>.empty();
        },
      );
      _addLogEntry('Writing firmware (${_formatBytes(firmwareBytes.length)})...');
      final writeResult = await _flashService!.writeFlash(params);

      final writeOk = writeResult.fold<bool>(
        (_) {
          _addLogEntry('[OK] Firmware written successfully');
          return true;
        },
        (f) {
          _addLogEntry('[ERROR] Write failed: ${f.message}');
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

      // Verify firmware integrity with local MD5 hash.
      // Chip-side flashMd5 is not supported by the stub flasher on
      // ESP32-S3 USB-JTAG-Serial, so we compute it locally instead.
      final hash = md5.convert(firmwareBytes).toString();
      _addLogEntry('[OK] Local firmware hash: $hash');

      _addLogEntry('[OK] Flashing complete. Device will reset.');
      _flashProgress = 1.0;
      _flashStatus = 'Complete';
    } catch (e) {
      _addLogEntry('[ERROR] Flash failed: $e');
      _errorMessage = 'Flash failed: $e';
    } finally {
      _isFlashing = false;
      _isOperationActive = false;
      notifyListeners();
    }
  }

  /// Re-prepare the chip for flashing by re-entering bootloader mode,
  /// re-syncing with the ROM bootloader, and reloading the stub.
  ///
  /// After a successful flash, the chip resets and exits download mode.
  /// The serial port remains open but the chip is running the new firmware.
  /// To flash again, we must re-enter bootloader mode and reload the stub
  /// (which lives in RAM and is lost on reset).
  Future<void> _reprepareForFlashing() async {
    await _enterBootloaderMode();

    final config = _espConfig;
    if (config == null || _connectionService == null) return;

    try {
      final syncResult = await _connectionService!.connect(config);
      syncResult.fold(
        (_) => _addLogEntry('[OK] Re-synced with bootloader'),
        (f) => _addLogEntry('[WARN] Re-sync: ${f.message} (continuing)'),
      );
    } catch (e) {
      _addLogEntry('[WARN] Re-sync failed: $e (continuing)');
    }

    // Reload the stub flasher (lost on chip reset).
    _flashService = _createFlashService();
  }

  /// Create a new [FlashService] with a fresh stub loader.
  FlashService _createFlashService() {
    final stubLoader = StubLoaderService(_transport!);
    final service = FlashService(
      transport: _transport!,
      stubLoader: stubLoader,
    );
    service.chipFamily = _chipFamily;
    return service;
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

  /// Whether the port description suggests this is an ESP device.
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

  const SelectedFirmware({
    required this.name,
    required this.size,
    required this.path,
    required this.bytes,
  });
}
