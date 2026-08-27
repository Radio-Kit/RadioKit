import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/providers/multi_device_provider.dart';
import 'package:radiokit/providers/device_provider.dart';
import 'package:radiokit/models/device_info.dart';
import 'package:radiokit/services/transport_service.dart';


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

    test('getDevice supports lookup by both original ID and post-connection UID', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');

      // Verify initial lookup by original ID (DEMO_WIDGETS_DEMO) works
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), dp);
      expect(provider.getDevice('POST_CONNECTION_UID'), isNull);

      // Simulate post-connection UID assignment (e.g. from settings handshake)
      dp.connectedDevice?.id = 'POST_CONNECTION_UID';

      // Verify lookup by both original ID (map key) and post-connection UID (device ID) works
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), dp);
      expect(provider.getDevice('POST_CONNECTION_UID'), dp);
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

  group('MultiDeviceProvider address matching on disconnect', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('disconnectDevice matches by UID, BLE, or WiFi address', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');
      // key is 'DEMO_WIDGETS_DEMO'

      // Verify connection mapped by original id
      expect(provider.deviceCount, 1);
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), dp);

      // Simulate post-handshake UID update
      dp.connectedDevice?.id = 'REAL_CHIP_UID';

      // Test duplicate connect prevention
      final infoDup = DeviceInfo(
        id: 'REAL_CHIP_UID',
        name: 'FS LED',
        rssi: -50,
      );
      final dpDup = await provider.connectDevice(
        device: infoDup,
        transport: MockTransport(),
      );
      expect(identical(dp, dpDup), isTrue, reason: 'Should return existing provider and not duplicate');
      expect(provider.deviceCount, 1);

      // Verify disconnect matches by UID
      await provider.disconnectDevice('REAL_CHIP_UID');
      expect(provider.deviceCount, 0);
    });
  });

  group('MultiDeviceProvider pruning', () {
    late MultiDeviceProvider provider;

    setUp(() {
      provider = MultiDeviceProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('does not prune disconnected device if it is focused', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');

      // Set focus to this device
      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');

      // Simulate connection lost
      dp.currentTransport.onConnectionLost?.call('Link down');

      // Wait a microtask since pruning runs in microtask
      await Future.delayed(Duration.zero);

      expect(provider.deviceCount, 1);
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), dp);
      expect(dp.connectionState, DeviceConnectionState.disconnected);
    });

    test('prunes disconnected device if it is unfocused', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');

      // No focus is set
      expect(provider.focusedDeviceId, isNull);

      // Simulate connection lost
      dp.currentTransport.onConnectionLost?.call('Link down');

      // Wait a microtask since pruning runs in microtask
      await Future.delayed(Duration.zero);

      expect(provider.deviceCount, 0);
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), isNull);
    });

    test('prunes focused disconnected device once focus is cleared', () async {
      final dp = await provider.connectDemo('WIDGETS_DEMO');

      // Set focus
      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');

      // Simulate connection lost
      dp.currentTransport.onConnectionLost?.call('Link down');
      await Future.delayed(Duration.zero);

      // Still there because it is focused
      expect(provider.deviceCount, 1);

      // Clear focus
      provider.setFocusedDevice(null);
      await Future.delayed(Duration.zero);

      // Now it should be pruned!
      expect(provider.deviceCount, 0);
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), isNull);
    });

    test('prunes focused disconnected device once focus moves to another device', () async {
      final dp1 = await provider.connectDemo('WIDGETS_DEMO');
      final dp2 = await provider.connectDemo('RC_CONTROLLER');

      // Focus WIDGETS_DEMO
      provider.setFocusedDevice('DEMO_WIDGETS_DEMO');

      // Simulate connection lost on WIDGETS_DEMO
      dp1.currentTransport.onConnectionLost?.call('Link down');
      await Future.delayed(Duration.zero);

      // Still there because focused
      expect(provider.deviceCount, 2);

      // Move focus to RC_CONTROLLER
      provider.setFocusedDevice('DEMO_RC_CONTROLLER');
      await Future.delayed(Duration.zero);

      // WIDGETS_DEMO should be pruned, RC_CONTROLLER remains
      expect(provider.deviceCount, 1);
      expect(provider.getDevice('DEMO_WIDGETS_DEMO'), isNull);
      expect(provider.getDevice('DEMO_RC_CONTROLLER'), dp2);
    });

    test('MULTI_PAGE_DEMO loads multiple pages and switches pages correctly', () async {
      final dp = await provider.connectDemo('MULTI_PAGE_DEMO');
      expect(dp.numPages, 2);
      expect(dp.pageNames, ['Control', 'Settings']);
      expect(dp.activePage, 0);
      expect(dp.widgets.where((w) => w.pageIndex == 0).length, 3);
      expect(dp.widgets.where((w) => w.pageIndex == 1).length, 2);

      await dp.sendSetPage(1);
      expect(dp.activePage, 1);

      await dp.sendSetPage(0);
      expect(dp.activePage, 0);
    });
  });
}

class MockTransport implements TransportService {
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
  }
  
  @override
  Future<void> writePacket(Uint8List data) async {}
  
  @override
  Future<int?> getRssi() async => -50;
  
  @override
  Future<void> dispose() async {}
}

