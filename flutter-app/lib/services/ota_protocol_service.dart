import 'dart:typed_data';
import '../models/protocol.dart';

/// Result of parsing a 0xBB OTA frame.
class ParsedOtaPacket {
  final int subCmd;
  final Uint8List payload;
  const ParsedOtaPacket({required this.subCmd, required this.payload});

  @override
  String toString() =>
      'ParsedOtaPacket(sub=0x${subCmd.toRadixString(16).padLeft(2, "0")}, '
      'payloadLen=${payload.length})';
}

/// Build and parse 0xBB OTA frames. Mirrors the Arduino side
/// (RadioKitOTA.h / RadioKitOTA.cpp).
class OtaProtocolService {
  // ── Frame building ──────────────────────────────────────────────────────

  /// Build a complete OTA frame:
  ///   [0xBB] [SUB_CMD(1)] [LEN_LO(1)] [LEN_HI(1)] [PAYLOAD(N)]
  static Uint8List buildFrame(int subCmd, [List<int>? payload]) {
    final p = payload ?? const [];
    final total = kOtaHeaderSize + p.length;
    if (total > 0xFFFF) {
      throw ArgumentError('OTA frame too large: $total bytes');
    }
    final frame = Uint8List(total);
    frame[0] = kOtaStartByte;
    frame[1] = subCmd & 0xFF;
    frame[2] = total & 0xFF;
    frame[3] = (total >> 8) & 0xFF;
    for (int i = 0; i < p.length; i++) {
      frame[kOtaHeaderSize + i] = p[i] & 0xFF;
    }
    return frame;
  }

  // ── Request builders ────────────────────────────────────────────────────

  /// OTA_BEGIN: [firmwareSize(4 LE)]
  static Uint8List buildBegin(int firmwareSize) {
    return buildFrame(kOtaCmdBegin, [
      firmwareSize & 0xFF,
      (firmwareSize >> 8) & 0xFF,
      (firmwareSize >> 16) & 0xFF,
      (firmwareSize >> 24) & 0xFF,
    ]);
  }

  /// OTA_CHUNK: [offset(4 LE)] [data...]
  static Uint8List buildChunk(int offset, List<int> data) {
    final p = <int>[
      offset & 0xFF,
      (offset >> 8) & 0xFF,
      (offset >> 16) & 0xFF,
      (offset >> 24) & 0xFF,
    ];
    p.addAll(data);
    return buildFrame(kOtaCmdChunk, p);
  }

  /// OTA_END: [crc32(4 LE)]
  static Uint8List buildEnd(int crc32) {
    return buildFrame(kOtaCmdEnd, [
      crc32 & 0xFF,
      (crc32 >> 8) & 0xFF,
      (crc32 >> 16) & 0xFF,
      (crc32 >> 24) & 0xFF,
    ]);
  }

  /// OTA_ABORT: empty payload
  static Uint8List buildAbort() => buildFrame(kOtaCmdAbort);

  // ── Frame parsing ───────────────────────────────────────────────────────

  /// Parse a complete 0xBB frame from raw bytes.
  static ParsedOtaPacket? parseFrame(List<int> data) {
    if (data.length < kOtaHeaderSize) return null;
    if (data[0] != kOtaStartByte) return null;
    final subCmd = data[1];
    final payload = Uint8List.fromList(data.sublist(kOtaHeaderSize));
    return ParsedOtaPacket(subCmd: subCmd, payload: payload);
  }

  // ── Response parsers ────────────────────────────────────────────────────

  /// Parse OTA_ACK: 1-byte error code, or null if malformed.
  static int? parseAck(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }

  /// Parse OTA_PROGRESS: [received(4 LE)] [total(4 LE)]
  /// Returns (received, total) or null.
  static (int, int)? parseProgress(List<int> payload) {
    if (payload.length < 8) return null;
    final received = payload[0] |
        (payload[1] << 8) |
        (payload[2] << 16) |
        (payload[3] << 24);
    final total = payload[4] |
        (payload[5] << 8) |
        (payload[6] << 16) |
        (payload[7] << 24);
    return (received, total);
  }
}
