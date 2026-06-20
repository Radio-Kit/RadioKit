---
name: radiokit-testing
description: Guide for writing and running tests across the RadioKit project. This skill should be used when adding unit tests, integration tests, or CI validation for the Flutter app (Dart), Arduino library (C++), or Rust relay server.
---

# RadioKit Testing

## Overview

This skill covers testing patterns, commands, and conventions for all three RadioKit components: the Flutter companion app, the Arduino C++ library, and the Rust relay server.

## Test Commands

### Flutter App

```bash
cd radiokit-app
flutter pub get                    # Fetch dependencies
flutter analyze --fatal-warnings   # Static analysis (CI enforces)
flutter test                       # Run all tests
flutter test test/my_test.dart     # Run specific test
```

### Arduino Library (PlatformIO)

```bash
# PlatformIO must be in a uv venv
uv venv .venv && source .venv/bin/activate && uv pip install platformio

cd rk-arduino/examples/<ExampleName>
pio run                     # Build only
pio run -t upload           # Build + flash to board
```

### Rust Relay

```bash
cd radiokit-relay
cargo build                 # Build
cargo test                  # Run tests
cargo run                   # Run locally
```

## Flutter Test Patterns

### Test File Location

Tests mirror the source structure under `radiokit-app/test/`:

| Source | Test |
|--------|------|
| `lib/services/device_fs_service.dart` | `test/device_fs_service_test.dart` |
| `lib/services/fs_protocol_service.dart` | `test/fs_protocol_service_test.dart` |
| `lib/providers/multi_device_provider.dart` | `test/multi_device_test.dart` |
| `lib/screens/home/models_tab.dart` | `test/dual_auth_test.dart` |
| `lib/screens/filesystem/fs_helpers.dart` | `test/fs_helpers_test.dart` |
| `lib/services/remote_access_service.dart` | `test/session_route_test.dart` |

### Testing Private Static Methods

Use `@visibleForTesting` from `package:flutter/foundation.dart`:

```dart
// In production code:
@visibleForTesting
static String? testOnlyFollowRoute(String path) => _followRoute(path);

// In test:
final result = RemoteAccessService.testOnlyFollowRoute('/api/widgets');
expect(result, '/control');
```

### Fake/Mock Transports

Create fake transports for unit tests:

```dart
class _FakeTransport implements TransportService {
  bool _connected = false;
  final _controller = StreamController<Uint8List>.broadcast();

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get onData => _controller.stream;

  @override
  Future<void> connect() async { _connected = true; }

  @override
  Future<void> disconnect() async { _connected = false; }

  @override
  Future<void> send(Uint8List data) async { /* no-op */ }

  // Helper for tests:
  void simulateReceive(Uint8List data) => _controller.add(data);
}
```

### Testing HTTP API Handlers

Use `shelf` and `shelf_router` directly in tests:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

test('GET /api/session/route', () async {
  final router = Router();
  router.get('/api/session/route', (request) async {
    return Response.ok(
      jsonEncode({'route': currentRoute}),
      headers: {'content-type': 'application/json'},
    );
  });

  final request = Request('GET', Uri.parse('http://test/api/session/route'));
  final response = await router(request);

  expect(response.statusCode, 200);
  final body = jsonDecode(await response.readAsString());
  expect(body['route'], '/control');
});
```

### Testing Filesystem Demo Mode

Use `DemoFsTransport` and `DemoFsState` for tests without hardware:

```dart
test('FS write and read', () async {
  final state = DemoFsState.seeded();
  // Write a file
  final writeResult = state.writeFile('/test.txt', [72, 101, 108]);
  expect(writeResult.result.code, 0);

  // Read it back
  final readResult = state.readFile('/test.txt', 0, 100);
  expect(readResult.result.code, 0);
  expect(readResult.data, [72, 101, 108]);
});
```

### Testing Follow Mode Route Mapping

```dart
test('follow route maps /api/fs/ to filesystem screen', () {
  final route = RemoteAccessService.testOnlyFollowRoute('/api/fs/read');
  expect(route, '/dev-tools/esp32-fs');
});

test('follow route maps /api/widgets to control screen', () {
  final route = RemoteAccessService.testOnlyFollowRoute('/api/widgets');
  expect(route, '/control');
});

test('follow route handles parameterized paths', () {
  final route = RemoteAccessService.testOnlyFollowRoute('/api/widgets/abc123');
  expect(route, '/control');
});
```

### Testing Multi-Device Provider

```dart
test('connect adds device to active list', () {
  final provider = MultiDeviceProvider();
  final transport = _FakeTransport();
  provider.connect(transport, deviceInfo);
  expect(provider.activeDevices.length, 1);
});
```

## CI Workflows

| Workflow | Trigger | What it runs |
|----------|---------|--------------|
| `flutter-ci.yml` | Every push | `flutter analyze` + `flutter test` |
| `pioarduino-ci.yml` | Every push | Builds all PlatformIO examples |
| `relay-ci.yml` | Every push | `cargo build` + `cargo test` |
| `release-android.yml` | `v*` tag | Android APK build |
| `release-ios.yml` | `v*` tag | iOS IPA build |
| `release-linux-flatpak.yml` | `*-flatpak` tag | Flatpak build |
| `release-windows.yml` | `v*` tag | Windows build |
| `release-macos.yml` | `v*` tag | macOS build |

## Key Testing Rules

1. **Run `flutter analyze --fatal-warnings` before pushing** — CI enforces zero warnings
2. **Run `flutter test` to verify** — all tests must pass
3. **Use `@visibleForTesting`** for exposing private methods in tests
4. **Never depend on hardware** in unit tests — use fakes and demo transports
5. **Test both success and error paths** — especially auth, FS errors, and transport disconnects
6. **Test route mapping edge cases** — bare paths vs parameterized paths
7. **Clean up timers and streams** in test `tearDown()` to avoid test pollution
