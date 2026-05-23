import 'dart:async';
import 'dart:typed_data';
import '../models/device_info.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Unsupported-platform stub for [SerialService].
class SerialService implements TransportService {
  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  @override bool get isConnected => false;
  bool get isSupported => false;

  Stream<DeviceInfo> listPorts() =>
      throw UnsupportedError('Serial not supported on this platform');

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) =>
      throw UnsupportedError('Serial not supported on this platform');

  @override
  Future<void> disconnect() =>
      throw UnsupportedError('Serial not supported on this platform');

  @override
  Future<void> writePacket(Uint8List data) =>
      throw UnsupportedError('Serial not supported on this platform');

  @override
  Future<void> dispose() => disconnect();

  @override
  Future<int?> getRssi() async => null;

  @override
  Stream<String> get logStream => const Stream.empty();
}
