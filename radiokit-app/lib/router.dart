import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/multi_device_provider.dart';
import 'screens/home/models_tab.dart';
import 'screens/home/system_tab.dart';
import 'screens/home/flasher_tab.dart';
import 'screens/control_ui/control_screen.dart';
import 'screens/control_ui/debug_screen.dart';
import 'screens/home_screen.dart';
import 'screens/designer/designer_screen.dart';
import 'screens/home/designs_tab.dart';
import 'theme/app_theme.dart';

class ConnectionNotifier extends ChangeNotifier {
  final MultiDeviceProvider _multiDeviceProvider;
  bool _wasConnected;

  ConnectionNotifier(this._multiDeviceProvider)
      : _wasConnected = _multiDeviceProvider.anyConnected {
    _multiDeviceProvider.addListener(_onUpdate);
  }

  void _onUpdate() {
    // Only re-evaluate when MultiDeviceProvider notifies (connect/disconnect)
    // This is fine because MultiDeviceProvider only calls notifyListeners
    // on connect/disconnect/focus changes, not on widget value updates.
    final isConnected = _multiDeviceProvider.anyConnected;
    if (isConnected != _wasConnected) {
      _wasConnected = isConnected;
      notifyListeners();
    }
  }

  bool get isConnected => _multiDeviceProvider.anyConnected;

  @override
  void dispose() {
    _multiDeviceProvider.removeListener(_onUpdate);
    super.dispose();
  }
}

GoRouter createRouter(ConnectionNotifier connectionNotifier) {
  return GoRouter(
    initialLocation: '/models',
    refreshListenable: connectionNotifier,
    redirect: (context, state) {
      final isConnected = connectionNotifier.isConnected;
      final matchedPath = state.matchedLocation;

      // Guard /control/* routes (both /control and /control/:deviceId)
      final isControlRoute = matchedPath == '/control' ||
          matchedPath.startsWith('/control/');
      final isDebugRoute = matchedPath == '/debug';

      if ((isControlRoute || isDebugRoute) && !isConnected) {
        return '/models';
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/models',
                builder: (context, state) => const ModelsTab(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/flasher',
                builder: (context, state) => const FlasherTab(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/designs',
                builder: (context, state) => const DesignsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/system',
                builder: (context, state) => const SystemTab(),
              ),
            ],
          ),
        ],
      ),
      // Device-specific control screen
      GoRoute(
        path: '/control/:deviceId',
        builder: (context, state) {
          final deviceId = state.pathParameters['deviceId']!;
          return ControlScreen(deviceId: deviceId);
        },
      ),
      // Bare /control route (no deviceId) — used by follow-mode API
      GoRoute(
        path: '/control',
        builder: (context, state) => const ControlScreen(),
      ),

      GoRoute(
        path: '/designer',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return DesignerScreen(designId: id);
        },
      ),
       GoRoute(
         path: '/debug',
         builder: (context, state) => const DebugScreen(),
       ),
    ],
  );
}

class ConnectionListener extends StatefulWidget {
  final Widget child;
  const ConnectionListener({super.key, required this.child});

  @override
  State<ConnectionListener> createState() => _ConnectionListenerState();
}

class _ConnectionListenerState extends State<ConnectionListener> {
  bool _wasConnected = false;

  @override
  void initState() {
    super.initState();
    final multiDevice = context.read<MultiDeviceProvider>();
    _wasConnected = multiDevice.anyConnected;
    multiDevice.addListener(_onUpdate);
  }

  @override
  void dispose() {
    context.read<MultiDeviceProvider>().removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    final multiDevice = context.read<MultiDeviceProvider>();
    final isConnected = multiDevice.anyConnected;
    if (_wasConnected && !isConnected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All devices disconnected'),
          backgroundColor: context.tokens.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    _wasConnected = isConnected;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
