---
name: radiokit-flutter
description: Guide for developing features in the RadioKit Flutter companion app. This skill should be used when adding screens, providers, services, or modifying the app architecture in radiokit-app/. Covers Provider state management, GoRouter routing, M3 UI patterns, and project conventions.
---

# RadioKit Flutter App Development

## Overview

This skill covers conventions and patterns for the RadioKit Flutter companion app. The app uses Provider for state management, GoRouter for navigation, Material 3 for UI, and a transport abstraction for device communication.

## Project Structure

```
radiokit-app/lib/
  main.dart              # Entry point
  app.dart               # MaterialApp.router + FollowModeWrapper
  router.dart            # GoRouter route definitions
  models/                # Data classes (DeviceInfo, WidgetConfig, etc.)
  providers/             # ChangeNotifier state management
  services/              # Transport, protocol, FS, auth services
  screens/               # UI screens organized by feature
  theme/                 # App theme definitions
  widgets/               # Shared UI components
  gen/                   # Generated code (flutter_gen)
```

## State Management: Provider Pattern

### Provider Creation

All providers extend `ChangeNotifier`:

```dart
class MyProvider extends ChangeNotifier {
  String _value = '';
  String get value => _value;

  void update(String newValue) {
    _value = newValue;
    notifyListeners();  // ALWAYS call after mutation
  }
}
```

### Provider Registration

Providers are registered in `app.dart` via `MultiProvider`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => DeviceProvider()),
    ChangeNotifierProvider(create: (_) => MultiDeviceProvider()),
    // ... other providers
  ],
  child: MyApp(...),
)
```

### Provider Access

```dart
// In build context:
final deviceProvider = context.watch<DeviceProvider>();
final deviceProvider = context.read<DeviceProvider>();  // no rebuild
```

## Current Providers

| Provider | Purpose |
|----------|---------|
| `DeviceProvider` | Active device connection, auth, widget state |
| `MultiDeviceProvider` | Manages multiple simultaneous device connections |
| `RemoteAccessProvider` | HTTP API server for remote control |
| `CloudIdentityProvider` | Ed25519 keypair for cloud relay auth |
| `AccountProvider` | Cloud account management |
| `BleProvider` | BLE scanning state |
| `SerialProvider` | Serial port discovery |
| `MdnsProvider` | mDNS device discovery |
| `DesignsProvider` | Saved designer configurations |
| `HistoryProvider` | Connection history |
| `FlasherProvider` | OTA firmware flashing |
| `DebugProvider` | Debug log collection |
| `ConsoleProvider` | Console output |
| `ThemePresetProvider` | UI theme presets |
| `SettingsProvider` | App settings |

## Routing: GoRouter

Routes are defined in `router.dart`:

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => HomeScreen()),
    GoRoute(path: '/scan', builder: (ctx, state) => ScanScreen()),
    GoRoute(path: '/control', builder: (ctx, state) => ControlScreen()),
    GoRoute(path: '/designs', builder: (ctx, state) => DesignerScreen()),
    GoRoute(path: '/dev-tools/esp32-fs', builder: (ctx, state) => FilesystemExplorerScreen()),
    // ...
  ],
);
```

### Route Conventions

- `/` — Home screen (models, pair, system tabs)
- `/scan` — BLE/serial scan
- `/control` — Active device control UI
- `/designs` — Visual designer
- `/dev-tools/esp32-fs` — Filesystem explorer
- `/debug` — Debug/log screen
- `/system` — System settings
- `/pair` — Device pairing
- `/donate` — Donation screen

## Screen Patterns

### StatefulWidget Pattern

```dart
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize, register listeners
  }

  @override
  void dispose() {
    // Clean up listeners
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: Consumer<MyProvider>(
        builder: (context, provider, child) {
          return ListView(/* ... */);
        },
      ),
    );
  }
}
```

## M3 UI Rules

- Use `Theme.of(context).colorScheme` for colors (not hardcoded)
- Use `Card`, `ListTile`, `FloatingActionButton` from Material 3
- Use `showModalBottomSheet(showDragHandle: true)` for action sheets
- Use `AlertDialog` with `icon:` for confirmations
- Use `LinearProgressIndicator` for progress (not custom bars)
- Use `ActionChip` for breadcrumbs
- Use `FilledButton.tonal` for destructive actions with `scheme.errorContainer`

## Filesystem Explorer Conventions

The filesystem explorer (`lib/screens/filesystem/`) follows strict M3 patterns:

- All file operations go through `DeviceFsService` (never call `DeviceProvider.sendFs()` directly)
- Path utilities live in `fs_helpers.dart` (`joinPath`, `parentPath`, `baseName`, `pathSegments`)
- Multi-select via long-press with `Set<String> _selectedPaths`
- Pull-to-refresh with `RefreshIndicator`
- Speed indicator in `FsInfoStrip` card header

## Testing

```bash
cd radiokit-app
flutter pub get
flutter analyze --fatal-warnings
flutter test
```

### Test File Naming

Tests mirror source structure:
- `lib/services/device_fs_service.dart` → `test/device_fs_service_test.dart`
- `lib/screens/home/models_tab.dart` → `test/multi_device_test.dart`

### Key Test Patterns

- Use `@visibleForTesting` to expose private methods for testing
- Use `FakeTransport` implements `TransportService` for unit tests
- Use `DemoFsTransport` for filesystem tests without hardware
- Use `shelf_router` for testing HTTP API handlers

## Important Conventions

1. **Docs-Sync**: Update `.mdx` docs in `website/src/content/docs/` when changing APIs
2. **No emojis** in documentation files
3. **Don't break backward compatibility** unless explicitly asked
4. **`flserial` has a git override** — do not remove from `pubspec.yaml` dependency_overrides
5. **Monorepo**: `radiokit-widgets` is a path dependency from `flutter-widgets/`
