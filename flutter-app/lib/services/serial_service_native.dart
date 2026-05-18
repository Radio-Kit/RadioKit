/// Native serial service dispatcher.
///
/// `dart.library.io` is true on BOTH Android and iOS, so we cannot use a
/// compile-time conditional export to pick between the Android usb_serial
/// implementation and the iOS stub.  Instead this file performs a runtime
/// check via [defaultTargetPlatform] and forwards every call to the correct
/// concrete implementation.
///
/// File routing:
///   Android → [_AndroidSerialService] (serial_service_android.dart)
///   iOS / macOS / Linux / Windows → [_StubSerialService] (stub)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import 'transport_service.dart';
export 'transport_service.dart';

// Conditionally import the Android implementation only on Android.
// This avoids pulling usb_serial into the iOS/desktop build graph.
import 'serial_service_android.dart'
    if (dart.library.js_interop) 'serial_service_stub.dart'
    as android;

/// The platform-dispatched [SerialService] that providers interact with.
///
/// On Android it wraps [android.SerialService].
/// On all other native platforms it returns [isSupported] = false.
class SerialService implements TransportService {
  late final TransportService _impl;

  SerialService() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _impl = android.SerialService();
    } else {
      _impl = _UnsupportedSerialService();
    }
  }

  /// Whether USB Serial is supported on the current platform.
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  // Delegate everything to _impl

  @override
  PacketReceivedCallback? get onPacketReceived => _impl.onPacketReceived;
  @override
  set onPacketReceived(PacketReceivedCallback? v) => _impl.onPacketReceived = v;

  @override
  ConnectionLostCallback? get onConnectionLost => _impl.onConnectionLost;
  @override
  set onConnectionLost(ConnectionLostCallback? v) => _impl.onConnectionLost = v;

  @override
  bool get isConnected => _impl.isConnected;

  @override
  Stream<String> get logStream => _impl.logStream;

  /// List available serial ports. Returns an empty stream on unsupported platforms.
  Stream<DeviceInfo> listPorts() {
    final impl = _impl;
    if (impl is android.SerialService) return impl.listPorts();
    return const Stream.empty();
  }

  @override
  Future<void> connect(String deviceId, {int baudRate = 115200}) =>
      _impl.connect(deviceId, baudRate: baudRate);

  @override
  Future<void> disconnect() => _impl.disconnect();

  @override
  Future<void> writePacket(Uint8List data) => _impl.writePacket(data);

  @override
  Future<void> dispose() => _impl.dispose();

  @override
  Future<int?> getRssi() => _impl.getRssi();
}

/// Returned on iOS / desktop where USB Serial is not supported.
class _UnsupportedSerialService implements TransportService {
  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;
  @override bool get isConnected => false;
  @override Stream<String> get logStream => const Stream.empty();

  @override
  Future<void> connect(String _, {int baudRate = 115200}) async =>
      throw UnsupportedError('USB Serial is not supported on ${defaultTargetPlatform.name}');

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> writePacket(Uint8List _) async =>
      throw UnsupportedError('USB Serial is not supported on ${defaultTargetPlatform.name}');

  @override
  Future<void> dispose() async {}

  @override
  Future<int?> getRssi() async => null;
}
