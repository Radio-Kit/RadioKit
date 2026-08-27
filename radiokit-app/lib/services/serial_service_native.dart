/// Native serial service dispatcher.
///
/// `dart.library.io` is true on Android, iOS, and all desktop platforms, so we
/// cannot use a compile-time conditional export. Instead this file performs a
/// runtime check via [defaultTargetPlatform] and forwards every call to the
/// correct concrete implementation.
///
/// On **Android**: uses [RawUsbSerialService] (custom Kotlin plugin with
/// STALL recovery for ESP32-S3 USB Serial/JTAG compatibility).
///
/// On **Linux/macOS/Windows**: uses [FlserialSerialService] (native FFI
/// via termios/Win32).
///
/// On **iOS**: USB serial is not supported.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import 'transport_service.dart';
export 'transport_service.dart';

// flserial (native FFI via termios/Win32) — desktop platforms
import 'serial_service_flserial.dart' as fls;

// flutter_serial_communication (usb-serial-for-android) — Android
import 'serial_service_fsc.dart' as fsc;

// Raw USB (custom Kotlin plugin) — Android bypass for STALL issues
import 'serial_service_raw_usb.dart' as raw;

/// The platform-dispatched [SerialService] that providers interact with.
///
/// Uses [raw.RawUsbSerialService] on Android (custom Kotlin plugin with
/// STALL recovery for ESP32-S3 USB Serial/JTAG compatibility).
/// Uses [fls.FlserialSerialService] on Linux/macOS/Windows (native FFI).
/// Returns [_UnsupportedSerialService] on iOS.
///
/// Port IDs are always `usb:/dev/bus/usb/...` — matching the flasher.
class SerialService implements TransportService {
  late final TransportService _impl;

  SerialService() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _impl = _UnsupportedSerialService();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      _impl = raw.RawUsbSerialService();
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
    if (impl is raw.RawUsbSerialService) return impl.listPorts();
    if (impl is fsc.FlutterSerialCommunicationService) return impl.listPorts();
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
