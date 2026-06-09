import 'dart:typed_data';
import 'transport_service.dart';

class DemoTransport implements TransportService {
  @override
  PacketReceivedCallback? onPacketReceived;
  @override
  FsPacketReceivedCallback? onFsPacketReceived;
  @override
  OtaPacketReceivedCallback? onOtaPacketReceived;
  @override
  SettingsPacketReceivedCallback? onSettingsPacketReceived;

  @override
  ConnectionLostCallback? onConnectionLost;

  @override
  Stream<String> get logStream => const Stream.empty();

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    onConnectionLost?.call('Demo disconnected');
  }

  @override
  Future<void> writePacket(Uint8List data) async {
    // Demo transport simply ignores writes or loops them back?
    // Bouncing writes logic is usually handled by real hardware. Here we do nothing, Provider updates inputs immediately anyway.
  }

  @override
  Future<void> dispose() async {
    _connected = false;
  }

  @override
  Future<int?> getRssi() async => -55;
}
