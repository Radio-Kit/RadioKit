import 'package:flutter/foundation.dart';
import '../models/api_log_entry.dart';

/// No-op stub for web builds where dart:io is unavailable.
class RemoteAccessService {
  bool isRunning = false;
  int actualPort = 0;
  String localIp = '127.0.0.1';

  RemoteAccessService({
    required void Function(ApiLogEntry) onLog,
    // ignore: avoid_unused_constructor_parameters
    required dynamic getActiveDevice,
    // ignore: avoid_unused_constructor_parameters
    required dynamic bleProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic serialProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic historyProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic settingsProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic consoleProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic designsProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic cloudIdentityProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic accountProvider,
    // ignore: avoid_unused_constructor_parameters
    required dynamic flasherProvider,
    // ignore: avoid_unused_constructor_parameters
    dynamic getMultiDevice,
    void Function(String route)? onFollowEvent,
    String Function() currentRouteGetter = _defaultRoute,
    // ignore: avoid_unused_constructor_parameters
    dynamic connectDemo,
    // ignore: avoid_unused_constructor_parameters
    dynamic libraryService,
  });

  static String _defaultRoute() => '';

  Future<String?> start() async {
    debugPrint('RadioKit: Remote access server not available on web');
    return null;
  }

  Future<void> stop() async {}

  static String? testOnlyFollowRoute(String path) => null;
}
