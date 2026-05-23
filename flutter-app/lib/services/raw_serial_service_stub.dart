import 'dart:async';
import 'dart:typed_data';
import '../models/device_info.dart';

/// Stub implementation for platforms without serial support (iOS, desktop).
class RawSerialService {
  bool get isSupported => false;

  Stream<DeviceInfo> listPorts() => const Stream.empty();

  Future<void> connect(
    String portId, {
    int baudRate = 115200,
    int dataBits = 8,
    int stopBits = 1,
    String parity = 'none',
  }) async {
    throw UnsupportedError('Raw serial not supported on this platform');
  }

  Future<void> disconnect() async {}

  Future<void> write(List<int> data) async {
    throw UnsupportedError('Raw serial not supported on this platform');
  }

  Stream<List<int>> get dataStream => const Stream.empty();

  bool get isConnected => false;

  void dispose() {}
}
