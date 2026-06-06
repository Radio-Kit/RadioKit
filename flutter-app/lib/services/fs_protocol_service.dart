import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/protocol.dart';
import '../models/fs_entry.dart';
import '../models/fs_info.dart';

/// Result of parsing a 0xAA bulk-FS frame.
class ParsedFsPacket {
  final int subCmd;
  final Uint8List payload;
  const ParsedFsPacket({required this.subCmd, required this.payload});

  @override
  String toString() =>
      'ParsedFsPacket(sub=0x${subCmd.toRadixString(16).padLeft(2, "0")}, '
      'payloadLen=${payload.length})';
}

/// Build and parse 0xAA bulk-FS frames. Mirrors the Arduino side
/// (RadioKitFS.h / RadioKitFS.cpp). No CRC — transport reliability
/// is sufficient for short bursts.
class FsProtocolService {
  // ── Frame building ──────────────────────────────────────────────────────

  /// Build a complete FS frame:
  ///   START(1) + SUB_CMD(1) + LEN_LO(1) + LEN_HI(1) + PAYLOAD(N)
  static Uint8List buildFrame(int subCmd, [List<int>? payload]) {
    final p = payload ?? const [];
    final total = kFsHeaderSize + p.length;
    if (total > 0xFFFF) {
      throw ArgumentError('FS frame too large: $total bytes');
    }
    final frame = Uint8List(total);
    frame[0] = kFsStartByte;
    frame[1] = subCmd & 0xFF;
    frame[2] = total & 0xFF;
    frame[3] = (total >> 8) & 0xFF;
    for (int i = 0; i < p.length; i++) {
      frame[kFsHeaderSize + i] = p[i] & 0xFF;
    }
    return frame;
  }

  // ── App → MCU builders ──────────────────────────────────────────────────

  /// Build a path-payload: 1-byte length + UTF-8 bytes.
  static List<int> _pathPayload(String path) {
    final bytes = utf8.encode(path);
    final out = <int>[bytes.length & 0xFF];
    for (final b in bytes) {
      out.add(b & 0xFF);
    }
    return out;
  }

  static Uint8List buildList(String path) =>
      buildFrame(kFsCmdList, _pathPayload(path));

  static Uint8List buildInfo() => buildFrame(kFsCmdInfo);

  static Uint8List buildMkdir(String path) =>
      buildFrame(kFsCmdMkdir, _pathPayload(path));

  static Uint8List buildDelete(String path, {bool recursive = false}) {
    final p = _pathPayload(path);
    p.add(recursive ? 0x01 : 0x00);
    return buildFrame(kFsCmdDelete, p);
  }

  static Uint8List buildRename(String oldPath, String newPath) {
    final p = <int>[];
    p.addAll(_pathPayload(oldPath));
    p.addAll(_pathPayload(newPath));
    return buildFrame(kFsCmdRename, p);
  }

  /// Read up to [maxSize] bytes at [offset] from [path].
  static Uint8List buildRead(String path, int offset, int maxSize) {
    final p = <int>[];
    p.addAll(_pathPayload(path));
    p.add(offset & 0xFF);
    p.add((offset >> 8) & 0xFF);
    p.add((offset >> 16) & 0xFF);
    p.add((offset >> 24) & 0xFF);
    p.add(maxSize & 0xFF);
    p.add((maxSize >> 8) & 0xFF);
    return buildFrame(kFsCmdRead, p);
  }

  /// Write [data] at [offset]. Offset 0 truncates + writes.
  static Uint8List buildWrite(String path, int offset, List<int> data) {
    final p = <int>[];
    p.addAll(_pathPayload(path));
    p.add(offset & 0xFF);
    p.add((offset >> 8) & 0xFF);
    p.add((offset >> 16) & 0xFF);
    p.add((offset >> 24) & 0xFF);
    p.addAll(data);
    return buildFrame(kFsCmdWrite, p);
  }

  // ── Packet parsing ──────────────────────────────────────────────────────

  /// Parse a complete FS frame extracted from the rx buffer. The caller
  /// is responsible for detecting the 0xAA start byte and slicing the
  /// [frameLen] bytes out of the receive buffer.
  static ParsedFsPacket? parseFrame(List<int> data) {
    if (data.length < kFsHeaderSize) return null;
    if (data[0] != kFsStartByte) return null;
    final subCmd = data[1];
    final payload = Uint8List.fromList(data.sublist(kFsHeaderSize));
    return ParsedFsPacket(subCmd: subCmd, payload: payload);
  }

  // ── Response parsers ────────────────────────────────────────────────────

  /// Parse a LIST_DATA frame. Payload layout:
  ///   [ENTRY_COUNT(2 LE)]
  ///   per entry: [TYPE(1)][SIZE(4 LE)][NAME_LEN(1)][NAME(NAME_LEN)]
  static List<FsEntry>? parseListData(List<int> payload) {
    if (payload.length < 2) return null;
    final count = payload[0] | (payload[1] << 8);
    int offset = 2;
    final entries = <FsEntry>[];
    for (int i = 0; i < count; i++) {
      if (offset + 6 > payload.length) break;
      final type   = payload[offset++];
      final size   = payload[offset] |
                     (payload[offset + 1] << 8) |
                     (payload[offset + 2] << 16) |
                     (payload[offset + 3] << 24);
      offset += 4;
      final nameLen = payload[offset++];
      if (offset + nameLen > payload.length) break;
      final name = utf8.decode(payload.sublist(offset, offset + nameLen),
          allowMalformed: true);
      offset += nameLen;
      entries.add(FsEntry(
        name: name,
        isDirectory: type == kFsTypeDir,
        size: size,
      ));
    }
    return entries;
  }

  /// Parse a READ_DATA frame. Payload layout:
  ///   [TOTAL_SIZE(4 LE)][OFFSET(4 LE)][DATA(N)]
  static ({int totalSize, int offset, Uint8List data})? parseReadData(
      List<int> payload) {
    if (payload.length < 8) return null;
    final totalSize = payload[0] |
        (payload[1] << 8) |
        (payload[2] << 16) |
        (payload[3] << 24);
    final offset = payload[4] |
        (payload[5] << 8) |
        (payload[6] << 16) |
        (payload[7] << 24);
    final data = Uint8List.fromList(payload.sublist(8));
    return (totalSize: totalSize, offset: offset, data: data);
  }

  /// Parse an INFO_DATA frame. Payload layout:
  ///   [TOTAL(4 LE)][USED(4 LE)][BLOCK_SIZE(2 LE)][FS_TYPE(1)]
  static FsInfo? parseInfoData(List<int> payload) {
    if (payload.length < 11) return null;
    final total    = payload[0] |
        (payload[1] << 8) |
        (payload[2] << 16) |
        (payload[3] << 24);
    final used     = payload[4] |
        (payload[5] << 8) |
        (payload[6] << 16) |
        (payload[7] << 24);
    final blockSize = payload[8] | (payload[9] << 8);
    final fsType    = payload[10];
    return FsInfo(
      totalBytes: total,
      usedBytes: used,
      blockSize: blockSize,
      fsType: fsType,
    );
  }

  /// Parse a single-byte Ack frame (WRITE_ACK, DELETE_ACK, etc.).
  /// Returns the error code, or null if the payload is malformed.
  static int? parseAck(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }
}
