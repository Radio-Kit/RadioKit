import 'dart:typed_data';

/// A single partition part defined in an ESP Web Tools manifest.json.
class FirmwarePart {
  final String path;
  final int offset;
  final Uint8List bytes;

  const FirmwarePart({
    required this.path,
    required this.offset,
    required this.bytes,
  });

  int get size => bytes.length;
}

/// A parsed ESP Web Tools firmware release bundle.
class FirmwareBundle {
  final String name;
  final String version;
  final String chipFamily;
  final List<FirmwarePart> parts;
  final Uint8List rawZipBytes;
  final String? originalFileName;

  const FirmwareBundle({
    required this.name,
    required this.version,
    required this.chipFamily,
    required this.parts,
    required this.rawZipBytes,
    this.originalFileName,
  });

  /// Total uncompressed size of all partition parts.
  int get totalBinaryBytes => parts.fold(0, (sum, p) => sum + p.size);

  /// Find the application firmware part intended for app slot 0 / OTA (offset 0x10000 = 65536).
  FirmwarePart? get appPart {
    // Exact standard offset 0x10000 (65536)
    for (final part in parts) {
      if (part.offset == 65536) return part;
    }
    // Fallback: look for firmware.bin or app.bin if offset differs
    for (final part in parts) {
      final lower = part.path.toLowerCase();
      if (lower.contains('firmware') || lower.contains('app')) return part;
    }
    return parts.isNotEmpty ? parts.last : null;
  }

  /// Find the filesystem part (e.g. littlefs.bin / spiffs.bin) if included.
  FirmwarePart? get filesystemPart {
    for (final part in parts) {
      final lower = part.path.toLowerCase();
      if (lower.contains('littlefs') || lower.contains('spiffs') || lower.contains('fs')) {
        return part;
      }
    }
    return null;
  }

  /// Build a single unified binary image starting at offset 0 with 0xFF padding.
  Uint8List buildMergedImage() {
    if (parts.isEmpty) return Uint8List(0);
    var maxEnd = 0;
    for (final p in parts) {
      final end = p.offset + p.size;
      if (end > maxEnd) maxEnd = end;
    }
    final merged = Uint8List(maxEnd);
    merged.fillRange(0, maxEnd, 0xFF);
    for (final p in parts) {
      merged.setRange(p.offset, p.offset + p.size, p.bytes);
    }
    return merged;
  }
}
