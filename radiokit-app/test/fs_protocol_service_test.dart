import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/models/protocol.dart';
import 'package:radiokit/models/fs_entry.dart';
import 'package:radiokit/models/fs_info.dart';
import 'package:radiokit/services/fs_protocol_service.dart';
import 'package:radiokit/services/protocol_service.dart';

void main() {
  group('FsProtocolService', () {
    test('buildFrame: LIST with simple path', () {
      final f = FsProtocolService.buildList('/foo');
      expect(f[0], kFsStartByte);
      expect(f[1], kFsCmdList);
      // length = 4 header + 1 (path-len) + 4 ("/foo") = 9
      expect(f[2], 9);
      expect(f[3], 0);
      expect(f.length, 9);
      // path bytes
      expect(f[4], 4); // path length
      expect(utf8.decode(f.sublist(5)), '/foo');
    });

    test('buildFrame: INFO has empty payload', () {
      final f = FsProtocolService.buildInfo();
      expect(f[0], kFsStartByte);
      expect(f[1], kFsCmdInfo);
      expect(f.length, 4); // header only
    });

    test('buildFrame: FORMAT has empty payload, subCmd 0x0C', () {
      final f = FsProtocolService.buildFormat();
      expect(f[0], kFsStartByte);
      expect(f[1], kFsCmdFormat);
      expect(f.length, 4); // header only
    });

    test('buildFrame: READ encodes path + offset + max_size', () {
      final f = FsProtocolService.buildRead('/data.bin', 0x100, 512);
      expect(f[0], kFsStartByte);
      expect(f[1], kFsCmdRead);
      // path-len byte
      expect(f[4], 9); // "/data.bin"
      // offset bytes (LE)
      expect(f[5 + 9], 0x00);
      expect(f[5 + 9 + 1], 0x01);
      expect(f[5 + 9 + 2], 0x00);
      expect(f[5 + 9 + 3], 0x00);
      // maxSize bytes
      expect(f[5 + 9 + 4], 0x00);
      expect(f[5 + 9 + 5], 0x02); // 512
    });

    test('parseFrame: round-trip a LIST frame', () {
      final f = FsProtocolService.buildList('/');
      final parsed = FsProtocolService.parseFrame(f);
      expect(parsed, isNotNull);
      expect(parsed!.subCmd, kFsCmdList);
      expect(parsed.payload[0], 1); // path-len = 1
    });

    test('parseListData: extracts entries with type/size/name', () {
      // Build a synthetic LIST_DATA payload.
      // [COUNT(2)] [TYPE SIZE NAME_LEN NAME]...
      final payload = <int>[
        2, 0, // count = 2
        kFsTypeFile, 0x00, 0x10, 0x00, 0x00, 4, 0x64, 0x61, 0x74, 0x61, // "data" 4096 B
        kFsTypeDir, 0x00, 0x00, 0x00, 0x00, 4, 0x74, 0x6D, 0x70, 0x21, // "tmp!" dir
      ];
      final entries = FsProtocolService.parseListData(payload);
      expect(entries, isNotNull);
      expect(entries!.length, 2);
      expect(entries[0].name, 'data');
      expect(entries[0].isDirectory, false);
      expect(entries[0].size, 0x1000);
      expect(entries[1].isDirectory, true);
    });

    test('parseReadData: extracts total/offset/data', () {
      // [TOTAL(4)] [OFFSET(4)] [DATA]
      final payload = <int>[
        10, 0, 0, 0, // total = 10
        2, 0, 0, 0, // offset = 2
        0xAB, 0xCD, 0xEF, // 3 data bytes
      ];
      final parsed = FsProtocolService.parseReadData(payload);
      expect(parsed, isNotNull);
      expect(parsed!.totalSize, 10);
      expect(parsed.offset, 2);
      expect(parsed.data.length, 3);
      expect(parsed.data[0], 0xAB);
    });

    test('parseInfoData: extracts total/used/block/fsType', () {
      final payload = <int>[
        0x00, 0x10, 0x00, 0x00, // total = 4096
        0x00, 0x04, 0x00, 0x00, // used = 1024
        0x00, 0x10, // blockSize = 4096
        0x01, // fsType = LittleFS
      ];
      final info = FsProtocolService.parseInfoData(payload);
      expect(info, isNotNull);
      expect(info!.totalBytes, 4096);
      expect(info.usedBytes, 1024);
      expect(info.blockSize, 4096);
      expect(info.fsType, 0x01);
      expect(info.fsTypeName, 'LittleFS');
    });

    test('parseAck: extracts single error code', () {
      expect(FsProtocolService.parseAck([0x00]), kFsErrOk);
      expect(FsProtocolService.parseAck([0x01]), kFsErrNotFound);
      expect(FsProtocolService.parseAck(<int>[]), null);
    });

    test('FsEntry equality: toString includes name + type + size', () {
      const e = FsEntry(name: 'foo', isDirectory: true, size: 0);
      expect(e.toString(), contains('foo'));
      expect(e.toString(), contains('dir'));
    });

    test('FsInfo: freeBytes and usedFraction', () {
      const info = FsInfo(totalBytes: 100, usedBytes: 25, blockSize: 1, fsType: 1);
      expect(info.freeBytes, 75);
      expect(info.usedFraction, closeTo(0.25, 1e-9));
    });
  });

  group('ProtocolService.drainBuffer', () {
    test('extracts a widget packet (0x55)', () {
      // Build a real widget packet: 0x55 + length + cmd + payload + CRC.
      final pkt = ProtocolService.buildGetConf();
      // Wrap it in a buffer with leading junk.
      final buf = <int>[0x00, 0x00, ...pkt];
      final r = ProtocolService.drainBuffer(buf);
      expect(r, isNotNull);
      expect(r!.kind, 'widget');
      expect(r.widgetPacket!.cmd, kCmdGetConf);
    });

    test('extracts an FS packet (0xAA)', () {
      final fs = FsProtocolService.buildInfo();
      final buf = <int>[0x00, 0xFF, ...fs];
      final r = ProtocolService.drainBuffer(buf);
      expect(r, isNotNull);
      expect(r!.kind, 'fs');
      expect(r.fsPacket!.subCmd, kFsCmdInfo);
    });

    test('returns null when buffer incomplete', () {
      final r = ProtocolService.drainBuffer([0x55, 0x06, 0x00]);
      expect(r, isNull);
    });

    test('drops junk bytes before start byte', () {
      final pkt = ProtocolService.buildGetConf();
      final buf = <int>[0x12, 0x34, 0x56, 0x78, ...pkt];
      final r = ProtocolService.drainBuffer(buf);
      expect(r, isNotNull);
      expect(r!.kind, 'widget');
    });

    test('mixed stream: widget then FS', () {
      final widgetPkt = ProtocolService.buildGetConf();
      final fsPkt = FsProtocolService.buildInfo();
      final buf = <int>[...widgetPkt, ...fsPkt];
      final r1 = ProtocolService.drainBuffer(buf);
      expect(r1!.kind, 'widget');
      final r2 = ProtocolService.drainBuffer(buf);
      expect(r2!.kind, 'fs');
    });
  });
}
