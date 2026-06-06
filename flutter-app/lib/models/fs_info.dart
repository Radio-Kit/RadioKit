/// Filesystem information returned by FS_INFO_DATA.
class FsInfo {
  final int totalBytes;
  final int usedBytes;
  final int blockSize;

  /// 0x01 = LittleFS, other values reserved for future backends.
  final int fsType;

  const FsInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.blockSize,
    required this.fsType,
  });

  int get freeBytes => totalBytes - usedBytes;
  double get usedFraction =>
      totalBytes == 0 ? 0 : usedBytes / totalBytes.toDouble();

  String get fsTypeName {
    switch (fsType) {
      case 0x01: return 'LittleFS';
      default:   return 'Unknown($fsType)';
    }
  }

  @override
  String toString() =>
      'FsInfo($fsTypeName, ${usedBytes ~/ 1024}K/${totalBytes ~/ 1024}K, '
      'block=$blockSize)';
}
