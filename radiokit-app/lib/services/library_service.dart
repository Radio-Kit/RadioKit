import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Serves the bundled rk-arduino library for download by agents and users.
///
/// On first access, extracts `assets/rk-arduino.zip` to the app documents
/// directory and reads the version from `library.json`.
class LibraryService {
  static const _assetPath = 'assets/rk-arduino.zip';
  static const _extractDirName = 'rk-arduino';

  String _version = '';
  bool _initialized = false;

  /// The library version read from `library.json` inside the ZIP.
  String get version => _version;

  /// Whether `initialize()` has completed.
  bool get isInitialized => _initialized;

  /// Extract the bundled ZIP to the documents directory (if not already present)
  /// and read the version from `library.json`.
  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    final extractDir = Directory('${appDir.path}/$_extractDirName');

    if (!extractDir.existsSync()) {
      await _extractZip(extractDir.path);
    }

    _readVersion(extractDir.path);
    _initialized = true;
  }

  /// Return the raw ZIP bytes from the bundled asset.
  Future<List<int>> downloadZip() async {
    final data = await rootBundle.load(_assetPath);
    return data.buffer.asUint8List();
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _extractZip(String destPath) async {
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = '$destPath/${file.name}';
      if (file.isFile) {
        final out = File(filePath);
        await out.create(recursive: true);
        await out.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  void _readVersion(String extractPath) {
    try {
      final file = File('$extractPath/library.json');
      if (file.existsSync()) {
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        _version = json['version'] as String? ?? '';
      }
    } catch (_) {
      _version = '';
    }
  }
}
