import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

import 'providers/ble_provider.dart';
import 'providers/console_provider.dart';
import 'providers/debug_provider.dart';
import 'providers/designs_provider.dart';
import 'providers/device_provider.dart';
import 'providers/history_provider.dart';
import 'providers/mdns_provider.dart';
import 'providers/cloud_identity_provider.dart';
import 'providers/remote_access_provider.dart';
import 'providers/serial_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_preset_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/account_provider.dart';
import 'providers/flasher_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class RadioKitApp extends StatefulWidget {
  const RadioKitApp({super.key});

  @override
  State<RadioKitApp> createState() => _RadioKitAppState();
}

class _RadioKitAppState extends State<RadioKitApp> {
  late final BleProvider _bleProvider;
  late final MdnsProvider _mdnsProvider;
  late final CloudIdentityProvider _cloudIdentityProvider;
  late final SerialProvider _serialProvider;
  late final DebugProvider _debugProvider;
  late final HistoryProvider _historyProvider;
  late final ConsoleProvider _consoleProvider;
  late final DeviceProvider _deviceProvider;
  late final ThemePresetProvider _themePresetProvider;
  late final SettingsProvider _settingsProvider;
  late final DesignsProvider _designsProvider;
  late final RemoteAccessProvider _remoteAccessProvider;
  late final AccountProvider _accountProvider;
  late final FlasherProvider _flasherProvider;
  late final ConnectionNotifier _connectionNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _themePresetProvider = ThemePresetProvider();
    _themePresetProvider.init(); // Restore persisted theme choice
    
    _settingsProvider = SettingsProvider();
    _designsProvider = DesignsProvider();
    _designsProvider.load();
    
    _bleProvider = BleProvider();
    _mdnsProvider = MdnsProvider();
    _cloudIdentityProvider = CloudIdentityProvider();
    _cloudIdentityProvider.initialize();
    _serialProvider = SerialProvider();
    _debugProvider = DebugProvider();
    _historyProvider = HistoryProvider();
    _consoleProvider = ConsoleProvider();

    _deviceProvider = DeviceProvider(
      transport: _bleProvider.bleService,
      debugSink: _debugProvider,
      console: _consoleProvider,
      themePresetProvider: _themePresetProvider,
      historyProvider: _historyProvider,
    );

    _flasherProvider = FlasherProvider();

    _accountProvider = AccountProvider();
    _accountProvider.load();

    _remoteAccessProvider = RemoteAccessProvider(
      settingsProvider: _settingsProvider,
      deviceProvider: _deviceProvider,
      bleProvider: _bleProvider,
      serialProvider: _serialProvider,
      historyProvider: _historyProvider,
      consoleProvider: _consoleProvider,
      designsProvider: _designsProvider,
      cloudIdentityProvider: _cloudIdentityProvider,
      accountProvider: _accountProvider,
      flasherProvider: _flasherProvider,
    );

    _connectionNotifier = ConnectionNotifier(_deviceProvider);
    _router = createRouter(_connectionNotifier);
  }

  @override
  void dispose() {
    _connectionNotifier.dispose();
    _settingsProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
        ChangeNotifierProvider<ThemePresetProvider>.value(value: _themePresetProvider),
        ChangeNotifierProvider<BleProvider>.value(value: _bleProvider),
        ChangeNotifierProvider<MdnsProvider>.value(value: _mdnsProvider),
        ChangeNotifierProvider<CloudIdentityProvider>.value(
            value: _cloudIdentityProvider),
        ChangeNotifierProvider<SerialProvider>.value(value: _serialProvider),
        ChangeNotifierProvider<DebugProvider>.value(value: _debugProvider),
        ChangeNotifierProvider<HistoryProvider>.value(value: _historyProvider),
        ChangeNotifierProvider<ConsoleProvider>.value(value: _consoleProvider),
        ChangeNotifierProvider<DeviceProvider>.value(value: _deviceProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: _settingsProvider),
        ChangeNotifierProvider<DesignsProvider>.value(value: _designsProvider),
        ChangeNotifierProvider<RemoteAccessProvider>.value(
            value: _remoteAccessProvider),
        ChangeNotifierProvider<AccountProvider>.value(value: _accountProvider),
        ChangeNotifierProvider<FlasherProvider>.value(value: _flasherProvider),
      ],
      child: Consumer2<ThemeProvider, ThemePresetProvider>(
        builder: (context, themeProvider, themePresetProvider, child) {
          return RKTheme(
            tokens: themePresetProvider.tokens,
            child: MaterialApp.router(
              title: 'RadioKit',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.fromTokens(themePresetProvider.tokens, Brightness.light),
              darkTheme: AppTheme.fromTokens(themePresetProvider.tokens, Brightness.dark),
              themeMode: themeProvider.themeMode,
              routerConfig: _router,
              builder: (context, child) {
                return ConnectionListener(
                  child: _FollowModeWrapper(
                    router: _router,
                    child: child!,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// App-level follow-mode overlay.
///
/// Wraps every route with:
/// 1. Follow navigation listener (navigates when followNavigationTarget fires)
/// 2. Edge glow halo (pulses blue then fades to yellow on navigation)
/// 3. [AbsorbPointer] on all routes EXCEPT `/control` (user interacts with
///    the controller even in follow mode)
/// 4. Red STOP button to exit follow mode
///
/// Uses [GoRouter] directly (passed from parent) instead of
/// [GoRouter.of(context)] because the InheritedWidget is inside the
/// Navigator and not accessible from this widget's build context.
class _FollowModeWrapper extends StatefulWidget {
  final GoRouter router;
  final Widget child;
  const _FollowModeWrapper({
    required this.router,
    required this.child,
  });

  @override
  State<_FollowModeWrapper> createState() => _FollowModeWrapperState();
}

class _FollowModeWrapperState extends State<_FollowModeWrapper> {
  String _currentLocation = '';

  @override
  void initState() {
    super.initState();
    final ra = context.read<RemoteAccessProvider>();
    ra.followNavigationTarget.addListener(_onFollow);

    // Defer initial location sync and listener registration to post-frame
    // so the router delegate is fully initialized.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLocation();
      // RouterDelegate extends Listenable — exposes addListener/removeListener.
      widget.router.routerDelegate.addListener(_onRouteChanged);
    });
  }

  @override
  void dispose() {
    context
        .read<RemoteAccessProvider>()
        .followNavigationTarget
        .removeListener(_onFollow);
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    _syncLocation();
  }

  void _syncLocation() {
    if (!mounted) return;
    try {
      final config = widget.router.routerDelegate.currentConfiguration;
      final loc = config.uri.toString();
      if (loc != _currentLocation) {
        setState(() => _currentLocation = loc);
      }
      // Expose current route to the remote API session endpoint.
      context.read<RemoteAccessProvider>().updateCurrentRoute(loc);
    } catch (e) {
      debugPrint('FollowMode: _syncLocation error: $e');
    }
  }

  void _onFollow() {
    final ra = context.read<RemoteAccessProvider>();
    final settings = context.read<SettingsProvider>();
    if (!settings.followRemoteAccess) return;
    final route = ra.consumeFollowTarget();
    if (route == null) return;
    // Skip re-navigation if already on this route — avoids recreating
    // screens and triggering redundant FS operations during transfers.
    if (_currentLocation == route) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        widget.router.go(route);
      } catch (e) {
        debugPrint('FollowRemote: go($route) failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ra = context.watch<RemoteAccessProvider>();
    final settings = context.watch<SettingsProvider>();
    final follow = settings.followRemoteAccess;

    if (!follow) return widget.child;

    final isControlScreen = _currentLocation == '/control' ||
        _currentLocation.startsWith('/control?');

    Widget body = widget.child;
    if (!isControlScreen) {
      body = AbsorbPointer(child: body);
    }

    return Stack(
      children: [
        body,
        // Edge glow that pulses on navigation
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<Color>(
              valueListenable: ra.glowColor,
              builder: (_, color, __) => Stack(
                children: [
                  Positioned(
                    top: 0, left: 0, right: 0, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            color.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0, bottom: 0, left: 0, width: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            color.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0, bottom: 0, right: 0, width: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            color.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Red STOP button
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'follow_stop',
            backgroundColor: context.tokens.error,
            onPressed: () => settings.setFollowRemoteAccess(false),
            child: Icon(Icons.stop_rounded, color: context.tokens.onError),
          ),
        ),
      ],
    );
  }
}
