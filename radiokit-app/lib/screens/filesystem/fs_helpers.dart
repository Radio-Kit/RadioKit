import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
    return (icon: PhosphorIconsFill.folder, color: const Color(0xFFFFB74D));
  }
  final ext = fileExtension(name);
  switch (ext) {
    case 'json':
      return (icon: PhosphorIconsFill.fileJs, color: const Color(0xFFFFCA28));
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
      return (icon: PhosphorIconsFill.fileCode, color: const Color(0xFF64B5F6));
    case 'md':
    case 'txt':
    case 'log':
      return (icon: PhosphorIconsFill.fileText, color: const Color(0xFFB0BEC5));
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return (icon: PhosphorIconsFill.fileImage, color: const Color(0xFFBA68C8));
    case 'mp3':
    case 'wav':
    case 'ogg':
    case 'flac':
      return (icon: PhosphorIconsFill.fileAudio, color: const Color(0xFFF06292));
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return (icon: PhosphorIconsFill.fileVideo, color: const Color(0xFF9575CD));
    case 'zip':
    case 'gz':
    case 'tar':
    case '7z':
    case 'rar':
      return (icon: PhosphorIconsFill.fileArchive, color: const Color(0xFFA1887F));
    case 'bin':
    case 'hex':
    case 'elf':
      return (icon: PhosphorIconsFill.binary, color: const Color(0xFF90A4AE));
    case 'csv':
    case 'tsv':
    case 'xls':
    case 'xlsx':
      return (icon: PhosphorIconsFill.fileXls, color: const Color(0xFF81C784));
    case 'pdf':
      return (icon: PhosphorIconsFill.fileText, color: const Color(0xFFEF5350));
    default:
      return (icon: PhosphorIconsFill.file, color: const Color(0xFF90A4AE));
  }
}

/// Returns true if the file extension indicates a text/code file that
/// can be edited in the file editor dialog.
bool isEditableFile(String name) {
  final ext = fileExtension(name);
  switch (ext) {
    case 'json':
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
    case 'md':
    case 'txt':
    case 'log':
    case 'csv':
    case 'tsv':
    case 'yaml':
    case 'yml':
    case 'toml':
    case 'ini':
    case 'cfg':
    case 'conf':
    case 'env':
    case 'sh':
    case 'bash':
    case 'zsh':
    case 'fish':
    case 'makefile':
    case 'gradle':
    case 'properties':
    case 'svg':
      return true;
    default:
      return false;
  }
}

/// Decode [bytes] as UTF-8, falling back to Latin-1 on malformed input.
String utf8DecodeWithFallback(Uint8List bytes) {
  try {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  } catch (_) {
    return String.fromCharCodes(bytes);
  }
}
