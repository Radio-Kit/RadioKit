import 'package:flutter/foundation.dart';
import '../models/api_log_entry.dart';

/// No-op stub for web builds where dart:io is unavailable.
class RemoteAccessService {
  bool isRunning = false;
  int actualPort = 0;
  String localIp = '127.0.0.1';
  void Function(ApiLogEntry)? onLog;

  // ignore: unused_element
  RemoteAccessService({
    required void Function(ApiLogEntry) onLog,
    // ignore: avoid_unused_constructor_parameters
    required dynamic consoleProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic designsProvider,
    void Function(String route)? onFollowEvent,
  }) : onLog = onLog {
    this.onLog = onLog;
  }

  Future<void> start() async {
    debugPrint('RadioKit: Remote access server not available on web');
  }

  Future<void> stop() async {}
}
