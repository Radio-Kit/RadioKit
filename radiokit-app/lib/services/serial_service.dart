/// Platform-conditional Serial service export.
///
/// On web (dart.library.js_interop available) → serial_service_web.dart
/// On native (Android/iOS/desktop)            → serial_service_native.dart
/// Unsupported platform                       → serial_service_stub.dart
library;
export 'serial_service_stub.dart'
    if (dart.library.js_interop) 'serial_service_web.dart'
    if (dart.library.io) 'serial_service_native.dart';
