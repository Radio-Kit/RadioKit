import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Represents a single entry in the ESP32 filesystem listing.
class EspFsEntry {
  final String name;
  final bool isDirectory;
  final int size;

  const EspFsEntry({
    required this.name,
    required this.isDirectory,
    this.size = 0,
  });

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isDirectory': isDirectory,
        'size': size,
      };

  factory EspFsEntry.fromJson(Map<String, dynamic> json) => EspFsEntry(
        name: json['name'] as String? ?? '',
        isDirectory: json['isDirectory'] as bool? ?? false,
        size: json['size'] as int? ?? 0,
      );
}

/// Result of a filesystem operation.
class EspFsResult {
  final bool success;
  final String message;

  const EspFsResult({required this.success, this.message = ''});

  factory EspFsResult.ok([String message = '']) =>
      EspFsResult(success: true, message: message);

  factory EspFsResult.error(String message) =>
      EspFsResult(success: false, message: message);
}

/// Protocol service for communicating with ESP32 filesystem over serial.
///
/// Wire protocol (over raw serial):
///   Commands (app → device):   `CMD [args...]\n`
///   Responses (device → app):  `OK:<type>\n[data]\n`
///                              `ERR:<message>\n`
///   Binary transfer:           prefixed with `SIZE:1234\n` then raw bytes
///
/// Available commands:
///   LIST [path]\n       → OK:list\ncount\nname|size|dirFlag\n...
///   READ [path]\n       → OK:read\nSIZE:1234\n[binary data]
///   WRITE path\nSIZE:N\n[binary data] → OK:write\n
///   DELETE path\n       → OK:delete\n or ERR:msg\n
///   MKDIR path\n        → OK:mkdir\n
///   RMDIR path\n        → OK:rmdir\n
///   STAT path\n         → OK:stat\nsize|isDir|name\n
///   INFO\n              → OK:info\ntotalBytes|usedBytes|fsType\n
class EspFsService {
  final void Function(List<int>) _writeFn;
  StreamSubscription<List<int>>? _sub;
  final StringBuffer _lineBuffer = StringBuffer();
  bool _isBinaryMode = false;
  int _binaryRemaining = 0;
  final List<int> _binaryData = [];
  Completer<EspFsResult>? _pendingCompleter;
  Completer<Uint8List?>? _readCompleter;
  Timer? _timeout;

  // LIST mode — uses the main pipeline instead of a separate subscription
  bool _listMode = false;
  final List<String> _listLines = [];

  // INFO mode — uses the main pipeline instead of a separate subscription
  Completer<Map<String, dynamic>>? _infoCompleter;

  /// Current working directory path.
  String currentPath = '/';

  EspFsService({
    required void Function(List<int>) writeFn,
    required Stream<List<int>> dataStream,
  })  : _writeFn = writeFn {
    _sub = dataStream.listen(_onData);
  }

  /// Cancel the active timeout timer safely.
  void _cancelTimeout() {
    _timeout?.cancel();
    _timeout = null;
  }

  void _onData(List<int> bytes) {
    if (_isBinaryMode) {
      for (final b in bytes) {
        if (_binaryRemaining > 0) {
          _binaryData.add(b);
          _binaryRemaining--;
          if (_binaryRemaining == 0) {
            _isBinaryMode = false;
            final data = Uint8List.fromList(_binaryData);
            _binaryData.clear();
            _readCompleter?.complete(data);
            _readCompleter = null;
            _cancelTimeout();
          }
        }
      }
      return;
    }

    for (final b in bytes) {
      final ch = String.fromCharCode(b);
      if (ch == '\n') {
        _processLine(_lineBuffer.toString().trim());
        _lineBuffer.clear();
      } else if (b >= 0x20 || b == 0x09) {
        // printable chars and tabs
        _lineBuffer.write(ch);
      }
    }
  }

  void _processLine(String line) {
    if (line.isEmpty) return;

    // --- ERR (always handled) ---
    if (line.startsWith('ERR:')) {
      final msg = line.substring(4);
      if (_listMode) {
        _listMode = false;
        _listLines.clear();
        _pendingCompleter?.complete(EspFsResult.error(msg));
        _pendingCompleter = null;
        _cancelTimeout();
        return;
      }
      if (_infoCompleter != null && !_infoCompleter!.isCompleted) {
        _infoCompleter?.completeError(Exception(msg));
        _infoCompleter = null;
        _cancelTimeout();
        return;
      }
      _pendingCompleter?.complete(EspFsResult.error(msg));
      _pendingCompleter = null;
      _cancelTimeout();
      return;
    }

    // --- OK:list (start LIST mode) ---
    if (line == 'OK:list') {
      _listMode = true;
      _listLines.clear();
      return;
    }

    // --- OK:read ---
    if (line.startsWith('OK:read')) {
      return; // next line should be SIZE:N
    }

    // --- SIZE:N (binary mode or empty file) ---
    if (line.startsWith('SIZE:')) {
      final sizeStr = line.substring(5);
      final size = int.tryParse(sizeStr);
      if (size != null && size > 0) {
        _isBinaryMode = true;
        _binaryRemaining = size;
        _binaryData.clear();
      } else if (size == 0) {
        _readCompleter?.complete(Uint8List(0));
        _readCompleter = null;
        _pendingCompleter?.complete(EspFsResult.ok());
        _pendingCompleter = null;
        _cancelTimeout();
      }
      return;
    }

    // --- In LIST mode, accumulate entry lines ---
    if (_listMode) {
      // If line contains '|' it's an entry (name|size|dirFlag)
      if (line.contains('|')) {
        _listLines.add(line);
      }
      // Otherwise it could be the count line — skip it
      return;
    }

    // --- OK:info — accumulate data line into info completer ---
    if (line == 'OK:info') {
      return; // next line has the data
    }

    // --- If we have an active info completer, try to parse the data ---
    if (_infoCompleter != null && !_infoCompleter!.isCompleted) {
      final parts = line.split('|');
      if (parts.length >= 2) {
        final total = int.tryParse(parts[0]) ?? 0;
        final used = int.tryParse(parts[1]) ?? 0;
        final fsType = parts.length > 2 ? parts[2] : 'SPIFFS';
        _infoCompleter?.complete({
          'totalBytes': total,
          'usedBytes': used,
          'freeBytes': total - used,
          'fsType': fsType,
        });
        _infoCompleter = null;
        _cancelTimeout();
        return;
      }
    }

    // --- OK: successful response for write/delete/mkdir/rmdir ---
    if (line.startsWith('OK:')) {
      _pendingCompleter?.complete(EspFsResult.ok());
      _pendingCompleter = null;
      _cancelTimeout();
    }
  }

  void _startTimeout(Duration duration, VoidCallback onTimeout) {
    _timeout?.cancel();
    _timeout = Timer(duration, onTimeout);
  }

  Future<void> _sendCommand(String cmd) async {
    _writeFn(utf8.encode('$cmd\n'));
  }

  Future<EspFsResult> _waitForResponse() {
    final completer = Completer<EspFsResult>();
    _pendingCompleter = completer;
    _startTimeout(const Duration(seconds: 5), () {
      _pendingCompleter?.complete(EspFsResult.error('Command timed out'));
      _pendingCompleter = null;
      _readCompleter?.complete(Uint8List(0));
      _readCompleter = null;
    });
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// List contents of [path] (defaults to [currentPath]).
  ///
  /// Uses the main [dataStream] pipeline via [listMode] flags — no competing
  /// subscriptions created.
  Future<List<EspFsEntry>> listDirectory([String? path]) async {
    final target = path ?? currentPath;
    final entries = <EspFsEntry>[];

    // Create a completer that resolves when LIST finishes (OK or ERR)
    final listCompleter = Completer<void>();

    _listMode = true;
    _listLines.clear();

    _startTimeout(const Duration(seconds: 5), () {
      _listMode = false;
      _listLines.clear();
      if (!listCompleter.isCompleted) {
        listCompleter.completeError(Exception('LIST timed out'));
      }
    });

    _writeFn(utf8.encode('LIST $target\n'));

    // Wait for the pending completer to resolve (set in _processLine)
    // We use _pendingCompleter to know when LIST is done
    // Actually, for LIST, the device sends OK:list, then lines, then...
    // The protocol doesn't have a terminator. We need a fixed delay.
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (_) {}

    _listMode = false;
    _cancelTimeout();

    // Parse accumulated lines as entries
    for (final line in _listLines) {
      final parts = line.split('|');
      if (parts.length >= 2) {
        final name = parts[0];
        final size = int.tryParse(parts[1]) ?? 0;
        final isDir = parts.length > 2 && parts[2] == '1';
        entries.add(EspFsEntry(name: name, isDirectory: isDir, size: size));
      }
    }
    _listLines.clear();

    return entries;
  }

  /// Read a file and return its contents as bytes.
  Future<Uint8List?> readFile(String path) async {
    final completer = Completer<Uint8List?>();
    _readCompleter = completer;

    _startTimeout(const Duration(seconds: 10), () {
      _readCompleter?.complete(null);
      _readCompleter = null;
    });

    _writeFn(utf8.encode('READ $path\n'));
    return completer.future;
  }

  /// Write [data] to a file at [path].
  Future<EspFsResult> writeFile(String path, Uint8List data) async {
    final header = utf8.encode('WRITE $path\nSIZE:${data.length}\n');
    _writeFn([...header, ...data]);
    return _waitForResponse();
  }

  /// Delete a file at [path].
  Future<EspFsResult> deleteFile(String path) async {
    _sendCommand('DELETE $path');
    return _waitForResponse();
  }

  /// Create a directory at [path].
  Future<EspFsResult> createDirectory(String path) async {
    _sendCommand('MKDIR $path');
    return _waitForResponse();
  }

  /// Remove an empty directory at [path].
  Future<EspFsResult> removeDirectory(String path) async {
    _sendCommand('RMDIR $path');
    return _waitForResponse();
  }

  /// Get filesystem info.
  ///
  /// Uses the main [dataStream] pipeline via [infoCompleter] — no competing
  /// subscriptions created.
  Future<Map<String, dynamic>?> getInfo() async {
    final completer = Completer<Map<String, dynamic>>();
    _infoCompleter = completer;

    _startTimeout(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(<String, dynamic>{});
      }
      _infoCompleter = null;
    });

    _writeFn(utf8.encode('INFO\n'));

    try {
      final result = await completer.future;
      return result.isNotEmpty ? result : null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    _listMode = false;
    _listLines.clear();
    _infoCompleter = null;
  }
}
