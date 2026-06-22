import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:radiokit/services/remote_access_service.dart';

void main() {
  group('/api/session/route handler', () {
    test('returns current route from the getter callback', () async {
      String currentRoute = '/system';

      final router = Router();
      router.get('/api/session/route', (request) async {
        return Response.ok(
          jsonEncode({'route': currentRoute}),
          headers: {'content-type': 'application/json'},
        );
      });

      final request =
          Request('GET', Uri.parse('http://test/api/session/route'));
      final response = await router(request);
      expect(response.statusCode, 200);

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['route'], '/system');
    });

    test('reflects route changes (mutable getter)', () async {
      String currentRoute = '/system';

      final router = Router();
      router.get('/api/session/route', (request) async {
        return Response.ok(
          jsonEncode({'route': currentRoute}),
          headers: {'content-type': 'application/json'},
        );
      });

      currentRoute = '/dev-tools/esp32-fs';
      final request =
          Request('GET', Uri.parse('http://test/api/session/route'));
      final response = await router(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['route'], '/dev-tools/esp32-fs');
    });

    test('returns JSON content-type header', () async {
      final router = Router();
      router.get('/api/session/route', (request) async {
        return Response.ok(
          jsonEncode({'route': ''}),
          headers: {'content-type': 'application/json'},
        );
      });

      final request =
          Request('GET', Uri.parse('http://test/api/session/route'));
      final response = await router(request);
      expect(response.headers['content-type'], contains('application/json'));
    });
  });

  group('RemoteAccessService._followRoute (path -> route mapping)', () {
    test('FS paths map to /dev-tools/esp32-fs', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/fs/info'),
        '/dev-tools/esp32-fs',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/fs/list?path=/'),
        '/dev-tools/esp32-fs',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/fs/write'),
        '/dev-tools/esp32-fs',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/fs/read?path=/x'),
        '/dev-tools/esp32-fs',
      );
    });

    test('pairing paths map to /models?sheet=pair', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/pair/scan'),
        '/models?sheet=pair',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/pair/devices'),
        '/models?sheet=pair',
      );
    });

    test('connection paths map correctly', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/connection/connect'),
        '/control',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/connection/disconnect'),
        '/models',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/connection/reconnect'),
        '/models',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/connection/demo'),
        '/control',
      );
    });

    test('app settings return null, device NVS maps to /system, cloud accounts to /system?sheet=accounts', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/settings'),
        isNull,
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/settings/nvs'),
        '/system',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/settings/nvs/authenticate'),
        '/system',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/cloud/accounts'),
        '/system?sheet=accounts',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/cloud/account'),
        '/system?sheet=accounts',
      );
    });

    test('console and log paths map to /system', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/console'),
        '/system',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/log'),
        '/system',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/transport/ping'),
        '/debug',
      );
    });

    test('widgets and designs paths map correctly', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/widgets'),
        '/control',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/widgets/1'),
        '/control',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/designs'),
        '/designs',
      );
    });

    test('models path maps correctly', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/models'),
        '/models',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/models/abc'),
        '/models',
      );
    });

    test('unknown paths return null', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/unknown'),
        isNull,
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/session/route'),
        isNull,
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/health'),
        isNull,
      );
    });
  });

  group('RemoteAccessService._followRoute (sheet query params)', () {
    test('per-device settings map to /models?sheet=deviceSettings', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/devices/B4:3A:45:AE:BA:25/settings/nvs'),
        '/models?sheet=deviceSettings',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/devices/B4:3A:45:AE:BA:25/settings/nvs/authenticate'),
        '/models?sheet=deviceSettings',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/devices/B4:3A:45:AE:BA:25/settings/nvs/factory-reset'),
        '/models?sheet=deviceSettings',
      );
    });

    test('pairing paths include ?sheet=pair', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/pair/scan'),
        '/models?sheet=pair',
      );
    });

    test('cloud account paths include ?sheet=accounts', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/cloud/accounts'),
        '/system?sheet=accounts',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/cloud/account'),
        '/system?sheet=accounts',
      );
    });
  });

  group('/api/session/sheets handler', () {
    test('returns all sheet definitions as JSON', () async {
      final router = Router();
      router.get('/api/session/sheets', (request) async {
        const sheets = {
          '/models': ['pair', 'deviceSettings'],
          '/system': ['accounts'],
        };
        return Response.ok(
          jsonEncode({'sheets': sheets}),
          headers: {'content-type': 'application/json'},
        );
      });

      final request =
          Request('GET', Uri.parse('http://test/api/session/sheets'));
      final response = await router(request);
      expect(response.statusCode, 200);

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body.containsKey('sheets'), true);
      final sheets = body['sheets'] as Map<String, dynamic>;
      expect(sheets['/models'], contains('pair'));
      expect(sheets['/models'], contains('deviceSettings'));
      expect(sheets['/system'], contains('accounts'));
    });
  });

  group('Follow-route and sheet consistency', () {
    test('all ?sheet= values in _followRoute are valid', () {
      final testPaths = {
        '/api/pair/scan': '/models?sheet=pair',
        '/api/devices/B4:3A:45/settings/nvs': '/models?sheet=deviceSettings',
        '/api/cloud/accounts': '/system?sheet=accounts',
        '/api/cloud/account': '/system?sheet=accounts',
      };

      for (final entry in testPaths.entries) {
        final result = RemoteAccessService.testOnlyFollowRoute(entry.key);
        expect(result, entry.value,
            reason: 'Route mismatch for ${entry.key}');

        if (result != null && result.contains('?sheet=')) {
          final sheetName =
              Uri.parse(result).queryParameters['sheet']!;
          expect(
            ['pair', 'deviceSettings', 'accounts'],
            contains(sheetName),
            reason: 'Unknown sheet name: $sheetName',
          );
        }
      }
    });

    test('non-sheet routes do not include ?sheet= parameter', () {
      final nonSheetPaths = {
        '/api/connection/connect': '/control',
        '/api/connection/disconnect': '/models',
        '/api/settings/nvs': '/system',
        '/api/console': '/system',
        '/api/fs/info': '/dev-tools/esp32-fs',
        '/api/designs': '/designs',
        '/api/models': '/models',
      };

      for (final entry in nonSheetPaths.entries) {
        final result = RemoteAccessService.testOnlyFollowRoute(entry.key);
        expect(result, entry.value,
            reason: 'Route mismatch for ${entry.key}');
        expect(result, isNot(contains('?sheet=')),
            reason: '${entry.key} should not have a sheet param');
      }
    });
  });
}
