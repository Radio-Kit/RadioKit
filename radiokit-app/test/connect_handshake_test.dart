import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/models/device_info.dart';
import 'package:radiokit/models/protocol.dart';
import 'package:radiokit/providers/device_provider.dart';
import 'package:radiokit/services/protocol_service.dart';
import 'package:radiokit/services/transport_service.dart';

/// Minimal in-memory transport that can simulate the firmware's proactive
/// CONF_DATA push (BLE subscribe) and/or answer GET_CONF requests.
class _FakeTransport implements TransportService {
  final List<Uint8List> writtenPackets = [];
  bool connected = false;

  /// When true, injects CONF_DATA right after connect() (like a BLE
  /// onSubscribe push).
  final bool pushOnConnect;

  /// When true, answers a GET_CONF write with CONF_DATA.
  final bool answerGetConf;

  _FakeTransport({this.pushOnConnect = false, this.answerGetConf = true});

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

  @override
  bool get isConnected => connected;

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    connected = true;
    if (pushOnConnect) {
      onPacketReceived?.call(_confDataPacket());
    }
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> writePacket(Uint8List data) async {
    writtenPackets.add(data);
    if (answerGetConf && data.length >= 4 && data[3] == kCmdGetConf) {
      onPacketReceived?.call(_confDataPacket());
    }
  }

  static ParsedPacket _confDataPacket() => ParsedPacket(
        // v4 CONF_DATA: orientation=0, 0 widgets, empty theme.
        cmd: kCmdConfData,
        payload: Uint8List.fromList([0, 0, 0, 0, 0, 0]),
      );

  @override
  Future<void> dispose() async {
    connected = false;
  }

  @override
  Future<int?> getRssi() async => -50;

  bool sentCommand(int cmd) =>
      writtenPackets.any((p) => p.length >= 4 && p[3] == cmd);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DeviceInfo bleDevice() => DeviceInfo(
        id: 'test-ble',
        name: 'Test BLE',
        rssi: -50,
        currentTransport: TransportType.ble,
        transportAddress: 'AA:BB:CC:DD:EE:FF',
        bleAddress: 'AA:BB:CC:DD:EE:FF',
      );

  DeviceInfo serialDevice() => DeviceInfo(
        id: 'test-serial',
        name: 'Test Serial',
        rssi: -50,
        currentTransport: TransportType.serial,
        transportAddress: '/dev/ttyACM0',
      );

  group('connectToDevice config handshake', () {
    test('BLE with push-capable firmware acquires config without GET_CONF',
        () async {
      final transport =
          _FakeTransport(pushOnConnect: true, answerGetConf: false);
      final dp = DeviceProvider(transport: transport);
      addTearDown(dp.dispose);

      await dp.connectToDevice(bleDevice());

      expect(dp.connectionState, DeviceConnectionState.connected);
      expect(transport.sentCommand(kCmdGetConf), isFalse,
          reason: 'push-capable firmware must not need a GET_CONF request');
    });

    test('BLE without push falls back to GET_CONF after the wait window',
        () async {
      final transport =
          _FakeTransport(pushOnConnect: false, answerGetConf: true);
      final dp = DeviceProvider(transport: transport);
      addTearDown(dp.dispose);

      await dp.connectToDevice(bleDevice());

      expect(dp.connectionState, DeviceConnectionState.connected);
      expect(transport.sentCommand(kCmdGetConf), isTrue,
          reason: 'fallback GET_CONF must be sent when the push does not arrive');
    });

    test('non-BLE transport requests config immediately (no push wait)',
        () async {
      final transport =
          _FakeTransport(pushOnConnect: false, answerGetConf: true);
      final dp = DeviceProvider(transport: transport);
      addTearDown(dp.dispose);

      final sw = Stopwatch()..start();
      await dp.connectToDevice(serialDevice());
      sw.stop();

      expect(dp.connectionState, DeviceConnectionState.connected);
      expect(transport.sentCommand(kCmdGetConf), isTrue);
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'non-BLE must not wait the push window');
    });

    test('BLE push arriving during connect() still completes the handshake',
        () async {
      // The push is delivered while transport.connect() is awaiting (subscribe
      // is the last BLE step); _requestConfig must short-circuit on the
      // already-received config instead of timing out and re-requesting.
      final transport =
          _FakeTransport(pushOnConnect: true, answerGetConf: true);
      final dp = DeviceProvider(transport: transport);
      addTearDown(dp.dispose);

      final sw = Stopwatch()..start();
      await dp.connectToDevice(bleDevice());
      sw.stop();

      expect(dp.connectionState, DeviceConnectionState.connected);
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'push arriving during connect must skip the 3s push window');
      expect(transport.sentCommand(kCmdGetConf), isFalse);
    });
  });
}
