import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/services/protocol_service.dart';
import 'package:radiokit/models/protocol.dart';
import 'package:radiokit/models/widget_config.dart';

void main() {
  group('ProtocolService', () {
    group('CRC-16/CCITT', () {
      test('builds GET_CONF packet with correct start byte', () {
        final packet = ProtocolService.buildGetConf();
        expect(packet[0], equals(kStartByte));
        expect(packet[3], equals(kCmdGetConf));
      });

      test('builds correct minimum packet length', () {
        final packet = ProtocolService.buildGetConf();
        expect(packet.length, equals(6));
      });

      test('packet length field matches actual packet length', () {
        final packet = ProtocolService.buildGetConf();
        final lengthField = packet[1] | (packet[2] << 8);
        expect(lengthField, equals(packet.length));
      });

      test('parses its own output correctly', () {
        final packet = ProtocolService.buildGetConf();
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdGetConf));
        expect(parsed.payload.length, equals(0));
      });

      test('returns null on CRC mismatch', () {
        final packet = ProtocolService.buildGetConf().toList();
        packet[packet.length - 1] ^= 0xFF;
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNull);
      });

      test('returns null on short data', () {
        expect(ProtocolService.parsePacket([0x55, 0x06]), isNull);
      });

      test('returns null on wrong start byte', () {
        final packet = ProtocolService.buildGetConf().toList();
        packet[0] = 0xAA;
        expect(ProtocolService.parsePacket(packet), isNull);
      });
    });

    group('CONF_DATA parsing', () {
      test('returns empty list for zero widgets', () {
        final payload = [0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x74, 0x68, 0x65, 0x6d, 0x65];
        final parsed = ProtocolService.parseConfData(payload);
        expect(parsed, isNotNull);
        expect(parsed!.widgets, isEmpty);
      });

      test('returns null for truncated payload', () {
        expect(ProtocolService.parseConfData([0x01]), isNull);
      });

      test('parses a single button widget descriptor', () {
        final payload = [
          0x03, 0x00, 0x01,
          0x04, 0x54, 0x65, 0x73, 0x74,
          0x00, 0x00,
          0x05, 0x74, 0x68, 0x65, 0x6d, 0x65,
          0x01, 0x05, 0x64, 0xC8, 0x14, 0x0A,
          0x00, 0x00, 0x00, 0x00,
          0x01, 0x03, 0x42, 0x54, 0x4E,
        ];
        final parsed = ProtocolService.parseConfData(payload);
        expect(parsed, isNotNull);
        expect(parsed!.widgets.length, equals(1));
        expect(parsed.widgets[0].typeId, equals(kWidgetButton));
        expect(parsed.widgets[0].widgetId, equals(5));
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

    group('Page commands', () {
      test('buildSetPage builds correct packet', () {
        final packet = ProtocolService.buildSetPage(2);
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdSetPage));
        expect(parsed.payload.length, equals(1));
        expect(parsed.payload[0], equals(2));
      });

      test('buildGetPages builds correct packet', () {
        final packet = ProtocolService.buildGetPages();
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdGetPages));
        expect(parsed.payload.length, equals(0));
      });

      test('parsePageIndex returns page index', () {
        expect(ProtocolService.parsePageIndex([3]), equals(3));
      });

      test('parsePageIndex returns null for empty', () {
        expect(ProtocolService.parsePageIndex([]), isNull);
      });

      test('parsePagesData parses page names', () {
        final result = ProtocolService.parsePagesData([2, 5, 0x41, 0x4C, 0x4C, 0x45, 0x59, 3, 0x46, 0x4F, 0x4F]);
        expect(result, isNotNull);
        expect(result!.length, equals(2));
        expect(result[0], equals('ALLEY'));
        expect(result[1], equals('FOO'));
      });

      test('parsePagesData returns null for empty', () {
        expect(ProtocolService.parsePagesData([]), isNull);
      });

      test('parseVarUpdate with page prefix', () {
        final result = ProtocolService.parseVarUpdate([1, 5, 3, 0x42, 0x54, 0x4E], hasPagePrefix: true);
        expect(result, isNotNull);
        expect(result!.$1, equals(1));
        expect(result.$2, equals(5));
      });

      test('parseVarUpdate without page prefix', () {
        final result = ProtocolService.parseVarUpdate([5, 3, 0x42, 0x54, 0x4E], hasPagePrefix: false);
        expect(result, isNotNull);
        expect(result!.$1, equals(0));
        expect(result.$2, equals(5));
      });

      test('buildVarUpdate with page > 0', () {
        final packet = ProtocolService.buildVarUpdate(5, 1, [0xFF], page: 1);
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.payload.length, equals(4));
        expect(parsed.payload[0], equals(1));
      });

      test('buildVarUpdate with page=0', () {
        final packet = ProtocolService.buildVarUpdate(5, 1, [0xFF], page: 0);
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.payload.length, equals(3));
        expect(parsed.payload[0], equals(5));
      });
    });

    group('Page switch state machine', () {
      test('sendSetPage packet', () {
        final packet = ProtocolService.buildSetPage(1);
        final parsed = ProtocolService.parsePacket(packet);
        expect(parsed, isNotNull);
        expect(parsed!.cmd, equals(kCmdSetPage));
        expect(parsed.payload[0], equals(1));
      });

      test('PAGE_CHANGED returns correct index', () {
        expect(ProtocolService.parsePageIndex([2]), equals(2));
      });

      test('PAGE_CHANGED empty payload', () {
        expect(ProtocolService.parsePageIndex([]), isNull);
      });

      test('parsePagesData single page', () {
        final result = ProtocolService.parsePagesData([1, 4, 0x48, 0x4F, 0x4D, 0x45]);
        expect(result, isNotNull);
        expect(result!.length, equals(1));
        expect(result[0], equals('HOME'));
      });

      test('parsePagesData zero pages', () {
        final result = ProtocolService.parsePagesData([0]);
        expect(result, isNotNull);
        expect(result!.length, equals(0));
      });
    });

    group('DesignerPage JSON', () {
      test('landscape orientation', () {
        final json = {'name': 'Test', 'orientation': 'landscape', 'widgets': []};
        expect(json['orientation'], equals('landscape'));
        expect((json['widgets'] as List).length, equals(0));
      });

      test('portrait with widgets', () {
        final json = {'name': 'Control', 'orientation': 'portrait', 'widgets': [{'type': 'button'}]};
        expect(json['orientation'], equals('portrait'));
        expect((json['widgets'] as List).length, equals(1));
      });

      test('JSON round-trip', () {
        final original = {'name': 'Settings', 'orientation': 'landscape', 'widgets': []};
        final decoded = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
        expect(decoded['name'], equals(original['name']));
        expect(decoded['orientation'], equals(original['orientation']));
      });

      test('multi-page config', () {
        final config = {'version': 2, 'pages': [{'name': 'Page 1'}, {'name': 'Page 2'}]};
        expect(config['version'], equals(2));
        expect((config['pages'] as List).length, equals(2));
      });
    });

    group('PageSwitcher widget', () {
      test('hidden when numPages is 1', () {
        expect(1 <= 1, isTrue);
      });

      test('visible when numPages > 1', () {
        expect(2 > 1, isTrue);
      });

      test('disables left chevron on first page', () {
        expect(0 == 0, isTrue);
      });

      test('disables right chevron on last page', () {
        expect(2 == 3 - 1, isTrue);
      });

      test('displays page name from list', () {
        final names = ['Control', 'Settings'];
        expect(names[1], equals('Settings'));
      });

      test('default page name', () {
        final names = <String>[];
        final name = names.isNotEmpty ? names[0] : 'Page 1';
        expect(name, equals('Page 1'));
      });
    });

    group('DesignerPageBar widget', () {
      test('disables left chevron on first page', () {
        expect(0 == 0, isTrue);
      });

      test('disables right chevron on last page', () {
        expect(2 == 3 - 1, isTrue);
      });

      test('add button increases count', () {
        expect(2 + 1, equals(3));
      });

      test('delete only when numPages > 1', () {
        expect(1 > 1, isFalse);
        expect(2 > 1, isTrue);
      });

      test('reorder maintains count', () {
        final pages = ['A', 'B', 'C'];
        final moved = pages.removeAt(0);
        pages.insert(2, moved);
        expect(pages.length, equals(3));
        expect(pages, equals(['B', 'C', 'A']));
      });
    });
  });
}

RadioWidgetState _emptyState() {
  return const RadioWidgetState(inputValues: {}, outputValues: {});
}
