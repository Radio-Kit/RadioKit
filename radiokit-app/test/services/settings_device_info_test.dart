import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/services/settings_protocol_service.dart';

void main() {
  group('SettingsProtocolService.parseDeviceInfoData', () {
    test('parses full device info with icon, board, and firmwareVersion', () {
      final nameBytes = utf8.encode('TrackLink Switch');
      final descBytes = utf8.encode('Living room controller');
      final uidBytes = utf8.encode('1234567890abcdef');
      final iconBytes = utf8.encode('gamepad');
      final boardBytes = utf8.encode('TRACKLINK_V3');
      final verBytes = utf8.encode('1.2.3');

      final payload = <int>[
        5, // proto version
        nameBytes.length,
        ...nameBytes,
        descBytes.length,
        ...descBytes,
        uidBytes.length,
        ...uidBytes,
        iconBytes.length,
        ...iconBytes,
        boardBytes.length,
        ...boardBytes,
        verBytes.length,
        ...verBytes,
      ];

      final parsed = SettingsProtocolService.parseDeviceInfoData(payload);
      expect(parsed, isNotNull);
      expect(parsed!.version, 5);
      expect(parsed.name, 'TrackLink Switch');
      expect(parsed.description, 'Living room controller');
      expect(parsed.uid, '1234567890abcdef');
      expect(parsed.icon, 'gamepad');
      expect(parsed.board, 'TRACKLINK_V3');
      expect(parsed.firmwareVersion, '1.2.3');
    });

    test('handles empty board and version strings gracefully', () {
      final nameBytes = utf8.encode('Generic');
      final descBytes = utf8.encode('');
      final uidBytes = utf8.encode('1234567890abcdef');

      final payload = <int>[
        5,
        nameBytes.length,
        ...nameBytes,
        0, // empty desc
        uidBytes.length,
        ...uidBytes,
        0, // empty icon
        0, // empty board
        0, // empty ver
      ];

      final parsed = SettingsProtocolService.parseDeviceInfoData(payload);
      expect(parsed, isNotNull);
      expect(parsed!.name, 'Generic');
      expect(parsed.icon, isNull);
      expect(parsed.board, isNull);
      expect(parsed.firmwareVersion, isNull);
    });
  });
}
