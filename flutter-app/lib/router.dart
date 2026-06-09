import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/device_provider.dart';
import 'screens/home/models_tab.dart';
import 'screens/home/pair_tab.dart';
import 'screens/home/system_tab.dart';
import 'screens/home/dev_tools_tab.dart';
import 'screens/control_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/skin_browser_screen.dart';
import 'screens/home_screen.dart';
import 'screens/designer/designer_screen.dart';
import 'screens/home/designs_tab.dart';
import 'screens/devtools/usb_serial_screen.dart';
import 'screens/devtools/firmware_flasher_screen.dart';
import 'screens/devtools/filesystem/filesystem_explorer_screen.dart';
import 'theme/app_theme.dart';

class ConnectionNotifier extends ChangeNotifier {
  final DeviceProvider _deviceProvider;
  bool _wasConnected;
  bool _wasAuthenticated;

  ConnectionNotifier(this._deviceProvider)
      : _wasConnected = _deviceProvider.isConnected,
        _wasAuthenticated = _deviceProvider.isAuthenticated {
    _deviceProvider.addListener(_onUpdate);
  }

  void _onUpdate() {
    final isConnected = _deviceProvider.isConnected;
    final isAuthenticated = _deviceProvider.isAuthenticated;
    if (isConnected != _wasConnected || isAuthenticated != _wasAuthenticated) {
      _wasConnected = isConnected;
      _wasAuthenticated = isAuthenticated;
      notifyListeners();
    }
  }

  bool get isConnected => _deviceProvider.isConnected;
  bool get isAuthenticated => _deviceProvider.isAuthenticated;
  bool get hasPassword => _deviceProvider.hasPassword;

  @override
  void dispose() {
    _deviceProvider.removeListener(_onUpdate);
    super.dispose();
  }
}

GoRouter createRouter(ConnectionNotifier connectionNotifier) {
  return GoRouter(
    initialLocation: '/models',
    refreshListenable: connectionNotifier,
    redirect: (context, state) {
      final isConnected = connectionNotifier.isConnected;
      final isGuardedRoute = state.matchedLocation == '/control' ||
          state.matchedLocation == '/debug';

      if (isGuardedRoute && !isConnected) {
        return '/models';
      }

      // Auth gate: if the device has a password and the user hasn't
      // authenticated yet, redirect to the models tab. The auth dialog
      // auto-pops up there. After successful auth, this redirect stops firing.
      if (isGuardedRoute && connectionNotifier.hasPassword && !connectionNotifier.isAuthenticated) {
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
                path: '/pair',
                builder: (context, state) => const PairTab(),
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
                path: '/dev-tools',
                builder: (context, state) => const DevToolsTab(),
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
        GoRoute(
          path: '/skins',
          builder: (context, state) => const SkinBrowserScreen(),
        ),
        GoRoute(
          path: '/dev-tools/usb-serial',
          builder: (context, state) => const UsbSerialScreen(),
        ),
        GoRoute(
          path: '/dev-tools/esp32-fs',
          builder: (context, state) => const FilesystemExplorerScreen(),
        ),
        GoRoute(
          path: '/dev-tools/firmware-flasher',
          builder: (context, state) => const FirmwareFlasherScreen(),
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
    final dp = context.read<DeviceProvider>();
    _wasConnected = dp.isConnected;
    dp.addListener(_onUpdate);
  }

  @override
  void dispose() {
    context.read<DeviceProvider>().removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    final dp = context.read<DeviceProvider>();
    final isConnected = dp.isConnected;
    if (_wasConnected && !isConnected && mounted) {
      final reason = dp.errorMessage ?? 'Device disconnected';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          backgroundColor: AppColors.disconnected,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    _wasConnected = isConnected;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
