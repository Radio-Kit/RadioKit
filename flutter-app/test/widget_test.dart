import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/services/protocol_service.dart';
import 'package:radiokit/models/protocol.dart';
import 'package:radiokit/models/widget_config.dart';

void main() {
  group('ProtocolService', () {
    group('CRC-16/CCITT', () {
      test('builds GET_CONF packet with correct start byte', () {
        final packet = ProtocolService.buildGetConf();
        expect(packet[0], equals(kStartByte)); // START = 0x55
        expect(packet[3], equals(kCmdGetConf)); // CMD = 0x01
      });

      test('builds correct minimum packet length', () {
        final packet = ProtocolService.buildPing();
        // Minimum: 1(start)+2(len)+1(cmd)+2(crc) = 6 bytes
        expect(packet.length, equals(6));
      });

      test('packet length field matches actual packet length', () {
        final packet = ProtocolService.buildGetConf();
        final lengthField = packet[1] | (packet[2] << 8);
        expect(lengthField, equals(packet.length));
      });

      test('parses its own output correctly', () {
        final packet = ProtocolService.buildPing();
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdPing));
        expect(parsed.payload.length, equals(0));
      });

      test('returns null on CRC mismatch', () {
        final packet = ProtocolService.buildPing().toList();
        // Corrupt a CRC byte
        packet[packet.length - 1] ^= 0xFF;
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNull);
      });

      test('returns null on short data', () {
        final parsed = ProtocolService.parsePacket([0x55, 0x06]);
        expect(parsed, isNull);
      });

      test('returns null on wrong start byte', () {
        final packet = ProtocolService.buildPing().toList();
        packet[0] = 0xAA; // Wrong start byte
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNull);
      });
    });

    group('CONF_DATA parsing', () {
      test('returns empty list for zero widgets', () {
        final payload = [
          0x03, // version
          0x00, // orientation
          0x00, // 0 widgets
          0x00, // nameLen=0
          0x00, // descLen=0
          0x00, // pwdLen=0
          0x05, 0x74, 0x68, 0x65, 0x6d, 0x65, // themeLen=5, "theme"
        ];
        final parsed = ProtocolService.parseConfData(payload);
        expect(parsed, isNotNull);
        expect(parsed!.widgets, isEmpty);
      });

      test('returns null for truncated payload', () {
        final payload = [0x01]; // Missing count byte
        final parsed = ProtocolService.parseConfData(payload);
        expect(parsed, isNull);
      });

      test('parses a single button widget descriptor', () {
        // [version][orientation][count][nameLen][name...][descLen][pwdLen][themeLen][theme...][TYPE][ID][X][Y][SCALE][ASPECT][ROT_L][ROT_H][STYLE][VARIANT][STR_MASK][STRINGS...]
        final payload = [
          0x03, // version
          0x00, // orientation
          0x01, // 1 widget
          0x04, 0x54, 0x65, 0x73, 0x74, // nameLen=4, "Test"
          0x00, // descLen=0
          0x00, // pwdLen=0
          0x05, 0x74, 0x68, 0x65, 0x6d, 0x65, // themeLen=5, "theme"
          0x01, // TYPE = BUTTON
          0x05, // WIDGET_ID = 5
          0x64, // X = 100
          0xC8, // Y = 200
          0x14, // Scale = 20 (2.0x)
          0x0A, // Aspect = 10 (1.0)
          0x00, 0x00, // Rotation = 0
          0x00, // Style
          0x00, // Variant
          0x01, // StrMask (Label only)
          0x03, 0x42, 0x54, 0x4E, // Prefix(3) + "BTN"
        ];
        final parsed = ProtocolService.parseConfData(payload);
        expect(parsed, isNotNull);
        expect(parsed!.widgets.length, equals(1));
        expect(parsed.widgets[0].typeId, equals(kWidgetButton));
        expect(parsed.widgets[0].widgetId, equals(5));
        expect(parsed.widgets[0].x, equals(100.0));
        expect(parsed.widgets[0].y, equals(200.0));
        expect(parsed.widgets[0].label, equals('BTN'));
      });
    });

    group('SET_INPUT building', () {
      test('builds correct payload for empty widget list', () {
        final packet = ProtocolService.buildSetInput([], _emptyState());
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdSetInput));
        expect(parsed.payload.length, equals(0));
      });
    });
  });
}

RadioWidgetState _emptyState() {
  return const RadioWidgetState(inputValues: {}, outputValues: {});
}
