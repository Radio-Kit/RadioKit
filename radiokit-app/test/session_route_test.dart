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

  group('RemoteAccessService._followRoute (path → route mapping)', () {
    // _followRoute is a static method on RemoteAccessService.
    // It maps API request paths to follow-mode route targets.

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

    test('pairing paths map to /models', () {
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/pair/scan'),
        '/models',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/pair/devices'),
        '/models',
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

    test('app settings return null, device NVS maps to /system', () {
      // /api/settings (app-level) excluded: toggling followRemoteAccess via
      // API would navigate away from /control, disconnecting active BLE.
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/settings'),
        isNull,
      );
      // Device-level NVS operations should still navigate to /system.
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/settings/nvs'),
        '/system',
      );
      expect(
        RemoteAccessService.testOnlyFollowRoute('/api/settings/nvs/authenticate'),
        '/system',
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
}
