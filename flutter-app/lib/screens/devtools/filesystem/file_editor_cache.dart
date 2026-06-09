import 'dart:typed_data';

/// A cached file entry with metadata for CRC32-based invalidation.
class _CacheEntry {
  final Uint8List data;
  final DateTime cachedAt;
  int? lastCrc32;
  int? lastSize;

  _CacheEntry(this.data, {this.lastCrc32, this.lastSize})
      : cachedAt = DateTime.now();
}

/// In-memory cache for files downloaded from the device filesystem.
///
/// Each path maps to a [_CacheEntry] holding the raw bytes, the CRC32
/// and size from when the cache was last verified. On subsequent open
/// requests, the caller compares the on-device CRC32 against the cached
/// value — if they match, the cache is used directly without re-fetching.
///
/// The cache is ephemeral (app lifetime only). It is NOT persisted to disk.
class FileEditorCache {
  final Map<String, _CacheEntry> _cache = {};

  /// Total number of cached entries.
  int get count => _cache.length;

  /// Whether [path] is cached.
  bool has(String path) => _cache.containsKey(path);

  /// Retrieve cached data for [path], or null if not cached.
  /// Returns null even if cached but CRC32 mismatched (caller must evict first).
  Uint8List? get(String path) {
    final entry = _cache[path];
    return entry?.data;
  }

  /// Store [data] for [path] with the given [crc32] and [size] from the device.
  void put(String path, Uint8List data, {int? crc32, int? size}) {
    _cache[path] = _CacheEntry(data, lastCrc32: crc32, lastSize: size);
  }

  /// Check whether the cached entry for [path] matches the given [crc32]
  /// and [size]. Returns true if the cache is valid (matches), false if
  /// it needs to be re-fetched, or null if not cached at all.
  bool? isValid(String path, {required int crc32, required int size}) {
    final entry = _cache[path];
    if (entry == null) return null;
    if (entry.lastCrc32 == crc32 && entry.lastSize == size) return true;
    // Mismatch — evict and return false
    _cache.remove(path);
    return false;
  }

  /// Remove [path] from the cache. Called when editing is saved externally
  /// or the file is deleted/renamed on the device.
  void evict(String path) {
    _cache.remove(path);
  }

  /// Evict all cached entries.
  void clear() {
    _cache.clear();
  }
}
