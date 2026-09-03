import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_esptool/flutter_esptool.dart';
import '../models/firmware_bundle.dart';

/// Exception thrown when a firmware bundle fails validation.
class FirmwareBundleException implements Exception {
  final String message;
  const FirmwareBundleException(this.message);

  @override
  String toString() => message;
}

/// Parser for ESP Web Tools compatible firmware `.zip` packages.
class FirmwareBundleParser {
  /// Parse a zip archive containing an ESP Web Tools `manifest.json`.
  static FirmwareBundle parseZip(
    Uint8List zipBytes, {
    String? fileName,
  }) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw FirmwareBundleException('Invalid ZIP archive: $e');
    }

    // Map archive entries by normalized file name/path
    final fileMap = <String, Uint8List>{};
    ArchiveFile? manifestFile;

    for (final file in archive) {
      if (!file.isFile) continue;
      final rawContent = file.content;
      final Uint8List bytes;
      if (rawContent is Uint8List) {
        bytes = rawContent;
      } else if (rawContent is List<int>) {
        bytes = Uint8List.fromList(rawContent);
      } else {
        continue;
      }

      final normalized = file.name.replaceAll('\\', '/');
      fileMap[normalized] = bytes;
      // Also map simple base name for flat lookups
      final baseName = normalized.split('/').last;
      fileMap[baseName] = bytes;

      if (baseName.toLowerCase() == 'manifest.json') {
        manifestFile = file;
      }
    }

    if (manifestFile == null) {
      throw const FirmwareBundleException(
        'Missing manifest.json in firmware bundle. Only standard ESP Web Tools .zip packages are supported.',
      );
    }

    final String manifestJson;
    try {
      final manifestBytes = fileMap['manifest.json']!;
      manifestJson = utf8.decode(manifestBytes);
    } catch (e) {
      throw FirmwareBundleException('Could not read manifest.json: $e');
    }

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    } catch (e) {
      throw FirmwareBundleException('Invalid JSON in manifest.json: $e');
    }

    final name = (manifest['name'] as String?) ?? 'RadioKit Firmware';
    final version = (manifest['version'] as String?) ?? '1.0.0';

    // Parse builds or root parts
    List<dynamic>? rawParts;
    String chipFamily = 'ESP32';

    if (manifest['builds'] is List && (manifest['builds'] as List).isNotEmpty) {
      final firstBuild = (manifest['builds'] as List).first as Map<String, dynamic>;
      chipFamily = (firstBuild['chipFamily'] as String?) ?? chipFamily;
      rawParts = firstBuild['parts'] as List<dynamic>?;
    } else if (manifest['parts'] is List) {
      rawParts = manifest['parts'] as List<dynamic>?;
      chipFamily = (manifest['chipFamily'] as String?) ?? chipFamily;
    }

    if (rawParts == null || rawParts.isEmpty) {
      throw const FirmwareBundleException('No partition parts defined in manifest.json');
    }

    final parts = <FirmwarePart>[];
    for (final p in rawParts) {
      if (p is! Map<String, dynamic>) continue;
      final path = (p['path'] as String?) ?? (p['file'] as String?);
      if (path == null || path.isEmpty) continue;

      final dynamic rawOffset = p['offset'] ?? p['flash_offset'];
      final int offset;
      if (rawOffset is int) {
        offset = rawOffset;
      } else if (rawOffset is String) {
        offset = int.tryParse(rawOffset.replaceAll('0x', ''), radix: rawOffset.startsWith('0x') ? 16 : 10) ?? 0;
      } else {
        offset = 0;
      }

      // Look up part binary in archive
      final cleanPath = path.replaceAll('\\', '/');
      final base = cleanPath.split('/').last;
      final partBytes = fileMap[cleanPath] ?? fileMap[base];

      if (partBytes == null || partBytes.isEmpty) {
        throw FirmwareBundleException('Referenced file "$path" not found in ZIP bundle');
      }

      parts.add(FirmwarePart(
        path: path,
        offset: offset,
        bytes: partBytes,
      ));
    }

    if (parts.isEmpty) {
      throw const FirmwareBundleException('No valid partition binaries found in bundle');
    }

    // Sort parts by offset in ascending order
    parts.sort((a, b) => a.offset.compareTo(b.offset));

    return FirmwareBundle(
      name: name,
      version: version,
      chipFamily: chipFamily,
      parts: parts,
      rawZipBytes: zipBytes,
      originalFileName: fileName,
    );
  }

  /// Check whether the detected ESP chip family matches the bundle's required chip family.
  static bool isChipFamilyCompatible(ChipFamily detectedFamily, String manifestFamily) {
    final normManifest = manifestFamily.toLowerCase().replaceAll('-', '').replaceAll('_', '').trim();
    final normDetected = detectedFamily.name.toLowerCase().replaceAll('-', '').replaceAll('_', '').trim();

    if (normDetected == 'unknown') return true; // Allow if detection was indeterminate
    if (normManifest == normDetected) return true;

    // Special aliases
    if (normManifest == 'esp32' && normDetected == 'esp32') return true;
    if ((normManifest == 'esp32s3' || normManifest == 's3') && normDetected == 'esp32s3') return true;
    if ((normManifest == 'esp32c3' || normManifest == 'c3') && normDetected == 'esp32c3') return true;
    if ((normManifest == 'esp32s2' || normManifest == 's2') && normDetected == 'esp32s2') return true;
    if ((normManifest == 'esp32c6' || normManifest == 'c6') && normDetected == 'esp32c6') return true;
    if ((normManifest == 'esp32h2' || normManifest == 'h2') && normDetected == 'esp32h2') return true;

    return false;
  }
}
