import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../models/protocol.dart';
import 'demo_fs_state.dart';
import 'demo_transport.dart';
import 'fs_protocol_service.dart';

/// A [DemoTransport] that also simulates the bulk-FS protocol (0xAA).
///
/// Intercepts every `writePacket` call. If the frame starts with
/// [kFsStartByte], the simulator runs the operation against an
/// in-memory [DemoFsState] and dispatches the synthesised response to
/// [onFsPacketReceived] on the next microtask (so callers see a
/// real async round-trip, matching the behaviour of BLE / Serial).
class DemoFsTransport extends DemoTransport {
  DemoFsState _state;

  /// Optional latency injected before each response, to make progress
  /// bars visible in the UI. Default `Duration.zero` for instant
  /// responses.
  Duration responseDelay;

  DemoFsTransport({DemoFsState? state, this.responseDelay = Duration.zero})
      : _state = state ?? DemoFsState.seeded();

  /// Reset the simulated FS to the seeded state.
  void reset() {
    _state = DemoFsState.seeded();
  }

  @override
  Future<void> writePacket(Uint8List data) async {
    // 0xAA frame?
    if (data.isNotEmpty && data[0] == kFsStartByte) {
      final parsed = FsProtocolService.parseFrame(data);
      if (parsed != null) {
        final response = _dispatch(parsed.subCmd, parsed.payload);
        if (response != null) {
          if (responseDelay > Duration.zero) {
            await Future.delayed(responseDelay);
          } else {
            // Yield once so the awaiting side sees a real microtask.
            await Future.microtask(() {});
          }
          onFsPacketReceived?.call(response);
        }
      }
      return;
    }
    // Non-FS frame: defer to the base transport (currently a no-op).
    await super.writePacket(data);
  }

  // ── FS dispatch ───────────────────────────────────────────────────────

  ParsedFsPacket? _dispatch(int subCmd, Uint8List payload) {
    switch (subCmd) {
      case kFsCmdList:
        return _handleList(payload);
      case kFsCmdInfo:
        return _handleInfo();
      case kFsCmdRead:
        return _handleRead(payload);
      case kFsCmdWrite:
        return _handleWrite(payload);
      case kFsCmdDelete:
        return _handleDelete(payload);
      case kFsCmdMkdir:
        return _handleMkdir(payload);
      case kFsCmdRename:
        return _handleRename(payload);
      case kFsCmdPing:
        return _handlePing();
      case kFsCmdFormat:
        return _handleFormat();
      case kFsCmdReplace:
        return _handleReplace(payload);
      case kFsCmdUploadBegin:
        return _handleUploadBegin(payload);
      case kFsCmdUploadChunk:
        return _handleUploadChunk(payload);
      case kFsCmdUploadEnd:
        return _handleUploadEnd(payload);
      case kFsCmdCrc32:
        return _handleCrc32(payload);
      default:
        // Unknown sub-commands: synthesize a NO_FS ack to fail gracefully.
        return ParsedFsPacket(
          subCmd: _ackForSub(subCmd),
          payload: Uint8List.fromList([kFsErrNoFs]),
        );
    }
  }

  ParsedFsPacket _handlePing() {
    return ParsedFsPacket(
      subCmd: kFsRespPingAck,
      payload: Uint8List.fromList([kFsErrOk]),
    );
  }

  ParsedFsPacket _handleReplace(Uint8List payload) {
    // Payload: [PATH_LEN(1)][PATH(N)][CRC32(4 LE)][CONTENT(M)]
    if (payload.length < 6) {
      return _ack(kFsRespReplaceAck, kFsErrInvalidPath);
    }
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen + 4) {
      return _ack(kFsRespReplaceAck, kFsErrInvalidPath);
    }
    final path = utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
    int p = 1 + pathLen + 4; // skip CRC32 (4 bytes)
    final content = Uint8List.sublistView(payload, p);
    final res = _state.replace(path, content);
    return _ack(kFsRespReplaceAck, res.code);
  }

  // ── Upload protocol handlers ─────────────────────────────────────────

  /// Simulated upload state.
  String _uploadPath = '';

  /// UPLOAD_BEGIN: create/truncate file for upload.
  /// Payload: [PATH_LEN(1)][PATH(N)][TOTAL_SIZE(4 LE)].
  ParsedFsPacket _handleUploadBegin(Uint8List payload) {
    if (payload.length < 6) {
      return _ack(kFsRespUploadBeginAck, kFsErrInvalidPath);
    }
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen + 4) {
      return _ack(kFsRespUploadBeginAck, kFsErrInvalidPath);
    }
    final path = utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
    // Create/truncate the file by writing empty at offset 0
    final res = _state.writeFile(path, 0, Uint8List(0));
    if (res.code != kFsErrOk) {
      _uploadPath = '';
      return _ack(kFsRespUploadBeginAck, res.code);
    }
    _uploadPath = path;
    return _ack(kFsRespUploadBeginAck, kFsErrOk);
  }

  /// UPLOAD_CHUNK: write data at sequential offset.
  /// Payload: [OFFSET(4 LE)][DATA(N)].
  ParsedFsPacket _handleUploadChunk(Uint8List payload) {
    if (payload.length < 5) {
      return _ack(kFsRespUploadChunkAck, kFsErrInvalidPath);
    }
    final offset = payload[0] |
        (payload[1] << 8) |
        (payload[2] << 16) |
        (payload[3] << 24);
    final data = Uint8List.sublistView(payload, 4);
    final res = _state.writeFile(_uploadPath, offset, data);
    return _ack(kFsRespUploadChunkAck, res.code);
  }

  /// UPLOAD_END: finalize upload. Demo doesn't verify CRC.
  /// Payload: [CRC32(4 LE)].
  ParsedFsPacket _handleUploadEnd(Uint8List payload) {
    _uploadPath = '';
    return _ack(kFsRespUploadEndAck, kFsErrOk);
  }

  ParsedFsPacket _handleCrc32(Uint8List payload) {
    // Payload: [PATH_LEN(1)][PATH(N)]
    final path = _readPathPayload(payload);
    if (path == null) {
      return ParsedFsPacket(
        subCmd: kFsRespCrc32Data,
        payload: Uint8List.fromList([1, 0, 0, 0, 0, 0, 0, 0, 0]),
      );
    }
    final result = _state.getFileCrc32(path);
    final buf = <int>[
      result.found ? 0x00 : 0x01,  // STATUS
      result.crc32 & 0xFF,
      (result.crc32 >> 8) & 0xFF,
      (result.crc32 >> 16) & 0xFF,
      (result.crc32 >> 24) & 0xFF,
      result.size & 0xFF,
      (result.size >> 8) & 0xFF,
      (result.size >> 16) & 0xFF,
      (result.size >> 24) & 0xFF,
    ];
    return ParsedFsPacket(
      subCmd: kFsRespCrc32Data,
      payload: Uint8List.fromList(buf),
    );
  }

  ParsedFsPacket _handleFormat() {
    // Reset the state to the seeded tree so the demo mirrors a real
    // device after a format. The caller (DeviceFsService.format) will
    // also re-query INFO afterwards.
    _state = DemoFsState.seeded();
    return ParsedFsPacket(
      subCmd: kFsRespFormatAck,
      payload: Uint8List.fromList([kFsErrOk]),
    );
  }

  ParsedFsPacket _handleList(Uint8List payload) {
    final path = _readPathPayload(payload);
    if (path == null) {
      return ParsedFsPacket(
        subCmd: kFsRespListData,
        payload: Uint8List.fromList([0, 0]),
      );
    }
    final res = _state.list(path);
    if (!res.result.isOk) {
      // Mirror the real device: an empty listing on error.
      return ParsedFsPacket(
        subCmd: kFsRespListData,
        payload: Uint8List.fromList([0, 0]),
      );
    }
    final buf = <int>[];
    final count = res.entries.length;
    buf.add(count & 0xFF);
    buf.add((count >> 8) & 0xFF);
    for (final e in res.entries) {
      buf.add(e.isDirectory ? kFsTypeDir : kFsTypeFile);
      buf.add(e.size & 0xFF);
      buf.add((e.size >> 8) & 0xFF);
      buf.add((e.size >> 16) & 0xFF);
      buf.add((e.size >> 24) & 0xFF);
      final nameBytes = utf8.encode(e.name);
      buf.add(nameBytes.length & 0xFF);
      buf.addAll(nameBytes);
    }
    return ParsedFsPacket(
      subCmd: kFsRespListData,
      payload: Uint8List.fromList(buf),
    );
  }

  ParsedFsPacket _handleInfo() {
    final info = _state.info();
    final buf = <int>[
      info.totalBytes & 0xFF,
      (info.totalBytes >> 8) & 0xFF,
      (info.totalBytes >> 16) & 0xFF,
      (info.totalBytes >> 24) & 0xFF,
      info.usedBytes & 0xFF,
      (info.usedBytes >> 8) & 0xFF,
      (info.usedBytes >> 16) & 0xFF,
      (info.usedBytes >> 24) & 0xFF,
      info.blockSize & 0xFF,
      (info.blockSize >> 8) & 0xFF,
      info.fsType & 0xFF,
    ];
    return ParsedFsPacket(
      subCmd: kFsRespInfoData,
      payload: Uint8List.fromList(buf),
    );
  }

  ParsedFsPacket _handleRead(Uint8List payload) {
    if (payload.length < 7) {
      return _readErr(kFsErrInvalidPath);
    }
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen + 6) {
      return _readErr(kFsErrInvalidPath);
    }
    final path = utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
    int p = 1 + pathLen;
    final offset = payload[p] |
        (payload[p + 1] << 8) |
        (payload[p + 2] << 16) |
        (payload[p + 3] << 24);
    p += 4;
    final length = payload[p] | (payload[p + 1] << 8);

    final r = _state.read(path, offset, length);
    if (!r.result.isOk) {
      return _readErr(r.result.code);
    }
    final buf = <int>[
      r.totalSize & 0xFF,
      (r.totalSize >> 8) & 0xFF,
      (r.totalSize >> 16) & 0xFF,
      (r.totalSize >> 24) & 0xFF,
      r.offset & 0xFF,
      (r.offset >> 8) & 0xFF,
      (r.offset >> 16) & 0xFF,
      (r.offset >> 24) & 0xFF,
      ...r.data,
    ];
    return ParsedFsPacket(
      subCmd: kFsRespReadData,
      payload: Uint8List.fromList(buf),
    );
  }

  ParsedFsPacket _handleWrite(Uint8List payload) {
    if (payload.isEmpty) {
      return _ack(kFsRespWriteAck, kFsErrInvalidPath);
    }
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen + 4) {
      return _ack(kFsRespWriteAck, kFsErrInvalidPath);
    }
    final path = utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
    int p = 1 + pathLen;
    final offset = payload[p] |
        (payload[p + 1] << 8) |
        (payload[p + 2] << 16) |
        (payload[p + 3] << 24);
    p += 4;
    final data = Uint8List.sublistView(payload, p);
    final res = _state.writeFile(path, offset, data);
    return _ack(kFsRespWriteAck, res.code);
  }

  ParsedFsPacket _handleDelete(Uint8List payload) {
    if (payload.length < 2) {
      return _ack(kFsRespDeleteAck, kFsErrInvalidPath);
    }
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen + 1) {
      return _ack(kFsRespDeleteAck, kFsErrInvalidPath);
    }
    final path = utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
    final recursive = payload[1 + pathLen] != 0;
    final res = _state.delete(path, recursive: recursive);
    return _ack(kFsRespDeleteAck, res.code);
  }

  ParsedFsPacket _handleMkdir(Uint8List payload) {
    if (payload.isEmpty) {
      return _ack(kFsRespMkdirAck, kFsErrInvalidPath);
    }
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen) {
      return _ack(kFsRespMkdirAck, kFsErrInvalidPath);
    }
    final path = utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
    final res = _state.mkdir(path);
    return _ack(kFsRespMkdirAck, res.code);
  }

  ParsedFsPacket _handleRename(Uint8List payload) {
    if (payload.isEmpty) {
      return _ack(kFsRespRenameAck, kFsErrInvalidPath);
    }
    final oldLen = payload[0];
    if (payload.length < 1 + oldLen) {
      return _ack(kFsRespRenameAck, kFsErrInvalidPath);
    }
    final oldPath = utf8.decode(
      payload.sublist(1, 1 + oldLen),
      allowMalformed: true,
    );
    int p = 1 + oldLen;
    if (payload.length < p + 1) {
      return _ack(kFsRespRenameAck, kFsErrInvalidPath);
    }
    final newLen = payload[p];
    p += 1;
    if (payload.length < p + newLen) {
      return _ack(kFsRespRenameAck, kFsErrInvalidPath);
    }
    final newPath = utf8.decode(
      payload.sublist(p, p + newLen),
      allowMalformed: true,
    );
    final res = _state.rename(oldPath, newPath);
    return _ack(kFsRespRenameAck, res.code);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  ParsedFsPacket _ack(int subCmd, int code) {
    return ParsedFsPacket(
      subCmd: subCmd,
      payload: Uint8List.fromList([code & 0xFF]),
    );
  }

  ParsedFsPacket _readErr(int code) {
    return ParsedFsPacket(
      subCmd: kFsRespReadData,
      payload: Uint8List.fromList([
        0, 0, 0, 0, // totalSize = 0
        0, 0, 0, 0, // offset = 0
      ]),
    );
  }

  int _ackForSub(int subCmd) {
    switch (subCmd) {
      case kFsCmdList:
        return kFsRespListData;
      case kFsCmdRead:
        return kFsRespReadData;
      case kFsCmdWrite:
        return kFsRespWriteAck;
      case kFsCmdDelete:
        return kFsRespDeleteAck;
      case kFsCmdInfo:
        return kFsRespInfoData;
      case kFsCmdMkdir:
        return kFsRespMkdirAck;
      case kFsCmdRename:
        return kFsRespRenameAck;
      default:
        return kFsRespWriteAck;
    }
  }

  /// Parse `[u8 pathLen][path bytes...]` and return the path string.
  /// Returns null if the payload is malformed.
  String? _readPathPayload(Uint8List payload) {
    if (payload.isEmpty) return null;
    final pathLen = payload[0];
    if (payload.length < 1 + pathLen) return null;
    return utf8.decode(
      payload.sublist(1, 1 + pathLen),
      allowMalformed: true,
    );
  }
}
