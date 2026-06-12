import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/providers/device_provider.dart';
import 'package:radiokit/models/device_info.dart';
import 'package:radiokit/services/transport_service.dart';

/// A programmable fake transport for testing transport switch ordering
/// and callback-clearing behavior.
///
/// Tracks connect/disconnect calls and fires onConnectionLost on disconnect
/// (unless the callback is cleared first), simulating real BLE/WebSocket
/// transport behavior.
class _FakeTransport implements TransportService {
  bool _connected = false;
  final String name;

  /// Whether onConnectionLost was called during disconnect.
  bool connectionLostFired = false;

  /// Whether connect() was called.
  bool connectCalled = false;

  /// Whether disconnect() was called.
  bool disconnectCalled = false;

  /// If true, connect() will throw an exception.
  bool failConnect = false;

  /// Connect hook — set by tests to inject ordering checks.
  Future<void> Function(String id, {int baudRate})? onConnect;

  /// Disconnect hook — set by tests to inject ordering checks.
  Future<void> Function()? onDisconnect;

  _FakeTransport(this.name);

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
    connectCalled = true;
    if (onConnect != null) {
      await onConnect!(deviceId, baudRate: baudRate);
      return;
    }
    if (failConnect) {
      throw Exception('$name connect failed');
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
    if (onDisconnect != null) {
      await onDisconnect!();
    }
    _connected = false;
    // Fire onConnectionLost only if callback is still set.
    // This simulates real BLE/WebSocket disconnect behavior.
    if (onConnectionLost != null && !connectionLostFired) {
      connectionLostFired = true;
      onConnectionLost!('$name disconnected');
    }
  }

  @override
  Future<void> writePacket(Uint8List data) async {}

  @override
  Future<int?> getRssi() async => null;

  @override
  Future<void> dispose() async {
    _connected = false;
  }

  void reset() {
    connectCalled = false;
    disconnectCalled = false;
    connectionLostFired = false;
    failConnect = false;
    onConnect = null;
    onDisconnect = null;
    _connected = false;
  }
}

void main() {
  group('transport switch ordering', () {
    test('target connects BEFORE source disconnects', () async {
      final src = _FakeTransport('Src');
      final tgt = _FakeTransport('Tgt');

      bool targetConnected = false;
      bool sourceDisconnected = false;

      tgt.onConnect = (id, {baudRate = 1000000}) async {
        targetConnected = true;
        tgt._connected = true;
        // Source should NOT be disconnected yet
        expect(sourceDisconnected, isFalse,
            reason: 'Target connects BEFORE source disconnects');
      };

      src.onDisconnect = () async {
        sourceDisconnected = true;
        src._connected = false;
        // Target should already be connected
        expect(targetConnected, isTrue,
            reason: 'Target connected before source disconnects');
      };

      // Simulate switchTransport: connect target, then disconnect source
      await tgt.connect('test-id');
      src.onConnectionLost = null;
      await src.disconnect();

      expect(targetConnected, isTrue);
      expect(sourceDisconnected, isTrue);
    });

    test('old transport onConnectionLost is cleared before disconnect', () async {
      final src = _FakeTransport('Src');
      final tgt = _FakeTransport('Tgt');

      // Connect target
      await tgt.connect('test-id');
      expect(tgt.isConnected, isTrue);

      // Clear source's callback (mimicking switchTransport logic)
      src.onConnectionLost = null;

      // Disconnect source — onConnectionLost should NOT fire
      await src.disconnect();

      expect(src.connectionLostFired, isFalse,
          reason: 'onConnectionLost was cleared before disconnect');
    });

    test('cleared onConnectionLost does not fire even when called on old transport',
        () async {
      final src = _FakeTransport('Src');
      final tgt = _FakeTransport('Tgt');

      // Create a provider and set up transports
      final p = DeviceProvider(transport: src);

      // setTransport in constructor assigns onConnectionLost
      expect(src.onConnectionLost, isNotNull,
          reason: 'setTransport assigns onConnectionLost');

      // Connect target
      await tgt.connect('test-id');

      // Clear source callback (as switchTransport does)
      src.onConnectionLost = null;

      // Swap transport on provider
      p.setTransport(tgt);

      // Disconnect source
      await src.disconnect();

      // Source callback was cleared — should not fire
      expect(src.connectionLostFired, isFalse,
          reason: 'Cleared onConnectionLost should not fire');
      expect(tgt.isConnected, isTrue,
          reason: 'Target transport stays connected');
    });

    test('disconnect after clearing callback does not affect provider state', () async {
      final src = _FakeTransport('Src');
      final tgt = _FakeTransport('Tgt');

      final p = DeviceProvider(transport: src);

      // Connect target
      await tgt.connect('test-id');

      // Clear and swap
      src.onConnectionLost = null;
      p.setTransport(tgt);

      // Disconnect source — should not trigger provider _handleConnectionLost
      await src.disconnect();

      // Provider should still have target transport (not disconnected by source)
      expect(identical(p.currentTransport, tgt), isTrue,
          reason: 'Provider transport should be target after swap');
    });
  });

  group('setTransport callback assignment', () {
    test('onConnectionLost is assigned by setTransport', () {
      final t = _FakeTransport('T');
      expect(t.onConnectionLost, isNull);

      DeviceProvider(transport: t);

      expect(t.onConnectionLost, isNotNull,
          reason: 'setTransport assigns onConnectionLost');
    });

    test('core callbacks are assigned by setTransport (fast path)', () {
      final t = _FakeTransport('T');
      DeviceProvider(transport: t);

      // When _transport is the same object, setTransport takes the fast path
      // which only assigns onPacketReceived and onConnectionLost.
      expect(t.onPacketReceived, isNotNull);
      expect(t.onConnectionLost, isNotNull);
    });

    test('all callbacks are assigned when transport differs', () {
      final t1 = _FakeTransport('T1');
      final t2 = _FakeTransport('T2');
      final p = DeviceProvider(transport: t1);

      // Switch to a different transport — this triggers the full path
      p.setTransport(t2);

      expect(t2.onPacketReceived, isNotNull);
      expect(t2.onFsPacketReceived, isNotNull);
      expect(t2.onOtaPacketReceived, isNotNull);
      expect(t2.onSettingsPacketReceived, isNotNull);
      expect(t2.onConnectionLost, isNotNull);
    });
  });

  group('transport switch error cases', () {
    test('returns false when no device is connected', () async {
      final t = _FakeTransport('T');
      final p = DeviceProvider(transport: t);

      // switchTransport checks _connectedDevice == null first
      final result = await p.switchTransport(TransportType.ble);
      expect(result, isFalse,
          reason: 'Should return false when _connectedDevice is null');
    });
  });
}
