/// Native serial service dispatcher.
///
/// `dart.library.io` is true on Android, iOS, and all desktop platforms, so we
/// cannot use a compile-time conditional export. Instead this file performs a
/// runtime check via [defaultTargetPlatform] and forwards every call to the
/// correct concrete implementation.
///
/// [FlserialSerialService] (flserial native FFI) is used on all platforms
/// except iOS (no USB serial access). Port IDs use the `usb:/dev/bus/usb/...`
/// format — identical to the flasher, making auto-handoff a trivial ID match.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import 'transport_service.dart';
export 'transport_service.dart';

// flserial (native FFI via termios/Win32) — single backend for all platforms
import 'serial_service_flserial.dart' as fls;

/// The platform-dispatched [SerialService] that providers interact with.
///
/// Uses [fls.FlserialSerialService] on all platforms except iOS (no USB serial
/// access). Port IDs are always `usb:/dev/bus/usb/...` — matching the flasher.
class SerialService implements TransportService {
  late final TransportService _impl;

  SerialService() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _impl = _UnsupportedSerialService();
    } else {
      _impl = fls.FlserialSerialService();
    }
  }

  /// Whether USB Serial is supported on the current platform.
  /// iOS is the only unsupported native platform (no USB serial access).
  bool get isSupported =>
      defaultTargetPlatform != TargetPlatform.iOS;

  // Delegate everything to _impl

  @override
  PacketReceivedCallback? get onPacketReceived => _impl.onPacketReceived;
  @override
  set onPacketReceived(PacketReceivedCallback? v) => _impl.onPacketReceived = v;

  @override
  FsPacketReceivedCallback? get onFsPacketReceived => _impl.onFsPacketReceived;
  @override
  set onFsPacketReceived(FsPacketReceivedCallback? v) =>
      _impl.onFsPacketReceived = v;

  @override
  OtaPacketReceivedCallback? get onOtaPacketReceived => _impl.onOtaPacketReceived;
  @override
  set onOtaPacketReceived(OtaPacketReceivedCallback? v) =>
      _impl.onOtaPacketReceived = v;

  @override
  SettingsPacketReceivedCallback? get onSettingsPacketReceived =>
      _impl.onSettingsPacketReceived;
  @override
  set onSettingsPacketReceived(SettingsPacketReceivedCallback? v) =>
      _impl.onSettingsPacketReceived = v;

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
    if (impl is fls.FlserialSerialService) return impl.listPorts();
    return const Stream.empty();
  }

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) =>
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
  @override FsPacketReceivedCallback? onFsPacketReceived;
  @override OtaPacketReceivedCallback? onOtaPacketReceived;
  @override SettingsPacketReceivedCallback? onSettingsPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;
  @override bool get isConnected => false;
  @override Stream<String> get logStream => const Stream.empty();

  @override
  Future<void> connect(String _, {int baudRate = 1000000}) async =>
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
