import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/providers/multi_device_provider.dart';
import 'package:radiokit/providers/device_provider.dart';
import 'package:radiokit/services/transport_service.dart';

/// Minimal fake transport for unit tests.
class _FakeTransport implements TransportService {
  bool _connected = false;

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
  bool get isConnected => _connected;
  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    _connected = true;
  }
  @override
  Future<void> disconnect() async {
    _connected = false;
  }
  @override
  Future<void> writePacket(List<int> data) async {}
  @override
  Future<int?> getRssi() async => null;
  @override
  Future<void> dispose() async {
    _connected = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // NOTE: We test MultiDeviceProvider's collection management by using
  // connectDemo() which loads from assets (available in test). We avoid
  // connectDevice() which triggers protocol handshakes that hang without
  // real BLE hardware.

  group('MultiDeviceProvider starts empty', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('has no devices initially', () {
      expect(provider.deviceCount, 0);
      expect(provider.devices, isEmpty);
      expect(provider.deviceIds, isEmpty);
      expect(provider.primaryDevice, isNull);
      expect(provider.hasConnectedDevices, isFalse);
    });
  });

  group('MultiDeviceProvider connectDemo', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('creates a demo device provider', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');

      expect(dp, isNotNull);
      expect(provider.deviceCount, 1);
      expect(provider.deviceIds, contains('DEMO_WIDGETS_DEMO'));
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), dp);
    });

    test('returns existing provider for same demoId (no duplicates)', () async {
      final dp1 = await provider.connectDemo('WIDGETS_DEMO');
      final dp2 = await provider.connectDemo('WIDGETS_DEMO');

      expect(identical(dp1, dp2), isTrue,
          reason: 'Should return existing provider for same demo');
      expect(provider.deviceCount, 1);
    });

    test('can load different demos simultaneously', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      await provider.connectDemo('RC_CONTROLLER');

      expect(provider.deviceCount, 2);
      expect(provider.deviceIds, contains('DEMO_WIDGETS_DEMO'));
      expect(provider.deviceIds, contains('DEMO_RC_CONTROLLER'));
    });
  });

  group('MultiDeviceProvider focus', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('focusedDevice is null initially', () {
      expect(provider.focusedDevice, isNull);
      expect(provider.focusedDeviceId, isNull);
    });

    test('setFocusedDevice sets the active device', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      await provider.connectDemo('RC_CONTROLLER');

      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');
      expect(provider.focusedDeviceId, 'DEMO_WIDGETS_DEMO');
      expect(provider.focusedDevice, provider.getDevice('DEMO_WIDGETS_DEMO'));
    });

    test('setFocusedDevice(null) clears focus', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');
      provider.setFocusedDevice(null);

      expect(provider.focusedDevice, isNull);
    });

    test('setFocusedDevice is idempotent', () async {
      await provider.connectDemo('WIDGETS_DEMO');

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');
      final countAfterFirst = notifyCount;

      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');
      expect(notifyCount, countAfterFirst);
    });

    test('primaryDevice returns focused device when set', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      await provider.connectDemo('RC_CONTROLLER');

      provider.setFocusedDevice('DEMO_RC_CONTROLLER');
      expect(provider.primaryDevice, provider.getDevice('DEMO_RC_CONTROLLER'));
    });

    test('primaryDevice returns first device when no focus', () async {
      final dp1 = await provider.connectDemo('WIDGETS_DEMO');
      await provider.connectDemo('RC_CONTROLLER');

      expect(provider.primaryDevice, dp1);
    });
  });

  group('MultiDeviceProvider disconnect', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('disconnectDevice removes demo from collection', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      expect(provider.deviceCount, 1);

      await provider.disconnectDevice('DEMO_WIDGETS_DEMO');
      expect(provider.deviceCount, 0);
      expect(provider.devices, isEmpty);
    });

    test('disconnectDevice clears focus if focused device is disconnected',
        () async {
      await provider.connectDemo('WIDGETS_DEMO');
      await provider.connectDemo('RC_CONTROLLER');

      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');
      await provider.disconnectDevice('DEMO_WIDGETS_DEMO');
      expect(provider.focusedDeviceId, isNull);
    });

    test('disconnectAll removes all devices', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      await provider.connectDemo('RC_CONTROLLER');
      expect(provider.deviceCount, 2);

      await provider.disconnectAll();
      expect(provider.deviceCount, 0);
    });

    test('disconnectDevice on nonexistent ID is no-op', () async {
      await provider.disconnectDevice('nonexistent');
      expect(provider.deviceCount, 0);
    });
  });

  group('MultiDeviceProvider collection queries', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('getDevice returns correct provider', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), dp);
      expect(provider.getDevice('nonexistent'), isNull);
    });

    test('isDeviceConnected returns false for nonexistent device', () async {
      await provider.connectDemo('WIDGETS_DEMO');
      expect(provider.isDeviceConnected('nonexistent'), isFalse);
      expect(provider.isDeviceConnected('DEMO_WIDGETS_DEMO'), isTrue);
    });
  });

  group('MultiDeviceProvider notifications', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('notifies listeners on connectDemo', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.connectDemo('WIDGETS_DEMO');
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('notifies listeners on disconnectDevice', () async {
      await provider.connectDemo('WIDGETS_DEMO');

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.disconnectDevice('DEMO_WIDGETS_DEMO');
      expect(notifyCount, greaterThanOrEqualTo(1));
    });

    test('notifies listeners on setFocusedDevice', () async {
      await provider.connectDemo('WIDGETS_DEMO');

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');
      expect(notifyCount, 1);
    });
  });

  group('getActiveDevice lambda safety', () {
    test('empty device list returns fallback without throwing', () {
      final provider = MultiDeviceProvider();

      DeviceProvider? result;
      try {
        result = provider.primaryDevice ??
            (provider.devices.isNotEmpty ? provider.devices.first : null);
      } catch (e) {
        fail('Lambda should not throw: $e');
      }

      expect(result, isNull,
          reason: 'Lambda returns null on empty list (idle provider handles this)');
    });
  });
}
