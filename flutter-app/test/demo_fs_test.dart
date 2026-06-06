import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/services/demo_fs_state.dart';
import 'package:radiokit/services/demo_fs_transport.dart';
import 'package:radiokit/services/fs_protocol_service.dart';
import 'package:radiokit/models/protocol.dart';

void main() {
  group('DemoFsState.path normalisation', () {
    test('returns null for empty input', () {
      expect(DemoFsState.normalizePath(''), isNull);
    });

    test('ensures leading slash', () {
      expect(DemoFsState.normalizePath('foo'), '/foo');
    });

    test('strips trailing slash (but keeps root)', () {
      expect(DemoFsState.normalizePath('/foo/'), '/foo');
      expect(DemoFsState.normalizePath('/'), '/');
    });

    test('rejects .. and //', () {
      expect(DemoFsState.normalizePath('/../etc'), isNull);
      expect(DemoFsState.normalizePath('/foo//bar'), isNull);
    });
  });

  group('DemoFsState.seeded', () {
    test('creates root + /demo + README + sensors.json + /scripts', () {
      final s = DemoFsState.seeded();
      final root = s.list('/');
      expect(root.result.isOk, isTrue);
      final names = root.entries.map((e) => e.name).toList();
      expect(names, contains('demo'));
      expect(names, contains('scripts'));

      final demo = s.list('/demo');
      expect(demo.result.isOk, isTrue);
      final demoNames = demo.entries.map((e) => e.name).toList();
      expect(demoNames, contains('README.txt'));
      expect(demoNames, contains('sensors.json'));

      final scripts = s.list('/scripts');
      expect(scripts.result.isOk, isTrue);
      expect(scripts.entries, isEmpty);
    });

    test('info returns totalBytes > 0 and LittleFS type', () {
      final s = DemoFsState.seeded();
      final i = s.info();
      expect(i.totalBytes, greaterThan(0));
      expect(i.usedBytes, greaterThan(0));
      expect(i.fsType, 0x01);
    });
  });

  group('DemoFsState.read', () {
    test('reads entire file in one chunk', () {
      final s = DemoFsState.seeded();
      final r = s.read('/demo/README.txt', 0, 1024);
      expect(r.result.isOk, isTrue);
      final text = utf8.decode(r.data);
      expect(text, contains('Hello from the RadioKit demo filesystem'));
    });

    test('reads partial content from offset', () {
      final s = DemoFsState.seeded();
      final r = s.read('/demo/README.txt', 0, 5);
      expect(r.result.isOk, isTrue);
      expect(utf8.decode(r.data), 'Hello');
    });

    test('returns NOT_FOUND for missing file', () {
      final s = DemoFsState.seeded();
      final r = s.read('/no/such/file', 0, 100);
      expect(r.result.code, FsDemoResult.errNotFound);
    });

    test('returns empty data for offset past EOF', () {
      final s = DemoFsState.seeded();
      final r = s.read('/demo/README.txt', 100000, 50);
      expect(r.result.isOk, isTrue);
      expect(r.data, isEmpty);
    });
  });

  group('DemoFsState.write', () {
    test('creates new file', () {
      final s = DemoFsState.seeded();
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final res = s.writeFile('/demo/new.txt', 0, data);
      expect(res.isOk, isTrue);
      final r = s.read('/demo/new.txt', 0, 100);
      expect(utf8.decode(r.data), 'hello world');
    });

    test('overwrites existing file at offset 0', () {
      final s = DemoFsState.seeded();
      final data = Uint8List.fromList(utf8.encode('NEW'));
      s.writeFile('/demo/README.txt', 0, data);
      final r = s.read('/demo/README.txt', 0, 100);
      expect(utf8.decode(r.data), 'NEW');
    });

    test('returns NOT_FOUND when parent dir missing', () {
      final s = DemoFsState.seeded();
      final data = Uint8List.fromList(utf8.encode('x'));
      final res = s.writeFile('/nope/foo.txt', 0, data);
      expect(res.code, FsDemoResult.errNotFound);
    });
  });

  group('DemoFsState.delete', () {
    test('deletes a file', () {
      final s = DemoFsState.seeded();
      final res = s.delete('/demo/README.txt');
      expect(res.isOk, isTrue);
      final r = s.read('/demo/README.txt', 0, 10);
      expect(r.result.code, FsDemoResult.errNotFound);
    });

    test('recursively deletes a directory', () {
      final s = DemoFsState.seeded();
      s.writeFile(
          '/scripts/script1.txt', 0, Uint8List.fromList(utf8.encode('a')));
      final res = s.delete('/scripts', recursive: true);
      expect(res.isOk, isTrue);
      final list = s.list('/');
      expect(list.entries.where((e) => e.name == 'scripts'), isEmpty);
    });

    test('rejects non-recursive delete of non-empty dir', () {
      final s = DemoFsState.seeded();
      final res = s.delete('/demo', recursive: false);
      expect(res.code, FsDemoResult.errInvalidState);
    });
  });

  group('DemoFsState.mkdir + rename', () {
    test('mkdir creates a directory', () {
      final s = DemoFsState.seeded();
      s.mkdir('/newdir');
      final list = s.list('/');
      expect(list.entries.any((e) => e.name == 'newdir'), isTrue);
    });

    test('rename moves a file', () {
      final s = DemoFsState.seeded();
      final res = s.rename('/demo/README.txt', '/demo/READ_ME.txt');
      expect(res.isOk, isTrue);
      final list = s.list('/demo');
      expect(list.entries.any((e) => e.name == 'READ_ME.txt'), isTrue);
      expect(list.entries.any((e) => e.name == 'README.txt'), isFalse);
    });

    test('rename a directory moves its children', () {
      final s = DemoFsState.seeded();
      final res = s.rename('/demo', '/newdemo');
      expect(res.isOk, isTrue);
      final newList = s.list('/newdemo');
      expect(newList.entries.any((e) => e.name == 'README.txt'), isTrue);
      final old = s.read('/newdemo/README.txt', 0, 5);
      expect(utf8.decode(old.data), 'Hello');
    });
  });

  group('DemoFsTransport — end-to-end 0xAA round-trip', () {
    test('LIST returns 2 entries in /demo', () async {
      final t = DemoFsTransport();
      ParsedFsPacket? response;
      t.onFsPacketReceived = (p) => response = p;

      final frame = FsProtocolService.buildList('/demo');
      await t.writePacket(frame);

      // Wait for the microtask to flush
      await Future<void>.delayed(Duration.zero);

      expect(response, isNotNull);
      expect(response!.subCmd, kFsRespListData);
      final entries = FsProtocolService.parseListData(response!.payload);
      expect(entries, isNotNull);
      expect(entries!.map((e) => e.name), containsAll(['README.txt', 'sensors.json']));
    });

    test('INFO returns totalBytes / usedBytes / LittleFS', () async {
      final t = DemoFsTransport();
      ParsedFsPacket? response;
      t.onFsPacketReceived = (p) => response = p;

      await t.writePacket(FsProtocolService.buildInfo());
      await Future<void>.delayed(Duration.zero);

      expect(response, isNotNull);
      expect(response!.subCmd, kFsRespInfoData);
      final info = FsProtocolService.parseInfoData(response!.payload);
      expect(info, isNotNull);
      expect(info!.fsType, 0x01);
      expect(info.totalBytes, greaterThan(0));
    });

    test('WRITE then READ roundtrip', () async {
      final t = DemoFsTransport();
      final responses = <ParsedFsPacket>[];
      t.onFsPacketReceived = responses.add;

      // Write a file
      final data = utf8.encode('SIM ROUND TRIP');
      await t.writePacket(
        FsProtocolService.buildWrite('/test.txt', 0, data),
      );
      // Read it back
      await t.writePacket(
        FsProtocolService.buildRead('/test.txt', 0, 100),
      );
      await Future<void>.delayed(Duration.zero);

      expect(responses.length, 2);
      final writeAck = FsProtocolService.parseAck(responses[0].payload);
      expect(writeAck, kFsErrOk);
      final parsed = FsProtocolService.parseReadData(responses[1].payload);
      expect(parsed, isNotNull);
      expect(utf8.decode(parsed!.data), 'SIM ROUND TRIP');
    });

    test('DELETE returns ack, then LIST omits the entry', () async {
      final t = DemoFsTransport();
      final responses = <ParsedFsPacket>[];
      t.onFsPacketReceived = responses.add;

      await t.writePacket(
        FsProtocolService.buildDelete('/demo/README.txt'),
      );
      await t.writePacket(
        FsProtocolService.buildList('/demo'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(FsProtocolService.parseAck(responses[0].payload), kFsErrOk);
      final entries = FsProtocolService.parseListData(responses[1].payload);
      expect(entries!.any((e) => e.name == 'README.txt'), isFalse);
    });

    test('MKDIR + RENAME flow', () async {
      final t = DemoFsTransport();
      final responses = <ParsedFsPacket>[];
      t.onFsPacketReceived = responses.add;

      await t.writePacket(
        FsProtocolService.buildMkdir('/work'),
      );
      await t.writePacket(
        FsProtocolService.buildRename('/demo/sensors.json', '/work/sensors.json'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(FsProtocolService.parseAck(responses[0].payload), kFsErrOk);
      expect(FsProtocolService.parseAck(responses[1].payload), kFsErrOk);
    });

    test('non-FS frame (0x55) is ignored', () async {
      final t = DemoFsTransport();
      var received = false;
      t.onFsPacketReceived = (_) => received = true;
      await t.writePacket(Uint8List.fromList([0x55, 0x06, 0x00, 0x01]));
      await Future<void>.delayed(Duration.zero);
      expect(received, isFalse);
    });

    test('PING returns OK (capability detection)', () async {
      final t = DemoFsTransport();
      ParsedFsPacket? response;
      t.onFsPacketReceived = (p) => response = p;
      await t.writePacket(FsProtocolService.buildPing());
      await Future<void>.delayed(Duration.zero);
      expect(response, isNotNull);
      expect(response!.subCmd, kFsRespPingAck);
      expect(FsProtocolService.parseAck(response!.payload), kFsErrOk);
    });

    test('FORMAT resets state to seeded tree', () async {
      final t = DemoFsTransport();
      final responses = <ParsedFsPacket>[];
      t.onFsPacketReceived = responses.add;

      // Mutate the seeded state first.
      await t.writePacket(
        FsProtocolService.buildWrite('/dirty.txt', 0,
            Uint8List.fromList(utf8.encode('will-be-erased'))),
      );
      // Now format.
      await t.writePacket(FsProtocolService.buildFormat());
      // Re-list the root.
      await t.writePacket(FsProtocolService.buildList('/'));
      await Future<void>.delayed(Duration.zero);

      // responses[0] = WRITE_ACK (from dirty.txt)
      // responses[1] = FORMAT_ACK
      // responses[2] = LIST_DATA
      expect(responses.length, 3);
      expect(responses[1].subCmd, kFsRespFormatAck);
      expect(FsProtocolService.parseAck(responses[1].payload), kFsErrOk);

      final entries = FsProtocolService.parseListData(responses[2].payload)!;
      final names = entries.map((e) => e.name).toSet();
      expect(names, isNot(contains('dirty.txt')),
          reason: 'FORMAT should reset the state');
      expect(names, containsAll(['demo', 'scripts']));
    });
  });
}
