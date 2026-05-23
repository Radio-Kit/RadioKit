/// Platform-conditional Raw Serial Service export.
///
/// On native (dart.library.io available)   → raw_serial_service_native.dart
/// On web (dart.library.js_interop)         → raw_serial_service_web.dart
/// Otherwise                                 → raw_serial_service_stub.dart
library;
export 'raw_serial_service_stub.dart'
    if (dart.library.io) 'raw_serial_service_native.dart'
    if (dart.library.js_interop) 'raw_serial_service_web.dart';
