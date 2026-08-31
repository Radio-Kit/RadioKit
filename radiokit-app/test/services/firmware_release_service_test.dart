import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radiokit/services/firmware_release_service.dart';

void main() {
  group('FirmwareReleaseService URL Parsing', () {
    test('parse plain github repo URL', () {
      final parsed = FirmwareReleaseService.parseGithubRepo(
          'https://github.com/Radio-Kit/demo-fs-assets');
      expect(parsed, isNotNull);
      expect(parsed!.owner, 'Radio-Kit');
      expect(parsed.repo, 'demo-fs-assets');
    });

    test('parse URL with .git suffix and subpaths', () {
      final parsed = FirmwareReleaseService.parseGithubRepo(
          'https://github.com/Radio-Kit/demo-fs-assets.git/tree/main');
      expect(parsed, isNotNull);
      expect(parsed!.owner, 'Radio-Kit');
      expect(parsed.repo, 'demo-fs-assets');
    });

    test('return null for non-github URLs', () {
      expect(FirmwareReleaseService.parseGithubRepo('https://example.com/repo'), isNull);
      expect(FirmwareReleaseService.parseGithubRepo(''), isNull);
      expect(FirmwareReleaseService.parseGithubRepo('invalid'), isNull);
    });
  });

  group('FirmwareReleaseService Semver Comparison', () {
    test('normalizes version strings', () {
      expect(FirmwareReleaseService.normalizeVersion('v1.2.3'), '1.2.3');
      expect(FirmwareReleaseService.normalizeVersion('V2.0.0'), '2.0.0');
      expect(FirmwareReleaseService.normalizeVersion('  1.0.0  '), '1.0.0');
    });

    test('compares semver versions correctly', () {
      expect(FirmwareReleaseService.compareSemver('1.2.3', '1.2.0'), greaterThan(0));
      expect(FirmwareReleaseService.compareSemver('1.10.0', '1.2.0'), greaterThan(0));
      expect(FirmwareReleaseService.compareSemver('2.0.0', '1.9.9'), greaterThan(0));
      expect(FirmwareReleaseService.compareSemver('1.0.0', '1.0.0'), equals(0));
      expect(FirmwareReleaseService.compareSemver('v1.0.0', '1.0.0'), equals(0));
      expect(FirmwareReleaseService.compareSemver('1.0.0', '1.0.1'), lessThan(0));
      expect(FirmwareReleaseService.compareSemver('1.2.0', '2.0.0'), lessThan(0));
    });

    test('isNewerVersion checks', () {
      expect(FirmwareReleaseService.isNewerVersion('v2.0.0', '1.0.0'), isTrue);
      expect(FirmwareReleaseService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(FirmwareReleaseService.isNewerVersion('0.9.0', '1.0.0'), isFalse);
      expect(FirmwareReleaseService.isNewerVersion('', '1.0.0'), isFalse);
      expect(FirmwareReleaseService.isNewerVersion('1.0.0', ''), isFalse);
    });
  });

  group('FirmwareRelease Asset Matching', () {
    const release = FirmwareRelease(
      tagName: 'v2.1.0',
      version: '2.1.0',
      title: 'Release 2.1.0',
      changelog: 'Awesome updates',
      assets: const [
        ReleaseAsset(
          name: 'README.md',
          size: 100,
          downloadUrl: 'https://example.com/readme.md',
        ),
        ReleaseAsset(
          name: 'MIKRO_V2-full.bin',
          size: 4194304,
          downloadUrl: 'https://example.com/mikro-full.bin',
        ),
        ReleaseAsset(
          name: 'MIKRO_V2-ota.bin',
          size: 1048576,
          downloadUrl: 'https://example.com/mikro-ota.bin',
        ),
        ReleaseAsset(
          name: 'TRACKLINK_V3-ota.bin',
          size: 2097152,
          downloadUrl: 'https://example.com/tracklink-ota.bin',
        ),
      ],
    );

    test('filters binAssets and otaBinAssets', () {
      expect(release.binAssets.length, 3);
      expect(release.hasOtaBinAssets, isTrue);
      expect(release.otaBinAssets.length, 2);
      expect(release.otaBinAssets.map((a) => a.name),
          containsAll(['MIKRO_V2-ota.bin', 'TRACKLINK_V3-ota.bin']));
    });

    test('getFilteredBinAssets defaults to ota binaries when present', () {
      expect(release.getFilteredBinAssets(showAll: false).length, 2);
      expect(release.getFilteredBinAssets(showAll: true).length, 3);
    });

    test('finds exact matching asset by board name with -ota suffix', () {
      final asset = release.findBestAsset('MIKRO_V2');
      expect(asset, isNotNull);
      expect(asset!.name, 'MIKRO_V2-ota.bin');
    });

    test('finds substring matching asset by board name', () {
      final asset = release.findBestAsset('tracklink');
      expect(asset, isNotNull);
      expect(asset!.name, 'TRACKLINK_V3-ota.bin');
    });

    test('falls back to first candidate bin asset when board name does not match', () {
      final asset = release.findBestAsset('UNKNOWN_BOARD');
      expect(asset, isNotNull);
      expect(asset!.name, 'MIKRO_V2-ota.bin');
    });
  });

  group('FirmwareReleaseService HTTP Operations', () {
    test('fetches latest release successfully', () async {
      final mockReleaseJson = jsonEncode({
        'tag_name': 'v2.0.1',
        'name': 'RadioKit Firmware v2.0.1',
        'published_at': '2026-08-20T12:00:00Z',
        'body': 'Fixed OTA transfer stability',
        'prerelease': false,
        'assets': [
          {
            'name': 'MIKRO_V2.bin',
            'size': 102400,
            'browser_download_url': 'https://github.com/Radio-Kit/demo-fs-assets/releases/download/v2.0.1/MIKRO_V2.bin',
            'content_type': 'application/octet-stream',
          }
        ]
      });

      final mockClient = MockClient((request) async {
        if (request.url.path == '/repos/Radio-Kit/demo-fs-assets/releases/latest') {
          return http.Response(mockReleaseJson, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = FirmwareReleaseService(client: mockClient);
      final release = await service.fetchLatestRelease('https://github.com/Radio-Kit/demo-fs-assets');

      expect(release, isNotNull);
      expect(release!.tagName, 'v2.0.1');
      expect(release.version, '2.0.1');
      expect(release.title, 'RadioKit Firmware v2.0.1');
      expect(release.changelog, 'Fixed OTA transfer stability');
      expect(release.binAssets.length, 1);
      expect(release.binAssets.first.name, 'MIKRO_V2.bin');
      expect(release.binAssets.first.size, 102400);
    });

    test('returns null when repo has no releases (404)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = FirmwareReleaseService(client: mockClient);
      final release = await service.fetchLatestRelease('https://github.com/Radio-Kit/demo-fs-assets');
      expect(release, isNull);
    });

    test('streams binary download with progress updates', () async {
      final mockBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04]);

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable([
            mockBytes.sublist(0, 4),
            mockBytes.sublist(4, 8),
          ]),
          200,
          contentLength: mockBytes.length,
        );
      });

      final service = FirmwareReleaseService(client: mockClient);
      final progressEvents = <int>[];
      final result = await service.downloadAsset(
        'https://example.com/firmware.bin',
        onProgress: (received, total) {
          progressEvents.add(received);
        },
      );

      expect(result, mockBytes);
      expect(progressEvents, [4, 8]);
    });
  });
}
