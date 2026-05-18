import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadFile(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
    
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
