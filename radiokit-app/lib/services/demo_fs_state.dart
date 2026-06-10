import 'dart:convert';
import 'dart:typed_data';

import '../models/fs_entry.dart';
import '../models/fs_info.dart';

/// Outcome of a single FS operation on the [DemoFsState]. Mirrors the
/// error codes in `protocol.dart` so the simulator can return the same
/// numeric values as a real device.
class FsDemoResult {
  /// `kFsErrOk` on success, otherwise an error code from `protocol.dart`.
  final int code;
  const FsDemoResult(this.code);
  const FsDemoResult.ok() : code = 0;

  bool get isOk => code == 0;

  // Error code constants — must match kFsErr* in protocol.dart.
  static const int errOk = 0x00;
  static const int errNotFound = 0x01;
  static const int errIo = 0x02;
  static const int errNoFs = 0x03;
  static const int errAccessDenied = 0x04;
  static const int errInvalidPath = 0x05;
  static const int errOutOfSpace = 0x06;
  static const int errInvalidState = 0x07;
}

/// A single node in the simulated filesystem.
class FsDemoNode {
  String name;
  final bool isDirectory;
  int size;
  Uint8List data;
  final Map<String, FsDemoNode> children;

  FsDemoNode.file(this.name, this.data)
      : isDirectory = false,
        size = data.length,
        children = const {};

  FsDemoNode.directory(this.name)
      : isDirectory = true,
        size = 0,
        data = Uint8List(0),
        children = {};

}

/// In-memory filesystem used by [DemoFsTransport] to simulate the bulk-FS
/// protocol (0xAA). All operations are synchronous; the transport is
/// responsible for scheduling async dispatch.
class DemoFsState {
  final FsDemoNode _root;
  final Map<String, FsDemoNode> _byPath;

  /// Total size of the simulated partition in bytes.
  final int totalBytes;

  /// Simulated block size.
  final int blockSize;

  /// Out-of-space threshold in bytes (used for OOM simulation in tests).
  final int quota;

  DemoFsState._(this._root, this._byPath)
      : totalBytes = 131072,
        blockSize = 4096,
        quota = 131072;

  /// Build a fresh state seeded with the standard demo tree.
  factory DemoFsState.seeded() {
    final root = FsDemoNode.directory('');
    final byPath = <String, FsDemoNode>{};

    DemoFsState s = DemoFsState._(root, byPath);

    void addDir(String path) {
      final res = s.mkdir(path);
      assert(res.isOk, 'Seeding: failed to create dir $path');
    }

    void addFile(String path, String contents) {
      final bytes = Uint8List.fromList(utf8.encode(contents));
      final res = s.writeFile(path, 0, bytes);
      assert(res.isOk, 'Seeding: failed to write $path');
    }

    addDir('/demo');
    addFile(
      '/demo/README.txt',
      'Hello from the RadioKit demo filesystem!\n'
      '\n'
      'This tree is simulated in-memory by DemoFsState.\n'
      'Try uploading, downloading, renaming and deleting.\n',
    );
    addFile(
      '/demo/sensors.json',
      '{\n'
      '  "device": "radiokit-demo",\n'
      '  "sensors": [\n'
      '    { "id": "temp", "unit": "C", "value": 23.4 },\n'
      '    { "id": "humidity", "unit": "%RH", "value": 51.0 },\n'
      '    { "id": "voltage", "unit": "V", "value": 3.31 }\n'
      '  ],\n'
      '  "updatedAt": "2026-06-06T00:00:00Z"\n'
      '}\n',
    );
    addDir('/scripts');

    return s;
  }

  // ── Path normalisation ────────────────────────────────────────────────

  /// Normalise a path: must start with `/`, no trailing slash, no `..` or `.`
  /// segments. Returns null for invalid paths.
  static String? normalizePath(String input) {
    if (input.isEmpty) return null;
    String p = input;
    if (!p.startsWith('/')) p = '/$p';
    // Strip trailing slashes (but keep root as '/')
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    if (p.contains('..') || p.contains('//')) return null;
    return p;
  }

  String? _norm(String p) => normalizePath(p);

  // ── Lookups ───────────────────────────────────────────────────────────

  FsDemoNode? _get(String path) {
    if (path == '/') return _root;
    return _byPath[path];
  }

  FsDemoNode? _parent(String path) {
    if (path == '/') return null;
    final i = path.lastIndexOf('/');
    if (i <= 0) return _root;
    return _byPath[path.substring(0, i)];
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// List entries of a directory. Returns the entries (sorted: dirs first,
  /// then case-insensitive name) and `notFound` if the path doesn't exist
  /// or isn't a directory.
  ({List<FsEntry> entries, FsDemoResult result}) list(String path) {
    final p = _norm(path);
    if (p == null) {
      return (entries: const [], result: const FsDemoResult(FsDemoResult.errInvalidPath));
    }
    final node = _get(p);
    if (node == null) {
      return (entries: const [], result: const FsDemoResult(FsDemoResult.errNotFound));
    }
    if (!node.isDirectory) {
      return (entries: const [], result: const FsDemoResult(FsDemoResult.errInvalidPath));
    }
    final out = node.children.values
        .map((c) => FsEntry(
              name: c.name,
              isDirectory: c.isDirectory,
              size: c.size,
            ))
        .toList();
    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return (entries: out, result: const FsDemoResult.ok());
  }

  /// Compute info: total partition size, used bytes, block size, fsType.
  FsInfo info() {
    int used = 0;
    _byPath.forEach((path, node) {
      if (path == '/') return;
      used += _ceilBlocks(node.size, blockSize);
    });
    return _info(used);
  }

  /// Build a [FsInfo] from any used-bytes value (used by tests).
  FsInfo _info(int used) {
    return FsInfo(
      totalBytes: totalBytes,
      usedBytes: used,
      blockSize: blockSize,
      fsType: 0x01, // LittleFS
    );
  }

  /// Read up to [length] bytes from [path] starting at [offset].
  /// Returns `null` if the path doesn't exist or isn't a file.
  ({Uint8List data, int totalSize, int offset, FsDemoResult result}) read(
    String path,
    int offset,
    int length,
  ) {
    final p = _norm(path);
    if (p == null) {
      return (
        data: Uint8List(0),
        totalSize: 0,
        offset: 0,
        result: const FsDemoResult(FsDemoResult.errInvalidPath)
      );
    }
    final node = _get(p);
    if (node == null) {
      return (
        data: Uint8List(0),
        totalSize: 0,
        offset: 0,
        result: const FsDemoResult(FsDemoResult.errNotFound)
      );
    }
    if (node.isDirectory) {
      return (
        data: Uint8List(0),
        totalSize: 0,
        offset: 0,
        result: const FsDemoResult(FsDemoResult.errInvalidPath)
      );
    }
    if (offset >= node.size) {
      return (
        data: Uint8List(0),
        totalSize: node.size,
        offset: offset,
        result: const FsDemoResult.ok()
      );
    }
    final end = (offset + length).clamp(0, node.size);
    final out = Uint8List.sublistView(node.data, offset, end);
    return (
      data: out,
      totalSize: node.size,
      offset: offset,
      result: const FsDemoResult.ok()
    );
  }

  /// Write [data] to [path] at [offset]. If the file doesn't exist, it
  /// is created (a parent directory must exist). If it exists and
  /// [offset] is `0`, the file is truncated first.
  FsDemoResult writeFile(String path, int offset, Uint8List data) {
    final p = _norm(path);
    if (p == null || p == '/') {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    if (data.length > quota) {
      return const FsDemoResult(FsDemoResult.errOutOfSpace);
    }
    final node = _get(p);
    if (node != null && node.isDirectory) {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    if (node == null) {
      final parent = _parent(p);
      if (parent == null || !parent.isDirectory) {
        return const FsDemoResult(FsDemoResult.errNotFound);
      }
      final name = _basename(p);
      final newNode = FsDemoNode.file(name, Uint8List(0));
      parent.children[name] = newNode;
      _byPath[p] = newNode;
    }
    final target = _get(p)!;
    // Re-allocate the data buffer to fit the new range.
    final newEnd = offset + data.length;
    if (offset == 0) {
      // Truncate-then-write: replace the entire file contents.
      target.data = Uint8List(newEnd);
    } else if (newEnd > target.data.length) {
      final grown = Uint8List(newEnd);
      grown.setRange(0, target.data.length, target.data);
      target.data = grown;
    }
    target.data.setRange(offset, newEnd, data);
    target.size = target.data.length;
    return const FsDemoResult.ok();
  }

  /// Delete a file or empty directory. If [recursive] is `true` and the
  /// target is a directory, all descendants are removed.
  FsDemoResult delete(String path, {bool recursive = false}) {
    final p = _norm(path);
    if (p == null || p == '/') {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    final node = _get(p);
    if (node == null) {
      return const FsDemoResult(FsDemoResult.errNotFound);
    }
    if (node.isDirectory) {
      if (node.children.isNotEmpty && !recursive) {
        return const FsDemoResult(FsDemoResult.errInvalidState);
      }
      if (recursive) {
        // Remove all descendants from the path index.
        final prefix = '$p/';
        _byPath.removeWhere((k, _) => k == p || k.startsWith(prefix));
      }
    }
    final parent = _parent(p);
    parent?.children.remove(node.name);
    _byPath.remove(p);
    return const FsDemoResult.ok();
  }

  /// Create a directory. Already-exists is treated as success.
  FsDemoResult mkdir(String path) {
    final p = _norm(path);
    if (p == null || p == '/') {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    if (_get(p) != null) {
      return const FsDemoResult.ok();
    }
    final parent = _parent(p);
    if (parent == null || !parent.isDirectory) {
      return const FsDemoResult(FsDemoResult.errNotFound);
    }
    final name = _basename(p);
    final dir = FsDemoNode.directory(name);
    parent.children[name] = dir;
    _byPath[p] = dir;
    return const FsDemoResult.ok();
  }

  /// Replace the content of a file at [path] with [data] in a single call.
  /// CRC32 is verified by the transport layer; the state always trusts the
  /// caller (the demo FS doesn't simulate corruption).
  FsDemoResult replace(String path, Uint8List data) {
    final p = _norm(path);
    if (p == null || p == '/') {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    if (data.length > quota) {
      return const FsDemoResult(FsDemoResult.errOutOfSpace);
    }
    final node = _get(p);
    if (node == null) {
      return const FsDemoResult(FsDemoResult.errNotFound);
    }
    if (node.isDirectory) {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    node.data = Uint8List.fromList(data);
    node.size = data.length;
    return const FsDemoResult.ok();
  }

  /// Compute CRC-32 of the file at [path]. Returns 0 and found=false if
  /// the file doesn't exist or is empty (for empty, found=true, crc32=0).
  ({bool found, int crc32, int size}) getFileCrc32(String path) {
    final p = _norm(path);
    if (p == null) return (found: false, crc32: 0, size: 0);
    final node = _get(p);
    if (node == null || node.isDirectory) return (found: false, crc32: 0, size: 0);
    // CRC-32 (IEEE 802.3)
    int crc = 0xFFFFFFFF;
    for (final byte in node.data) {
      crc ^= byte & 0xFF;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    final computed = crc ^ 0xFFFFFFFF;
    return (found: true, crc32: computed, size: node.size);
  }

  /// Rename (or move) a path. The new path's parent must exist; if a file
  /// already exists at the new path, the operation fails.
  FsDemoResult rename(String oldPath, String newPath) {
    final o = _norm(oldPath);
    final n = _norm(newPath);
    if (o == null || n == null || o == '/' || n == '/') {
      return const FsDemoResult(FsDemoResult.errInvalidPath);
    }
    final src = _get(o);
    if (src == null) {
      return const FsDemoResult(FsDemoResult.errNotFound);
    }
    if (_get(n) != null) {
      return const FsDemoResult(FsDemoResult.errInvalidState);
    }
    final newParent = _parent(n);
    if (newParent == null || !newParent.isDirectory) {
      return const FsDemoResult(FsDemoResult.errNotFound);
    }
    // Detach from old parent.
    final oldParent = _parent(o);
    oldParent?.children.remove(src.name);
    _byPath.remove(o);
    if (src.isDirectory) {
      // Remove the old subtree from the index, then re-add under new path.
      final oldPrefix = '$o/';
      final movedChildren = <String, FsDemoNode>{};
      _byPath.removeWhere((k, v) {
        if (k == o || k.startsWith(oldPrefix)) {
          movedChildren[k == o ? '' : k.substring(oldPrefix.length)] = v;
          return true;
        }
        return false;
      });
      movedChildren.remove('');
      // Attach as new dir
      final newName = _basename(n);
      final newDir = src;
      newDir
        ..name = newName
        ..children;
      newParent.children[newName] = newDir;
      _byPath[n] = newDir;
      for (final entry in movedChildren.entries) {
        if (entry.key.isEmpty) continue;
        _byPath['$n/${entry.key}'] = entry.value;
      }
    } else {
      final newName = _basename(n);
      final renamed = FsDemoNode.file(newName, Uint8List.fromList(src.data))
        ..size = src.size;
      newParent.children[newName] = renamed;
      _byPath[n] = renamed;
    }
    return const FsDemoResult.ok();
  }

  /// Number of nodes (including root) — exposed for tests/diagnostics.
  int get nodeCount => _byPath.length + 1; // +1 for the root
  int get usedBytes {
    int used = 0;
    _byPath.forEach((path, node) {
      if (path == '/') return;
      used += _ceilBlocks(node.size, blockSize);
    });
    return used;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  static int _ceilBlocks(int bytes, int block) {
    if (bytes == 0) return 0;
    return ((bytes + block - 1) ~/ block) * block;
  }
}
