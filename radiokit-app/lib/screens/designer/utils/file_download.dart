import 'dart:convert';
import 'package:file_picker/file_picker.dart';

Future<void> downloadFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  await FilePicker.saveFile(
    fileName: filename,
    bytes: bytes,
  );
}
