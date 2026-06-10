import 'package:flutter/foundation.dart';

enum ConsoleLogLevel { info, success, warning, error, raw }

@immutable
class ConsoleEntry {
  final DateTime timestamp;
  final String message;
  final ConsoleLogLevel level;

  const ConsoleEntry({
    required this.timestamp,
    required this.message,
    this.level = ConsoleLogLevel.info,
  });

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
