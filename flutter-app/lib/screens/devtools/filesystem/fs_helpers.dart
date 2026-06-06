import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Human-readable byte size. Uses binary (KiB, MiB) units.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Returns the file extension (lowercase, no dot) or `''` if none.
String fileExtension(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0 || i == name.length - 1) return '';
  return name.substring(i + 1).toLowerCase();
}

/// Returns the basename portion of a path.
String baseName(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? path : path.substring(i + 1);
}

/// Returns the parent directory portion of a path. Always ends without `/`.
String parentPath(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final i = path.lastIndexOf('/');
  if (i <= 0) return '/';
  return path.substring(0, i);
}

/// Joins a parent and a child with a single `/` between them.
String joinPath(String parent, String child) {
  if (parent == '/' || parent.isEmpty) return '/$child';
  return '$parent/$child';
}

/// Splits `/foo/bar/baz` into `['foo', 'bar', 'baz']`.
List<String> pathSegments(String path) {
  if (path == '/' || path.isEmpty) return const [];
  return path.split('/').where((s) => s.isNotEmpty).toList(growable: false);
}

/// Picks an M3-appropriate icon and accent color for a file or directory.
({IconData icon, Color color}) fileVisual(String name, {required bool isDir}) {
  if (isDir) {
    return (icon: LucideIcons.folder, color: const Color(0xFFFFB74D));
  }
  final ext = fileExtension(name);
  switch (ext) {
    case 'json':
      return (icon: LucideIcons.fileJson2, color: const Color(0xFFFFCA28));
    case 'html':
    case 'htm':
    case 'xml':
    case 'css':
    case 'js':
    case 'ts':
    case 'dart':
    case 'cpp':
    case 'c':
    case 'h':
    case 'py':
      return (icon: LucideIcons.fileCode2, color: const Color(0xFF64B5F6));
    case 'md':
    case 'txt':
    case 'log':
      return (icon: LucideIcons.fileText, color: const Color(0xFFB0BEC5));
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return (icon: LucideIcons.fileImage, color: const Color(0xFFBA68C8));
    case 'mp3':
    case 'wav':
    case 'ogg':
    case 'flac':
      return (icon: LucideIcons.fileMusic, color: const Color(0xFFF06292));
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return (icon: LucideIcons.fileVideo, color: const Color(0xFF9575CD));
    case 'zip':
    case 'gz':
    case 'tar':
    case '7z':
    case 'rar':
      return (icon: LucideIcons.fileArchive, color: const Color(0xFFA1887F));
    case 'bin':
    case 'hex':
    case 'elf':
      return (icon: LucideIcons.binary, color: const Color(0xFF90A4AE));
    case 'csv':
    case 'tsv':
    case 'xls':
    case 'xlsx':
      return (icon: LucideIcons.fileSpreadsheet, color: const Color(0xFF81C784));
    case 'pdf':
      return (icon: LucideIcons.fileText, color: const Color(0xFFEF5350));
    default:
      return (icon: LucideIcons.file, color: const Color(0xFF90A4AE));
  }
}
