class ApiLogEntry {
  final DateTime timestamp;
  final String method;
  final String path;
  final int statusCode;
  final int durationMs;

  const ApiLogEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
  });

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'method': method,
    'path': path,
    'statusCode': statusCode,
    'durationMs': durationMs,
  };
}
