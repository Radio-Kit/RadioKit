/// A single entry from FS_LIST_DATA: file or directory.
class FsEntry {
  final String name;
  final bool isDirectory;
  final int size;

  const FsEntry({
    required this.name,
    required this.isDirectory,
    required this.size,
  });

  @override
  String toString() => 'FsEntry($name, ${isDirectory ? "dir" : "file"}, $size bytes)';
}
