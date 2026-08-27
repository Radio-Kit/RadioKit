import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radiokit/services/repo_tree_service.dart';

void main() {
  group('RepoTreeService URL Parsing', () {
    test('parse plain repository URL', () {
      final info = RepoTreeService.parseGithubUrl('https://github.com/rambros3d/RadioKit');
      expect(info, isNotNull);
      expect(info!.owner, 'rambros3d');
      expect(info.repo, 'RadioKit');
      expect(info.ref, 'HEAD');
      expect(info.subfolder, '');
      expect(info.rawBase, 'https://raw.githubusercontent.com/rambros3d/RadioKit/HEAD');
      expect(info.rawFileUrl('configs/sensors.json'),
          'https://raw.githubusercontent.com/rambros3d/RadioKit/HEAD/configs/sensors.json');
    });

    test('parse URL with .git suffix and trailing slash', () {
      final info = RepoTreeService.parseGithubUrl('https://github.com/owner/my-repo.git/');
      expect(info, isNotNull);
      expect(info!.owner, 'owner');
      expect(info.repo, 'my-repo');
      expect(info.ref, 'HEAD');
      expect(info.subfolder, '');
    });

    test('parse branch-qualified tree URL with subfolder', () {
      final info = RepoTreeService.parseGithubUrl(
          'https://github.com/rambros3d/RadioKit/tree/main/configs/sensors');
      expect(info, isNotNull);
      expect(info!.owner, 'rambros3d');
      expect(info.repo, 'RadioKit');
      expect(info.ref, 'main');
      expect(info.subfolder, 'configs/sensors');
      expect(info.rawFileUrl('configs/sensors/cal.json'),
          'https://raw.githubusercontent.com/rambros3d/RadioKit/main/configs/sensors/cal.json');
    });

    test('parse blob URL', () {
      final info = RepoTreeService.parseGithubUrl(
          'https://github.com/owner/repo/blob/dev/web/index.html');
      expect(info, isNotNull);
      expect(info!.owner, 'owner');
      expect(info.repo, 'repo');
      expect(info.ref, 'dev');
      expect(info.subfolder, 'web/index.html');
    });

    test('return null for non-GitHub URLs', () {
      expect(RepoTreeService.parseGithubUrl('https://gitlab.com/owner/repo'), isNull);
      expect(RepoTreeService.parseGithubUrl('https://example.com/file.zip'), isNull);
      expect(RepoTreeService.parseGithubUrl(''), isNull);
      expect(RepoTreeService.parseGithubUrl('not-a-url'), isNull);
    });
  });

  group('RepoTreeService Tree Fetching', () {
    test('fetches and filters tree by subfolder', () async {
      final mockTreeResponse = jsonEncode({
        'sha': 'abc1234',
        'tree': [
          {
            'path': 'configs',
            'mode': '040000',
            'type': 'tree',
            'sha': '111',
          },
          {
            'path': 'configs/sensors',
            'mode': '040000',
            'type': 'tree',
            'sha': '222',
          },
          {
            'path': 'configs/sensors/data.json',
            'mode': '100644',
            'type': 'blob',
            'size': 1024,
            'sha': '333',
          },
          {
            'path': 'configs/sensors/sub/cal.bin',
            'mode': '100644',
            'type': 'blob',
            'size': 2048,
            'sha': '444',
          },
          {
            'path': 'src/main.cpp',
            'mode': '100644',
            'type': 'blob',
            'size': 512,
            'sha': '555',
          },
        ]
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/git/trees/main')) {
          return http.Response(mockTreeResponse, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = RepoTreeService(client: mockClient);
      final info = RepoUrlInfo(
        owner: 'rambros3d',
        repo: 'RadioKit',
        ref: 'main',
        subfolder: 'configs/sensors',
      );

      final entries = await service.fetchTree(info);
      expect(entries.length, 2);

      expect(entries[0].name, 'data.json');
      expect(entries[0].relativePath, 'data.json');
      expect(entries[0].size, 1024);
      expect(entries[0].isDirectory, isFalse);
      expect(entries[0].downloadUrl,
          'https://raw.githubusercontent.com/rambros3d/RadioKit/main/configs/sensors/data.json');

      expect(entries[1].name, 'cal.bin');
      expect(entries[1].relativePath, 'sub/cal.bin');
      expect(entries[1].size, 2048);
      expect(entries[1].isDirectory, isFalse);
    });

    test('downloads raw file bytes', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://raw.githubusercontent.com/test/repo/HEAD/data.bin') {
          return http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = RepoTreeService(client: mockClient);
      final bytes = await service.downloadFile(
          'https://raw.githubusercontent.com/test/repo/HEAD/data.bin');
      expect(bytes, Uint8List.fromList([1, 2, 3, 4]));
    });
  });
}
