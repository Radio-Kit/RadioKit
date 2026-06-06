import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'theme/app_theme.dart';
import 'providers/ble_provider.dart';
import 'providers/serial_provider.dart';
import 'providers/device_provider.dart';
import 'providers/debug_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/history_provider.dart';
import 'providers/console_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/skin_provider.dart';
import 'providers/designs_provider.dart';
import 'providers/remote_access_provider.dart';
import 'router.dart';

class RadioKitApp extends StatefulWidget {
  const RadioKitApp({super.key});

  @override
  State<RadioKitApp> createState() => _RadioKitAppState();
}

class _RadioKitAppState extends State<RadioKitApp> {
  late final BleProvider _bleProvider;
  late final SerialProvider _serialProvider;
  late final DebugProvider _debugProvider;
  late final HistoryProvider _historyProvider;
  late final ConsoleProvider _consoleProvider;
  late final DeviceProvider _deviceProvider;
  late final SkinProvider _skinProvider;
  late final SettingsProvider _settingsProvider;
  late final DesignsProvider _designsProvider;
  late final RemoteAccessProvider _remoteAccessProvider;
  late final ConnectionNotifier _connectionNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _skinProvider = SkinProvider();
    _skinProvider.init(); // Restore persisted theme choice
    
    _settingsProvider = SettingsProvider();
    _designsProvider = DesignsProvider();
    _designsProvider.load();
    
    _bleProvider = BleProvider();
    _serialProvider = SerialProvider();
    _debugProvider = DebugProvider();
    _historyProvider = HistoryProvider();
    _consoleProvider = ConsoleProvider();

    _deviceProvider = DeviceProvider(
      transport: _bleProvider.bleService,
      debugSink: _debugProvider,
      console: _consoleProvider,
      skinProvider: _skinProvider,
    );

    _remoteAccessProvider = RemoteAccessProvider(
      settingsProvider: _settingsProvider,
      deviceProvider: _deviceProvider,
      bleProvider: _bleProvider,
      serialProvider: _serialProvider,
      historyProvider: _historyProvider,
      consoleProvider: _consoleProvider,
      designsProvider: _designsProvider,
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
        ChangeNotifierProvider<SkinProvider>.value(value: _skinProvider),
        ChangeNotifierProvider<BleProvider>.value(value: _bleProvider),
        ChangeNotifierProvider<SerialProvider>.value(value: _serialProvider),
        ChangeNotifierProvider<DebugProvider>.value(value: _debugProvider),
        ChangeNotifierProvider<HistoryProvider>.value(value: _historyProvider),
        ChangeNotifierProvider<ConsoleProvider>.value(value: _consoleProvider),
        ChangeNotifierProvider<DeviceProvider>.value(value: _deviceProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: _settingsProvider),
        ChangeNotifierProvider<DesignsProvider>.value(value: _designsProvider),
        ChangeNotifierProvider<RemoteAccessProvider>.value(
            value: _remoteAccessProvider),
      ],
      child: Consumer2<ThemeProvider, SkinProvider>(
        builder: (context, themeProvider, skinProvider, child) {
          return RKTheme(
            tokens: skinProvider.tokens,
            child: MaterialApp.router(
              title: 'RadioKit',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.themeMode,
              routerConfig: _router,
              builder: (context, child) {
                final settings = context.watch<SettingsProvider>();
                final scale = settings.interfaceScale.clamp(50, 200) / 100.0;
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    size: Size(mq.size.width / scale, mq.size.height / scale),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth / scale;
                      final h = constraints.maxHeight / scale;
                      return OverflowBox(
                        minWidth: w,
                        maxWidth: w,
                        minHeight: h,
                        maxHeight: h,
                        child: Transform.scale(
                          scale: scale,
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(
                                LogicalKeyboardKey.minus,
                                control: true,
                              ): () {
                                final s = context.read<SettingsProvider>();
                                s.setInterfaceScale(s.interfaceScale - 10);
                              },
                              const SingleActivator(
                                LogicalKeyboardKey.equal,
                                control: true,
                              ): () {
                                final s = context.read<SettingsProvider>();
                                s.setInterfaceScale(s.interfaceScale + 10);
                              },
                              const SingleActivator(
                                LogicalKeyboardKey.digit0,
                                control: true,
                              ): () {
                                context
                                    .read<SettingsProvider>()
                                    .setInterfaceScale(100);
                              },
                            },
                            child: Focus(
                              autofocus: true,
                              child: ConnectionListener(child: child!),
                            ),
                          ),
                        ),
                      );
                    },
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
