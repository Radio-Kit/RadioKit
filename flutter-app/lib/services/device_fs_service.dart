import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/fs_entry.dart';
import '../models/fs_info.dart';
import '../models/protocol.dart';
import 'fs_protocol_service.dart';
import '../providers/device_provider.dart';

// ── CRC-32 (IEEE 802.3) ─────────────────────────────────────────────────────

/// Lazily-initialized CRC-32 lookup table used by [_crc32].
List<int>? _crc32Table;

List<int> _getCrc32Table() {
  if (_crc32Table != null) return _crc32Table!;
  final table = List<int>.generate(256, (i) {
    int crc = i;
    for (int j = 0; j < 8; j++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
    return crc;
  });
  _crc32Table = table;
  return table;
}

/// Compute CRC-32 over [data].
int _crc32(Uint8List data) {
  final table = _getCrc32Table();
  int crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

/// Result of a filesystem write/delete/mkdir/rename operation.
class FsOpResult {
  final bool success;
  final int errorCode;
  final String errorName;
  final String message;

  const FsOpResult({
    required this.success,
    required this.errorCode,
    required this.errorName,
    this.message = '',
  });

  @override
  String toString() => success ? 'OK' : '$errorName ($message)';
}

/// Minimal transport surface required by [DeviceFsService]. Implemented
/// by [DeviceProvider] in production; tests can supply a fake.
abstract class FsTransport {
  bool get isConnected;
  Future<ParsedFsPacket?> sendFs(Uint8List frame, {Duration timeout});
}

/// High-level filesystem service that runs on top of the main
/// [DeviceProvider] transport (BLE or Serial).
///
/// Uses the 0xAA bulk-FS protocol added alongside the widget protocol.
/// Drives [FsTransport] (a minimal `sendFs` / `isConnected` interface
/// that [DeviceProvider] implements).
class DeviceFsService {
  final FsTransport _transport;

  /// Default chunk size for reads. 16 KB accounts for the 8-byte response
  /// header overhead (totalSize(4) + fileOffset(4)) that the ESP32 subtracts
  /// from RK_FS_MAX_PAYLOAD (16384). The effective data per chunk is
  /// RK_FS_MAX_PAYLOAD - 8 = 16376 bytes, which is >= 16384 - 8 = 16376.
  /// This produces ~32 BLE notifications per chunk at MTU 512.
  /// Larger chunks were previously avoided because notification interleaving
  /// at the single-characteristic level caused data corruption at 500KB+ —
  /// this was fixed by dedicated BLE characteristics (0xFFE1 widget, 0xFFE2
  /// FS, 0xFFE3 OTA).
  static const int _defaultChunkSize = 16376;

  /// Default chunk size for writes. 4 KB matches reads — larger chunks
  /// (8 KB) produce ~17 BLE Write-No-Response fragments per chunk, and
  /// BLE Write-No-Response has no application-layer delivery guarantee.
  /// Dropped fragments cause silent data corruption detectable only on
  /// read-back integrity checks.
  static const int _writeChunkSize = 8192;

  /// Max safe payload for a single WRITE frame. Below the 16 KB frame
  /// limit we leave headroom for the path-length byte + offset bytes
  /// + per-frame overhead. Larger files are chunked transparently.
  static const int _maxWriteChunk = 12288;

  /// Timeout for short operations (LIST, INFO, MKDIR, PING, etc.)
  static const Duration _shortTimeout = Duration(seconds: 3);

  /// Timeout for a single read chunk — 15 s (10 KB/s at 4 KB chunks = ~2
  /// chunks = ~1s, so 15s is generous even for slow connections).
  static const Duration _readChunkTimeout = Duration(seconds: 15);

  /// Timeout for write — 30 s (at 18 KB/s this covers ~540 KB per chunk;
  /// larger files are multi-chunked so the per-chunk timeout is sufficient).
  static const Duration _writeTimeout = Duration(seconds: 30);

  DeviceFsService(this._transport);

  bool get isReady => _transport.isConnected;

  /// Internal helper: send an FS frame and await its response.
  Future<ParsedFsPacket?> _sendFs(
    Uint8List frame, {
    Duration timeout = _shortTimeout,
  }) {
    // Defer to the transport — provider's _sendFsRequest handles
    // timeout and disconnect cleanup; tests can supply a fake.
    return _transport.sendFs(frame, timeout: timeout);
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// List a directory's contents.
  Future<List<FsEntry>> listDir(String path) async {
    final resp = await _sendFs(FsProtocolService.buildList(path));
    if (resp == null) return [];
    final entries = FsProtocolService.parseListData(resp.payload);
    return entries ?? <FsEntry>[];
  }

  /// Get filesystem usage info.
  Future<FsInfo?> getInfo() async {
    final resp = await _sendFs(FsProtocolService.buildInfo());
    if (resp == null) return null;
    return FsProtocolService.parseInfoData(resp.payload);
  }

  /// Delete a file or directory at [path].
  Future<FsOpResult> delete(String path, {bool recursive = false}) async {
    final resp = await _sendFs(
        FsProtocolService.buildDelete(path, recursive: recursive));
    if (resp == null) {
      return FsOpResult(
        success: false, errorCode: -1, errorName: 'TIMEOUT',
        message: 'No response from device',
      );
    }
    final code = FsProtocolService.parseAck(resp.payload) ?? -1;
    return FsOpResult(
      success: code == kFsErrOk,
      errorCode: code,
      errorName: fsErrorName(code),
    );
  }

  /// Create a directory at [path].
  Future<FsOpResult> mkdir(String path) async {
    final resp = await _sendFs(FsProtocolService.buildMkdir(path));
    if (resp == null) {
      return FsOpResult(
        success: false, errorCode: -1, errorName: 'TIMEOUT',
        message: 'No response from device',
      );
    }
    final code = FsProtocolService.parseAck(resp.payload) ?? -1;
    return FsOpResult(
      success: code == kFsErrOk,
      errorCode: code,
      errorName: fsErrorName(code),
    );
  }

  /// Rename a file or directory.
  Future<FsOpResult> rename(String oldPath, String newPath) async {
    final resp = await _sendFs(
        FsProtocolService.buildRename(oldPath, newPath));
    if (resp == null) {
      return FsOpResult(
        success: false, errorCode: -1, errorName: 'TIMEOUT',
        message: 'No response from device',
      );
    }
    final code = FsProtocolService.parseAck(resp.payload) ?? -1;
    return FsOpResult(
      success: code == kFsErrOk,
      errorCode: code,
      errorName: fsErrorName(code),
    );
  }

  /// Ping the FS. Returns true if the device replies with OK (mounted),
  /// false on NO_FS / timeout / disconnect. Use for capability detection.
  Future<bool> ping({Duration timeout = const Duration(seconds: 2)}) async {
    final resp = await _sendFs(
      FsProtocolService.buildPing(),
      timeout: timeout,
    );
    if (resp == null) return false;
    final code = FsProtocolService.parseAck(resp.payload) ?? kFsErrNoFs;
    return code == kFsErrOk;
  }

  /// Format the default filesystem. Destructive — erases all data.
  /// Returns true on success.
  Future<FsOpResult> format() async {
    final resp = await _sendFs(
      FsProtocolService.buildFormat(),
      timeout: const Duration(seconds: 10),
    );
    if (resp == null) {
      return FsOpResult(
        success: false, errorCode: -1, errorName: 'TIMEOUT',
        message: 'No response from device',
      );
    }
    final code = FsProtocolService.parseAck(resp.payload) ?? -1;
    return FsOpResult(
      success: code == kFsErrOk,
      errorCode: code,
      errorName: fsErrorName(code),
    );
  }

  /// Read the entire file at [path]. Auto-chunks at [_defaultChunkSize].
  ///
  /// Uses **pipelined reads**: the request for chunk N+1 is sent while
  /// chunk N's response is still in flight (during BLE notification delay).
  /// This hides the request-write round-trip time (~48ms at actual 48ms
  /// conn interval), saving ~48ms per chunk after the first.
  ///
  /// [onProgress] is called with bytesRead/total periodically (best effort).
  /// The transport's _pendingFs uses a FIFO queue per sub-cmd to match
  /// the pipelined responses in order.
  Future<Uint8List?> readFile(
    String path, {
    int chunkSize = _defaultChunkSize,
    void Function(int bytesRead, int totalBytes)? onProgress,
  }) async {
    final buffer = BytesBuilder();

    // Kick off the first chunk request.
    Future<ParsedFsPacket?> pendingResp = _sendFs(
      FsProtocolService.buildRead(path, 0, chunkSize),
      timeout: _readChunkTimeout,
    );
    int offset = 0;
    int? totalSize;

    while (true) {
      if (totalSize != null && offset >= totalSize) break;

      final resp = await pendingResp;
      if (resp == null) return null;

      final parsed = FsProtocolService.parseReadData(resp.payload);
      if (parsed == null) return null;
      totalSize = parsed.totalSize;
      buffer.add(parsed.data);

      offset = parsed.offset + parsed.data.length;
      onProgress?.call(offset, totalSize);

      if (parsed.data.isEmpty || offset >= totalSize) break;

      // Pipeline: send the next chunk's request before the current await
      // completes, so the BLE write overlaps with notification processing.
      pendingResp = _sendFs(
        FsProtocolService.buildRead(path, offset, chunkSize),
        timeout: _readChunkTimeout,
      );
    }

    // Discard any pre-sent-but-unawaited future
    if (offset >= (totalSize ?? 0)) {
      unawaited(pendingResp.catchError((_) {}));
    }

    return buffer.toBytes();
  }

  /// Write [data] to a file at [path] (truncates if exists). Auto-chunks
  /// at [chunkSize] (default [_writeChunkSize]; capped at [_maxWriteChunk]
  /// to leave headroom for the FS frame header and 4-byte offset).
  Future<FsOpResult> writeFile(
    String path,
    Uint8List data, {
    int chunkSize = _writeChunkSize,
    void Function(int bytesWritten, int totalBytes)? onProgress,
  }) async {
    final effectiveChunk = chunkSize > _maxWriteChunk ? _maxWriteChunk : chunkSize;
    int offset = 0;
    while (offset < data.length) {
      final end = (offset + effectiveChunk).clamp(0, data.length);
      final chunk = data.sublist(offset, end);
      final resp = await _sendFs(
        FsProtocolService.buildWrite(path, offset, chunk),
        timeout: _writeTimeout,
      );
      if (resp == null) {
        return FsOpResult(
          success: false, errorCode: -1, errorName: 'TIMEOUT',
          message: 'No response at offset $offset',
        );
      }
      final code = FsProtocolService.parseAck(resp.payload) ?? -1;
      if (code != kFsErrOk) {
        return FsOpResult(
          success: false, errorCode: code, errorName: fsErrorName(code),
        );
      }
      offset = end;
      onProgress?.call(offset, data.length);
    }
    return FsOpResult(
      success: true, errorCode: kFsErrOk, errorName: 'OK',
    );
  }

  // ── Upload Protocol (CRC32-verified) ────────────────────────────────────

  /// Upload [data] to [path] using the CRC32-verified upload protocol.
  ///
  /// Unlike [writeFile], which sends every chunk as a standalone WRITE frame
  /// carrying the full path + offset + data with no integrity check, the
  /// upload protocol:
  ///   1. Sends path + total size once (UPLOAD_BEGIN)
  ///   2. Sends data-only chunks with just offset (UPLOAD_CHUNK) — no path
  ///   3. Verifies CRC32 at the end (UPLOAD_END); file is deleted on mismatch
  ///
  /// This enables safe use of larger chunks (up to [_maxUploadChunk]) because
  /// CRC32 catches BLE Write-No-Response fragment drops that would silently
  /// corrupt data with [writeFile].
  ///
  /// Chunks are serial (no pipelining) — each chunk waits for an ACK before
  /// sending the next. The speed improvement comes from fewer round trips
  /// due to larger chunk size, not from concurrency.
  ///
  /// Returns OK on success, or an error code — notably IO_ERROR if the CRC32
  /// check fails (data was corrupted in transit). The caller can retry.
  static const int _uploadChunkSize = 8192;
  static const int _maxUploadChunk = 12288;

  Future<FsOpResult> writeFileUpload(
    String path,
    Uint8List data, {
    int chunkSize = _uploadChunkSize,
    void Function(int bytesWritten, int totalBytes)? onProgress,
  }) async {
    final effectiveChunk = chunkSize > _maxUploadChunk ? _maxUploadChunk : chunkSize;

    // Compute CRC32 before sending (the reference checksum)
    final fileCrc = _crc32(data);

    // Phase 1: Begin
    var resp = await _sendFs(
      FsProtocolService.buildUploadBegin(path, data.length),
      timeout: _writeTimeout,
    );
    if (resp == null) {
      return FsOpResult(
        success: false, errorCode: -1, errorName: 'TIMEOUT',
        message: 'No response from UPLOAD_BEGIN',
      );
    }
    var code = FsProtocolService.parseAck(resp.payload) ?? -1;
    if (code != kFsErrOk) {
      return FsOpResult(
        success: false, errorCode: code, errorName: fsErrorName(code),
        message: 'UPLOAD_BEGIN failed',
      );
    }

    // Phase 2: Chunks
    int offset = 0;
    while (offset < data.length) {
      final end = (offset + effectiveChunk).clamp(0, data.length);
      final chunk = data.sublist(offset, end);
      resp = await _sendFs(
        FsProtocolService.buildUploadChunk(offset, chunk),
        timeout: _writeTimeout,
      );
      if (resp == null) {
        return FsOpResult(
          success: false, errorCode: -1, errorName: 'TIMEOUT',
          message: 'No response at offset $offset',
        );
      }
      code = FsProtocolService.parseAck(resp.payload) ?? -1;
      if (code != kFsErrOk) {
        return FsOpResult(
          success: false, errorCode: code, errorName: fsErrorName(code),
          message: 'UPLOAD_CHUNK failed at offset $offset',
        );
      }
      offset = end;
      onProgress?.call(offset, data.length);
    }

    // Phase 3: End (CRC32 verification)
    resp = await _sendFs(
      FsProtocolService.buildUploadEnd(fileCrc),
      timeout: _shortTimeout,
    );
    if (resp == null) {
      return FsOpResult(
        success: false, errorCode: -1, errorName: 'TIMEOUT',
        message: 'No response from UPLOAD_END',
      );
    }
    code = FsProtocolService.parseAck(resp.payload) ?? -1;
    if (code != kFsErrOk) {
      return FsOpResult(
        success: false, errorCode: code, errorName: fsErrorName(code),
        message: 'UPLOAD_END CRC32 mismatch — file deleted on device',
      );
    }

    return FsOpResult(
      success: true, errorCode: kFsErrOk, errorName: 'OK',
    );
  }

  // ── REPLACE (single-frame CRC32-verified) ──────────────────────────────

  /// Replace the content of a file in a single frame with CRC32 verification.
  /// For files that fit within [FsProtocolService.replaceMaxContent].
  /// Falls back to [writeFileUpload] for larger files.
  Future<FsOpResult> replaceFile(String path, Uint8List data) async {
    final maxContent = FsProtocolService.replaceMaxContent(path);
    if (data.length <= maxContent) {
      // Single-frame REPLACE with CRC32
      final crc32 = _crc32(data);
      final resp = await _sendFs(
        FsProtocolService.buildReplace(path, data, crc32),
        timeout: _writeTimeout,
      );
      if (resp == null) {
        return FsOpResult(
          success: false, errorCode: -1, errorName: 'TIMEOUT',
          message: 'No response from REPLACE',
        );
      }
      final code = FsProtocolService.parseAck(resp.payload) ?? -1;
      if (code != kFsErrOk) {
        // REPLACE failed — fall back to basic WRITE protocol.
        // This happens on devices with older firmware that don't
        // support the REPLACE command, or when FS is in a stale state.
        return _fallbackWrite(path, data);
      }
      return FsOpResult(success: true, errorCode: kFsErrOk, errorName: 'OK');
    }
    // Larger files: fall back to CRC32-verified upload protocol
    return writeFileUpload(path, data);
  }

  /// Internal: fallback when REPLACE fails (e.g. older firmware).
  /// Delegates to [writeFile], which uses the basic WRITE protocol.
  Future<FsOpResult> _fallbackWrite(String path, Uint8List data) async {
    return writeFile(path, data);
  }

  // ── CRC32 query ─────────────────────────────────────────────────────────

  /// Request the CRC32 checksum and file size from the device.
  /// Returns null on timeout or malformed response.
  Future<({bool found, int crc32, int size})?> getFileCrc32(String path) async {
    final resp = await _sendFs(
      FsProtocolService.buildCrc32(path),
      timeout: const Duration(seconds: 3),
    );
    if (resp == null) return null;
    return FsProtocolService.parseCrc32Data(resp.payload);
  }
}

/// Convenience: build a [DeviceFsService] that routes through a
/// [DeviceProvider]. Equivalent to `DeviceFsService(_ProviderAdapter(p))`
/// but keeps the construction site tidy.
DeviceFsService createDeviceFsService(DeviceProvider provider) =>
    DeviceFsService(_ProviderAdapter(provider));

/// Adapter that exposes a [DeviceProvider] as an [FsTransport].
/// Acquires/releases the FS busy lock around every `sendFs` call so the
/// ping timer doesn't inject PONG frames into the FS response stream.
class _ProviderAdapter implements FsTransport {
  final DeviceProvider _provider;
  _ProviderAdapter(this._provider);

  @override
  bool get isConnected => _provider.isConnected;

  @override
  Future<ParsedFsPacket?> sendFs(
    Uint8List frame, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Lock FS busy before any I/O so the ping timer can't send new PINGs
    // that could interleave with FS response notifications.
    _provider.setFsBusy(true);

    try {
      return await _provider.sendFs(frame, timeout: timeout);
    } finally {
      _provider.setFsBusy(false);
    }
  }
}
