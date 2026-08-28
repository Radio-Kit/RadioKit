import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radiokit/services/firmware_marketplace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirmwareMarketplaceService URL Parsing', () {
    test('parses plain github repo url', () {
      final parsed = FirmwareMarketplaceService.parseRepoUrl('https://github.com/DragonRailway/RC_Engine');
      expect(parsed, isNotNull);
      expect(parsed!.$1, equals('DragonRailway'));
      expect(parsed.$2, equals('RC_Engine'));
    });

    test('parses github url with .git and trailing slash', () {
      final parsed = FirmwareMarketplaceService.parseRepoUrl('https://github.com/Radio-Kit/demo-fs-assets.git/');
      expect(parsed, isNotNull);
      expect(parsed!.$1, equals('Radio-Kit'));
      expect(parsed.$2, equals('demo-fs-assets'));
    });

    test('parses deep link uri format', () {
      final parsed = FirmwareMarketplaceService.parseRepoUrl('radiokit://firmware?url=https://github.com/DragonRailway/RC_Engine');
      expect(parsed, isNotNull);
      expect(parsed!.$1, equals('DragonRailway'));
      expect(parsed.$2, equals('RC_Engine'));
    });

    test('returns null for invalid URLs', () {
      expect(FirmwareMarketplaceService.parseRepoUrl(''), isNull);
      expect(FirmwareMarketplaceService.parseRepoUrl('https://example.com/foo'), isNull);
    });
  });

  group('FirmwareMarketplaceService Binary Filename Parsing', () {
    test('parses standard binary with version, chip, board, and factory type', () {
      final info = FirmwareMarketplaceService.parseBinaryFilename(
        'RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin',
        downloadUrl: 'https://example.com/bin',
        sizeBytes: 887000,
      );

      expect(info.project, equals('RC_Engine'));
      expect(info.version, equals('v1.0.0'));
      expect(info.chip, equals('esp32s3'));
      expect(info.board, equals('MIKRO_V2'));
      expect(info.variant, isNull);
      expect(info.displayName, equals('MIKRO_V2'));
      expect(info.boardOrVariant, equals('MIKRO_V2'));
      expect(info.flashType, equals('factory'));
      expect(info.isFactory, isTrue);
      expect(info.isOta, isFalse);
    });

    test('parses clean binary without factory suffix', () {
      final info = FirmwareMarketplaceService.parseBinaryFilename(
        'RC_Engine-v1.0.0-esp32s3-GTRACK.bin',
        downloadUrl: 'https://example.com/bin',
        sizeBytes: 1400000,
      );

      expect(info.project, equals('RC_Engine'));
      expect(info.version, equals('v1.0.0'));
      expect(info.chip, equals('esp32s3'));
      expect(info.board, equals('GTRACK'));
      expect(info.variant, isNull);
      expect(info.displayName, equals('GTRACK'));
      expect(info.isOta, isFalse);
    });

    test('parses standard OTA binary with version, chip, and ota type', () {
      final info = FirmwareMarketplaceService.parseBinaryFilename(
        'BasicSwitch-v2.1.0-esp32s3-ota.bin',
        downloadUrl: 'https://example.com/bin',
        sizeBytes: 720000,
      );

      expect(info.project, equals('BasicSwitch'));
      expect(info.version, equals('v2.1.0'));
      expect(info.chip, equals('esp32s3'));
      expect(info.board, isNull);
      expect(info.variant, isNull);
      expect(info.displayName, equals('BasicSwitch'));
      expect(info.boardOrVariant, isNull);
      expect(info.flashType, equals('ota'));
      expect(info.isFactory, isFalse);
      expect(info.isOta, isTrue);
    });

    test('parses variant with sub-target features', () {
      final info = FirmwareMarketplaceService.parseBinaryFilename(
        'RC_Engine-v1.0.0-esp32c3-GTRACK-sound-factory.bin',
        downloadUrl: 'https://example.com/bin',
        sizeBytes: 850000,
      );

      expect(info.project, equals('RC_Engine'));
      expect(info.version, equals('v1.0.0'));
      expect(info.chip, equals('esp32c3'));
      expect(info.board, equals('GTRACK'));
      expect(info.variant, equals('sound'));
      expect(info.displayName, equals('GTRACK'));
      expect(info.boardOrVariant, equals('GTRACK-sound'));
      expect(info.flashType, equals('factory'));
    });

    test('handles non-standard binary names gracefully', () {
      final info = FirmwareMarketplaceService.parseBinaryFilename(
        'firmware_custom_esp32s3.bin',
        downloadUrl: 'https://example.com/bin',
        sizeBytes: 600000,
      );

      expect(info.assetName, equals('firmware_custom_esp32s3.bin'));
      expect(info.displayName, equals('firmware_custom_esp32s3'));
      expect(info.chip, equals('esp32s3'));
      expect(info.formattedSize, isNotEmpty);
    });
  });

  group('FirmwareMarketplaceService Chip Matching', () {
    test('matches exact and substring chip names', () {
      final s3Info = FirmwareMarketplaceService.parseBinaryFilename(
        'RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin',
        downloadUrl: 'https://example.com/bin',
        sizeBytes: 887000,
      );

      expect(s3Info.matchesChip('ESP32-S3'), isTrue);
      expect(s3Info.matchesChip('esp32s3'), isTrue);
      expect(s3Info.matchesChip('ESP32-C3'), isFalse);
      expect(s3Info.matchesChip('ESP32'), isFalse);
    });

    test('finds best binary matching connected chip and board', () {
      final release = MarketplaceRelease(
        repoUrl: 'https://github.com/DragonRailway/RC_Engine',
        owner: 'DragonRailway',
        repo: 'RC_Engine',
        tagName: 'v1.0.0',
        version: '1.0.0',
        title: 'Release v1.0.0',
        changelog: 'Initial release',
        binaries: [
          FirmwareMarketplaceService.parseBinaryFilename(
            'RC_Engine-v1.0.0-esp32c3-GTRACK-factory.bin',
            downloadUrl: 'https://example.com/c3',
            sizeBytes: 800000,
          ),
          FirmwareMarketplaceService.parseBinaryFilename(
            'RC_Engine-v1.0.0-esp32s3-TRACKLINK_V3-factory.bin',
            downloadUrl: 'https://example.com/s3-tracklink',
            sizeBytes: 880000,
          ),
          FirmwareMarketplaceService.parseBinaryFilename(
            'RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin',
            downloadUrl: 'https://example.com/s3-mikro',
            sizeBytes: 880000,
          ),
        ],
      );

      final match = release.findBestBinary(
        connectedChip: 'ESP32-S3',
        connectedBoard: 'MIKRO_V2',
        preferFactory: true,
      );

      expect(match, isNotNull);
      expect(match!.assetName, equals('RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin'));
    });
  });

  group('FirmwareMarketplaceService Persistence & API Fetch', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getSavedRepos returns default repositories initially', () async {
      final service = FirmwareMarketplaceService();
      final repos = await service.getSavedRepos();
      expect(repos, contains('https://github.com/DragonRailway/RC_Engine'));
      expect(repos, contains('https://github.com/Radio-Kit/demo-fs-assets'));
    });

    test('addRepo persists new repository', () async {
      final service = FirmwareMarketplaceService();
      final added = await service.addRepo('https://github.com/test-org/custom-firmware');
      expect(added, isTrue);

      final repos = await service.getSavedRepos();
      expect(repos, contains('https://github.com/test-org/custom-firmware'));
    });

    test('removeRepo removes custom repository', () async {
      final service = FirmwareMarketplaceService();
      await service.addRepo('https://github.com/test-org/custom-firmware');
      await service.removeRepo('https://github.com/test-org/custom-firmware');

      final repos = await service.getSavedRepos();
      expect(repos, isNot(contains('https://github.com/test-org/custom-firmware')));
    });

    test('fetchRelease parses release and binaries from GitHub API mock', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/releases/latest')) {
          final payload = {
            'tag_name': 'v1.0.0',
            'name': 'RC_Engine v1.0.0',
            'published_at': '2026-08-27T12:00:00Z',
            'body': '## Changes\n- Initial release',
            'assets': [
              {
                'name': 'RC_Engine-v1.0.0-esp32s3-MIKRO_V2-factory.bin',
                'size': 876560,
                'browser_download_url': 'https://github.com/download/factory.bin',
              },
              {
                'name': 'RC_Engine-v1.0.0-esp32s3-MIKRO_V2-ota.bin',
                'size': 811024,
                'browser_download_url': 'https://github.com/download/ota.bin',
              },
              {
                'name': 'RC_Engine-configs.zip',
                'size': 15000000,
                'browser_download_url': 'https://github.com/download/configs.zip',
              }
            ]
          };
          return http.Response(jsonEncode(payload), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = FirmwareMarketplaceService(client: mockClient);
      final release = await service.fetchRelease('https://github.com/DragonRailway/RC_Engine');

      expect(release, isNotNull);
      expect(release!.tagName, equals('v1.0.0'));
      expect(release.binaries.length, equals(2));
      expect(release.factoryBinaries.length, equals(1));
      expect(release.otaBinaries.length, equals(1));
      expect(release.factoryBinaries.first.chip, equals('esp32s3'));
    });
  });
}
