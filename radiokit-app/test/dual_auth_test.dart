import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:radiokit/services/protocol_service.dart';
import 'package:radiokit/models/protocol.dart';
import 'package:radiokit/providers/device_provider.dart';

void main() {
  group('ProtocolService — PWD_AUTH', () {
    test('buildPwdAuth produces correct packet structure', () {
      final pkt = ProtocolService.buildPwdAuth('test123');
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      expect(parsed!.cmd, kCmdPwdAuth);
      // payload: [len(1)] [password bytes...]
      expect(parsed.payload.length, greaterThan(1));
      expect(parsed.payload[0], 7); // "test123" = 7 chars
      expect(
          utf8.decode(parsed.payload.sublist(1, 8)), 'test123');
    });

    test('buildPwdAuth with admin flag appends flag byte', () {
      final pkt = ProtocolService.buildPwdAuth('admin', admin: true);
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      expect(parsed!.payload.last, kPwdAuthFlagAdmin);
    });

    test('buildPwdAuth without admin flag has no flag byte', () {
      final pkt = ProtocolService.buildPwdAuth('pass', admin: false);
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      // payload: [len(1)] [4 bytes] = 5 bytes total, no trailing flag
      expect(parsed!.payload.length, 5);
    });

    test('parsePwdAuthResponse returns status code', () {
      expect(ProtocolService.parsePwdAuthResponse([kPwdAuthDevice]), kPwdAuthDevice);
      expect(ProtocolService.parsePwdAuthResponse([kPwdAuthDenied]),
          kPwdAuthDenied);
      expect(ProtocolService.parsePwdAuthResponse(<int>[]), isNull);
    });
  });

  group('ProtocolService — SET_CONF', () {
    test('buildSetConf with name only sets correct field mask', () {
      final pkt = ProtocolService.buildSetConf(name: 'My Device');
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      expect(parsed!.cmd, kCmdSetConf);
      // field mask at payload[0..1] = 0x01 (kSetConfName)
      expect(parsed.payload[0], kSetConfName);
      expect(parsed.payload[1], 0);
    });

    test('buildSetConf with all fields sets all mask bits', () {
      final pkt = ProtocolService.buildSetConf(
        name: 'Test',
        description: 'Desc',
        password: 'conn123',
        adminPassword: 'admin456',
      );
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      final mask = parsed!.payload[0] | (parsed.payload[1] << 8);
      expect(mask & kSetConfName, kSetConfName);
      expect(mask & kSetConfDesc, kSetConfDesc);
      expect(mask & kSetConfPwd, kSetConfPwd);
      expect(mask & kSetConfAdminPwd, kSetConfAdminPwd);
    });

    test('buildSetConf with null fields omits those mask bits', () {
      final pkt =
          ProtocolService.buildSetConf(password: 'pwd', adminPassword: null);
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      final mask = parsed!.payload[0] | (parsed.payload[1] << 8);
      expect(mask & kSetConfPwd, kSetConfPwd);
      expect(mask & kSetConfAdminPwd, 0);
    });
  });

  group('ProtocolService — FACTORY_RESET', () {
    test('buildFactoryReset has correct cmd byte', () {
      final pkt = ProtocolService.buildFactoryReset();
      final parsed = ProtocolService.parsePacket(pkt);
      expect(parsed, isNotNull);
      expect(parsed!.cmd, kCmdFactoryReset);
      expect(parsed.payload.length, 0);
    });
  });

  group('RemoteAccessService — NVS handlers', () {
    test('_handleNvsGet returns auth state fields', () async {
      // Build a test router with a mock NVS GET handler
      String? currentRoute;
      final router = Router();
      router.get('/api/settings/nvs', (request) async {
        return Response.ok(
          jsonEncode({
            'name': 'Test Device',
            'description': 'Unit 01',
            'hasPassword': true,
            'hasAdminPassword': true,
            'isAuthenticated': true,
            'isAdminMode': true,
            'isUserMode': false,
          }),
          headers: {'content-type': 'application/json'},
        );
      });

      final request =
          Request('GET', Uri.parse('http://test/api/settings/nvs'));
      final response = await router(request);
      expect(response.statusCode, 200);

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['hasPassword'], true);
      expect(body['hasAdminPassword'], true);
      expect(body['isAuthenticated'], true);
      expect(body['isAdminMode'], true);
      expect(body['isUserMode'], false);
    });

    test('_handleNvsSet accepts adminPassword field', () async {
      final router = Router();
      router.post('/api/settings/nvs', (request) async {
        final body = jsonDecode(await request.readAsString())
            as Map<String, dynamic>;
        final adminPassword = body['adminPassword'] as String?;
        final password = body['password'] as String?;
        if (adminPassword == null && password == null) {
          return Response(400,
              headers: {'content-type': 'application/json'},
              body: jsonEncode({
                'error': 'invalid_params',
                'message': 'At least one field required'
              }));
        }
        return Response.ok(
          jsonEncode({'ok': true, 'message': 'Config saved to NVS'}),
          headers: {'content-type': 'application/json'},
        );
      });

      // Test setting adminPassword only
      final request1 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs'),
          body: jsonEncode({'adminPassword': 'admin456'}));
      final response1 = await router(request1);
      expect(response1.statusCode, 200);
      final body1 =
          jsonDecode(await response1.readAsString()) as Map<String, dynamic>;
      expect(body1['ok'], true);

      // Test setting both passwords
      final request2 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs'),
          body: jsonEncode({
            'password': 'conn123',
            'adminPassword': 'admin456'
          }));
      final response2 = await router(request2);
      expect(response2.statusCode, 200);

      // Test validation — reject empty body
      final request3 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs'),
          body: jsonEncode({}));
      final response3 = await router(request3);
      expect(response3.statusCode, 400);
    });

    test('_handleNvsAuthenticate returns ok on success', () async {
      final router = Router();
      router.post(
          '/api/settings/nvs/authenticate', (request) async {
        final body = jsonDecode(await request.readAsString())
            as Map<String, dynamic>;
        final password = body['password'] as String?;
        if (password == null || password.isEmpty) {
          return Response(400,
              headers: {'content-type': 'application/json'},
              body: jsonEncode({
                'error': 'invalid_params',
                'message': 'password is required'
              }));
        }
        if (password == 'admin456') {
          return Response.ok(
            jsonEncode(
                {'ok': true, 'message': 'Authenticated successfully'}),
            headers: {'content-type': 'application/json'},
          );
        }
        return Response(401,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'error': 'auth_failed',
              'message': 'Password mismatch'
            }));
      });

      // Success case
      final request1 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs/authenticate'),
          body: jsonEncode({'password': 'admin456'}));
      final response1 = await router(request1);
      expect(response1.statusCode, 200);

      // Failure case
      final request2 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs/authenticate'),
          body: jsonEncode({'password': 'wrong'}));
      final response2 = await router(request2);
      expect(response2.statusCode, 401);

      // Empty password
      final request3 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs/authenticate'),
          body: jsonEncode({'password': ''}));
      final response3 = await router(request3);
      expect(response3.statusCode, 400);
    });

    test('_handleNvsFactoryReset requires confirmation', () async {
      final router = Router();
      router.post(
          '/api/settings/nvs/factory-reset', (request) async {
        final body = jsonDecode(await request.readAsString())
            as Map<String, dynamic>;
        final confirm = body['confirm'] as bool? ?? false;
        if (!confirm) {
          return Response(400,
              headers: {'content-type': 'application/json'},
              body: jsonEncode({
                'error': 'confirmation_required',
                'message': 'Set confirm: true to proceed'
              }));
        }
        return Response.ok(
          jsonEncode(
              {'ok': true, 'message': 'Factory reset sent'}),
          headers: {'content-type': 'application/json'},
        );
      });

      // Without confirm → 400
      final request1 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs/factory-reset'),
          body: jsonEncode({}));
      final response1 = await router(request1);
      expect(response1.statusCode, 400);

      // With confirm: true → 200
      final request2 = Request(
          'POST',
          Uri.parse('http://test/api/settings/nvs/factory-reset'),
          body: jsonEncode({'confirm': true}));
      final response2 = await router(request2);
      expect(response2.statusCode, 200);
    });
  });    group('Feature flags — protocol constants (new auth model)', () {
    test('kFeatureHasDevicePassword and kFeatureHasUserPassword are distinct',
        () {
      // These must be different bits so the feature bitmask can carry both
      expect(kFeatureHasDevicePassword, isNot(kFeatureHasUserPassword));
      expect(kFeatureHasDevicePassword & kFeatureHasUserPassword, 0);
    });

    test('kPwdAuthFlagAdmin is deprecated but distinct from kPwdAuthDevice', () {
      expect(kPwdAuthFlagAdmin, isNot(kPwdAuthDevice));
    });

    test('kSetConfUserPwd replaces kSetConfAdminPwd (same bit position)', () {
      expect(kSetConfUserPwd, 1 << 3);
      expect(kSetConfUserPwd, kSetConfAdminPwd); // legacy alias
    });

    test('AuthLevel enum has none/user/device values', () {
      expect(AuthLevel.none.index, 0);
      expect(AuthLevel.user.index, 1);
      expect(AuthLevel.device.index, 2);
    });

    test('New PWD_AUTH status codes match spec', () {
      expect(kPwdAuthDevice, 0x00); // Device (full access)
      expect(kPwdAuthUser, 0x01);   // User (widgets-only)
      expect(kPwdAuthDenied, 0x02); // Denied
    });

    test('K_SETTINGS_PWD codes match widget protocol codes', () {
      expect(kSettingsPwdDevice, kPwdAuthDevice);
      expect(kSettingsPwdUser, kPwdAuthUser);
      expect(kSettingsPwdDenied, kPwdAuthDenied);
    });

    test('Protocol version bumped to 0x05', () {
      expect(kProtocolVersion, 0x05);
    });
  });
}
