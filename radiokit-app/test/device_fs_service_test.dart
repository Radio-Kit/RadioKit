import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/services/device_fs_service.dart';
import 'package:radiokit/services/fs_protocol_service.dart';
import 'package:radiokit/models/protocol.dart';

/// A programmable [FsTransport] for tests. It records the frames the
/// service sends and replays a queued list of responses back in order.
/// When the queue runs out, [sendFs] returns null (timeout).
class _FakeFsTransport implements FsTransport {
  bool _connected = true;
  final List<Uint8List> sent = [];
  final List<ParsedFsPacket?> responses = [];
  Future<ParsedFsPacket?> Function(Uint8List frame)? onSendFs;
  Duration? overrideTimeout;

  @override
  bool get isConnected => _connected;

  void disconnect() => _connected = false;

  @override
  Future<ParsedFsPacket?> sendFs(
      Uint8List frame, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
    if (!_connected) return null;
    sent.add(frame);
    if (onSendFs != null) {
      return onSendFs!(frame);
    }
    if (responses.isEmpty) {
      // No scripted response — pretend timeout.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return null;
    }
    return responses.removeAt(0);
  }
}

/// Build a single-frame READ_DATA response for [offset] / [chunk] of [totalSize].
ParsedFsPacket readData(int totalSize, int offset, Uint8List chunk) {
  final p = <int>[
    totalSize & 0xFF,
    (totalSize >> 8) & 0xFF,
    (totalSize >> 16) & 0xFF,
    (totalSize >> 24) & 0xFF,
    offset & 0xFF,
    (offset >> 8) & 0xFF,
    (offset >> 16) & 0xFF,
    (offset >> 24) & 0xFF,
    ...chunk,
  ];
  return ParsedFsPacket(subCmd: kFsRespReadData, payload: Uint8List.fromList(p));
}

ParsedFsPacket ack([int code = kFsErrOk]) => ParsedFsPacket(
      subCmd: kFsRespWriteAck,
      payload: Uint8List.fromList([code]),
    );

void main() {
  group('DeviceFsService.listDir / getInfo', () {
    test('listDir returns parsed entries', () async {
      final t = _FakeFsTransport();
      // Build a 2-entry LIST_DATA response payload.
      final payload = <int>[
        2, 0, // count = 2
        kFsTypeFile, 100, 0, 0, 0, 4, 0x66, 0x6F, 0x6F, 0x2E, // "foo."
        kFsTypeDir, 0, 0, 0, 0, 4, 0x62, 0x61, 0x72, 0x2F, // "bar/"
      ];
      t.responses.add(ParsedFsPacket(
        subCmd: kFsRespListData,
        payload: Uint8List.fromList(payload),
      ));
      final svc = DeviceFsService(t);
      final entries = await svc.listDir('/');
      expect(entries.length, 2);
      expect(entries[0].name, 'foo.');
      expect(entries[0].isDirectory, isFalse);
      expect(entries[1].name, 'bar/');
      expect(entries[1].isDirectory, isTrue);
    });

    test('listDir returns [] on timeout', () async {
      final t = _FakeFsTransport();
      final svc = DeviceFsService(t);
      final entries = await svc.listDir('/');
      expect(entries, isEmpty);
    });

    test('getInfo returns parsed FsInfo', () async {
      final t = _FakeFsTransport();
      t.responses.add(ParsedFsPacket(
        subCmd: kFsRespInfoData,
        payload: Uint8List.fromList([
          0, 0, 0x10, 0, // total = 0x100000 = 1 MB
          0, 0, 0x04, 0, // used  = 0x040000 = 256 KB
          0x00, 0x10,    // block = 4096
          0x01,          // fsType = LittleFS
        ]),
      ));
      final svc = DeviceFsService(t);
      final info = await svc.getInfo();
      expect(info, isNotNull);
      expect(info!.totalBytes, 0x100000);
      expect(info.usedBytes, 0x040000);
      expect(info.blockSize, 4096);
      expect(info.fsType, 0x01);
    });
  });

  group('DeviceFsService.readFile (chunking + progress)', () {
    test('reads a small file in one round-trip', () async {
      final t = _FakeFsTransport();
      const data = 'Hello world';
      final bytes = Uint8List.fromList(utf8.encode(data));
      t.responses.add(readData(bytes.length, 0, bytes));
      final svc = DeviceFsService(t);
      final out = await svc.readFile('/test.txt');
      expect(out, isNotNull);
      expect(utf8.decode(out!), data);
      // Single READ request, no WRITE.
      expect(t.sent.length, 1);
      expect(t.sent[0][1], kFsCmdRead);
    });

    test('chunks reads for a 20 KB file (3 chunks at 8 KB)', () async {
      final t = _FakeFsTransport();
      const total = 20480; // 20 KB
      final big = Uint8List(total);
      for (int i = 0; i < total; i++) {
        big[i] = i & 0xFF;
      }
      t.responses.add(readData(total, 0, big.sublist(0, 8192)));
      t.responses.add(readData(total, 8192, big.sublist(8192, 16384)));
      t.responses.add(readData(total, 16384, big.sublist(16384)));

      final svc = DeviceFsService(t);
      final out = await svc.readFile('/big.bin');
      expect(out, isNotNull);
      expect(out!.length, total);
      expect(out, big);

      // 3 READ frames in total.
      expect(t.sent.length, 3);
      for (final f in t.sent) {
        expect(f[1], kFsCmdRead);
      }
    });

    test('reports progress at each chunk', () async {
      final t = _FakeFsTransport();
      const total = 12000;
      final bytes = Uint8List(total);
      t.responses.add(readData(total, 0, bytes.sublist(0, 8192)));
      t.responses.add(readData(total, 8192, bytes.sublist(8192)));

      final svc = DeviceFsService(t);
      final progress = <int>[];
      await svc.readFile('/x.bin', onProgress: (read, t) => progress.add(read));
      expect(progress, [8192, 12000]);
    });

    test('returns null on transport timeout', () async {
      final t = _FakeFsTransport(); // no responses
      final svc = DeviceFsService(t);
      expect(await svc.readFile('/missing'), isNull);
    });
  });

  group('DeviceFsService.writeFile (chunking + cap)', () {
    test('writes a small file in one frame', () async {
      final t = _FakeFsTransport()..responses.add(ack());
      final svc = DeviceFsService(t);
      final res = await svc.writeFile('/small.txt', Uint8List.fromList(utf8.encode('hi')));
      expect(res.success, isTrue);
      expect(t.sent.length, 1);
      expect(t.sent[0][1], kFsCmdWrite);
    });

    test('chunks a 20 KB write at the 8 KB default', () async {
      final t = _FakeFsTransport();
      // 20 KB / 8 KB = 3 chunks.
      t.responses.add(ack());
      t.responses.add(ack());
      t.responses.add(ack());
      final svc = DeviceFsService(t);
      final data = Uint8List(20480);
      final res = await svc.writeFile('/big.bin', data);
      expect(res.success, isTrue);
      expect(t.sent.length, 3);
    });

    test('caps chunkSize at 12 KB to stay under the 16 KB frame limit', () async {
      final t = _FakeFsTransport();
      // 30 KB write with chunkSize=20 KB. Should cap to 12 KB.
      // 30 KB / 12 KB = 3 chunks (12 + 12 + 6).
      t.responses.add(ack());
      t.responses.add(ack());
      t.responses.add(ack());
      final svc = DeviceFsService(t);
      final data = Uint8List(30720);
      final res = await svc.writeFile('/huge.bin', data, chunkSize: 20480);
      expect(res.success, isTrue);
      expect(t.sent.length, 3);
    });

    test('aborts with error code on first chunk NACK', () async {
      final t = _FakeFsTransport()
        ..responses.add(ack(kFsErrOutOfSpace));
      final svc = DeviceFsService(t);
      final res = await svc.writeFile('/x', Uint8List.fromList([1, 2, 3]));
      expect(res.success, isFalse);
      expect(res.errorCode, kFsErrOutOfSpace);
      expect(res.errorName, 'OUT_OF_SPACE');
    });

    test('aborts with TIMEOUT on chunk timeout', () async {
      final t = _FakeFsTransport(); // no response
      final svc = DeviceFsService(t);
      final res = await svc.writeFile('/x', Uint8List.fromList([1]));
      expect(res.success, isFalse);
      expect(res.errorName, 'TIMEOUT');
    });

    test('progress fires for each chunk', () async {
      final t = _FakeFsTransport();
      t.responses.add(ack());
      t.responses.add(ack());
      final svc = DeviceFsService(t);
      final events = <int>[];
      await svc.writeFile(
        '/x',
        Uint8List(16000),
        onProgress: (w, total) => events.add(w),
      );
      expect(events, [8192, 16000]);
    });
  });

  group('DeviceFsService.delete / mkdir / rename / format', () {
    test('delete returns success on OK ack', () async {
      final t = _FakeFsTransport()..responses.add(ack());
      final svc = DeviceFsService(t);
      final res = await svc.delete('/a.txt');
      expect(res.success, isTrue);
    });

    test('delete propagates error code', () async {
      final t = _FakeFsTransport()..responses.add(ack(kFsErrNotFound));
      final svc = DeviceFsService(t);
      final res = await svc.delete('/missing');
      expect(res.success, isFalse);
      expect(res.errorCode, kFsErrNotFound);
    });

    test('mkdir + rename + format work end-to-end', () async {
      final t = _FakeFsTransport()
        ..responses.add(ack())  // mkdir
        ..responses.add(ack()); // rename
      final svc = DeviceFsService(t);
      expect((await svc.mkdir('/d')).success, isTrue);
      expect((await svc.rename('/d', '/d2')).success, isTrue);

      final t2 = _FakeFsTransport()..responses.add(ack());
      final svc2 = DeviceFsService(t2);
      final res = await svc2.format();
      expect(res.success, isTrue);
    });
  });

  group('DeviceFsService serialization', () {
    test('concurrent operations are executed sequentially', () async {
      final t = _FakeFsTransport();
      final svc = DeviceFsService(t);
      final order = <String>[];

      t.onSendFs = (frame) async {
        final subCmd = frame[1];
        if (subCmd == kFsCmdList) {
          order.add('list_start');
          await Future.delayed(const Duration(milliseconds: 20));
          order.add('list_end');
          return ParsedFsPacket(
            subCmd: kFsRespListData,
            payload: Uint8List.fromList([0, 0]),
          );
        } else if (subCmd == kFsCmdInfo) {
          order.add('info_start');
          await Future.delayed(const Duration(milliseconds: 10));
          order.add('info_end');
          return ParsedFsPacket(
            subCmd: kFsRespInfoData,
            payload: Uint8List(11),
          );
        }
        return null;
      };

      // Launch listDir and getInfo concurrently
      final f1 = svc.listDir('/');
      final f2 = svc.getInfo();

      await Future.wait([f1, f2]);

      expect(order, ['list_start', 'list_end', 'info_start', 'info_end']);
    });
  });
}
