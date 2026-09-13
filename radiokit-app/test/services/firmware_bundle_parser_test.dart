import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_esptool/flutter_esptool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/models/firmware_bundle.dart';
import 'package:radiokit/services/firmware_bundle_parser.dart';

Uint8List createTestZip({
  required Map<String, dynamic>? manifest,
  required Map<String, List<int>> files,
}) {
  final archive = Archive();
  if (manifest != null) {
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
  }
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

void main() {
  group('FirmwareBundleParser', () {
    test('parses valid ESP Web Tools manifest.json bundle', () {
      final manifest = {
        'name': 'RadioKit TrackLink',
        'version': '1.2.3',
        'builds': [
          {
            'chipFamily': 'ESP32-S3',
            'parts': [
              {'path': 'bootloader.bin', 'offset': 0},
              {'path': 'partitions.bin', 'offset': 32768},
              {'path': 'boot_app0.bin', 'offset': 57344},
              {'path': 'firmware.bin', 'offset': 65536},
              {'path': 'littlefs.bin', 'offset': 3211264},
            ]
          }
        ]
      };

      final files = {
        'bootloader.bin': [0x01, 0x02, 0x03],
        'partitions.bin': [0x04, 0x05],
        'boot_app0.bin': [0x06],
        'firmware.bin': [0x07, 0x08, 0x09, 0x0A],
        'littlefs.bin': [0x0B, 0x0C],
      };

      final zipBytes = createTestZip(manifest: manifest, files: files);
      final bundle = FirmwareBundleParser.parseZip(zipBytes, fileName: 'test_release.zip');

      expect(bundle.name, 'RadioKit TrackLink');
      expect(bundle.version, '1.2.3');
      expect(bundle.chipFamily, 'ESP32-S3');
      expect(bundle.parts.length, 5);

      expect(bundle.parts[0].offset, 0);
      expect(bundle.parts[0].path, 'bootloader.bin');

      expect(bundle.parts[1].offset, 32768);
      expect(bundle.parts[2].offset, 57344);

      expect(bundle.parts[3].offset, 65536);
      expect(bundle.parts[3].path, 'firmware.bin');

      expect(bundle.parts[4].offset, 3211264);
      expect(bundle.parts[4].path, 'littlefs.bin');

      expect(bundle.appPart?.offset, 65536);
      expect(bundle.filesystemPart?.offset, 3211264);
    });

    test('throws exception when manifest.json is missing', () {
      final zipBytes = createTestZip(
        manifest: null,
        files: {'firmware.bin': [1, 2, 3]},
      );

      expect(
        () => FirmwareBundleParser.parseZip(zipBytes),
        throwsA(isA<FirmwareBundleException>()),
      );
    });

    test('throws exception when referenced file is missing in archive', () {
      final manifest = {
        'name': 'Test',
        'builds': [
          {
            'chipFamily': 'ESP32',
            'parts': [
              {'path': 'bootloader.bin', 'offset': 0},
              {'path': 'missing.bin', 'offset': 65536},
            ]
          }
        ]
      };

      final files = {'bootloader.bin': [1, 2, 3]};
      final zipBytes = createTestZip(manifest: manifest, files: files);

      expect(
        () => FirmwareBundleParser.parseZip(zipBytes),
        throwsA(isA<FirmwareBundleException>()),
      );
    });

    test('validates chip family compatibility correctly', () {
      expect(FirmwareBundleParser.isChipFamilyCompatible(ChipFamily.esp32s3, 'ESP32-S3'), isTrue);
      expect(FirmwareBundleParser.isChipFamilyCompatible(ChipFamily.esp32s3, 'esp32s3'), isTrue);
      expect(FirmwareBundleParser.isChipFamilyCompatible(ChipFamily.esp32, 'ESP32'), isTrue);
      expect(FirmwareBundleParser.isChipFamilyCompatible(ChipFamily.esp32c3, 'ESP32-C3'), isTrue);

      expect(FirmwareBundleParser.isChipFamilyCompatible(ChipFamily.esp32, 'ESP32-S3'), isFalse);
      expect(FirmwareBundleParser.isChipFamilyCompatible(ChipFamily.esp32s3, 'ESP32'), isFalse);
    });
  });
}
