import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/fs_entry.dart';
import '../models/fs_info.dart';
import '../models/protocol.dart';
import 'fs_protocol_service.dart';
import '../providers/device_provider.dart';

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

  /// Default chunk size for reads/writes. 8 KB is a good balance between
  /// BLE per-round-trip latency and avoiding massive buffers.
  static const int _defaultChunkSize = 8192;

  /// Max safe payload for a single WRITE frame. Below the 16 KB frame
  /// limit we leave headroom for the path-length byte + offset bytes
  /// + per-frame overhead. Larger files are chunked transparently.
  static const int _maxWriteChunk = 12288;

  /// Timeout for short operations (LIST, INFO, MKDIR, etc.)
  static const Duration _shortTimeout = Duration(seconds: 5);

  /// Timeout for a single read chunk — 30 s to accommodate slow connections.
  static const Duration _readChunkTimeout = Duration(seconds: 30);

  /// Timeout for write — 60 s for large file uploads.
  static const Duration _writeTimeout = Duration(seconds: 60);

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
      timeout: const Duration(seconds: 30),
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
  /// [onProgress] is called with bytesRead/total periodically (best effort).
  Future<Uint8List?> readFile(
    String path, {
    int chunkSize = _defaultChunkSize,
    void Function(int bytesRead, int totalBytes)? onProgress,
  }) async {
    int offset = 0;
    int? totalSize;
    final buffer = BytesBuilder();

    while (true) {
      if (totalSize != null && offset >= totalSize) break;

      final resp = await _sendFs(
        FsProtocolService.buildRead(path, offset, chunkSize),
        timeout: _readChunkTimeout,
      );
      if (resp == null) return null;

      final parsed = FsProtocolService.parseReadData(resp.payload);
      if (parsed == null) {
        debugPrint('DeviceFsService: malformed READ_DATA');
        return null;
      }
      totalSize = parsed.totalSize;
      buffer.add(parsed.data);

      offset = parsed.offset + parsed.data.length;
      onProgress?.call(offset, totalSize);

      if (parsed.data.isEmpty || offset >= totalSize) break;
      if (parsed.data.length < chunkSize) break;
    }

    return buffer.toBytes();
  }

  /// Write [data] to a file at [path] (truncates if exists). Auto-chunks
  /// at [chunkSize] (default 8 KB; capped at [_maxWriteChunk] to leave
  /// headroom for the FS frame header and 4-byte offset).
  Future<FsOpResult> writeFile(
    String path,
    Uint8List data, {
    int chunkSize = _defaultChunkSize,
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
}

/// Convenience: build a [DeviceFsService] that routes through a
/// [DeviceProvider]. Equivalent to `DeviceFsService(_ProviderAdapter(p))`
/// but keeps the construction site tidy.
DeviceFsService createDeviceFsService(DeviceProvider provider) =>
    DeviceFsService(_ProviderAdapter(provider));

/// Adapter that exposes a [DeviceProvider] as an [FsTransport].
class _ProviderAdapter implements FsTransport {
  final DeviceProvider _provider;
  _ProviderAdapter(this._provider);

  @override
  bool get isConnected => _provider.isConnected;

  @override
  Future<ParsedFsPacket?> sendFs(
    Uint8List frame, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _provider.sendFs(frame, timeout: timeout);
}
