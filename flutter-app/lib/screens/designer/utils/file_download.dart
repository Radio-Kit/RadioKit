import 'dart:convert';
import 'package:file_saver/file_saver.dart';

Future<void> downloadFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final name = filename.contains('.')
      ? filename.substring(0, filename.lastIndexOf('.'))
      : filename;
  final ext = filename.contains('.')
      ? filename.substring(filename.lastIndexOf('.') + 1)
      : '';
  await FileSaver.instance.saveAs(
    name: name,
    bytes: bytes,
    fileExtension: ext,
    mimeType: MimeType.other,
  );
}
