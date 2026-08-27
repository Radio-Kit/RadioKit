import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/models/device_info.dart';
import 'package:radiokit/providers/history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('HistoryProvider deduplicates entries on save with same BLE address', () async {
    final history = HistoryProvider();

    final dev1 = DeviceInfo(
      id: 'uid_flash_1',
      name: 'RC_UI',
      rssi: -60,
      bleAddress: 'AC:27:6E:AE:FA:69',
      transportAddress: 'AC:27:6E:AE:FA:69',
      currentTransport: TransportType.ble,
    );

    await history.saveDevice(dev1, 'ble', configName: 'RC_UI');
    expect(history.pairedDevices.length, equals(1));
    expect(history.pairedDevices.first.uid, equals('uid_flash_1'));

    // After reflash with new UID but same BLE MAC
    final dev2 = DeviceInfo(
      id: 'uid_flash_2',
      name: 'RC_UI',
      rssi: -60,
      bleAddress: 'AC:27:6E:AE:FA:69',
      transportAddress: 'AC:27:6E:AE:FA:69',
      currentTransport: TransportType.ble,
    );

    await history.saveDevice(dev2, 'ble', configName: 'RC_UI');
    expect(history.pairedDevices.length, equals(1));
    expect(history.pairedDevices.first.uid, equals('uid_flash_2'));
    expect(history.pairedDevices.first.bleAddress, equals('AC:27:6E:AE:FA:69'));
  });

  test('HistoryProvider merges multiple transport addresses for same device', () async {
    final history = HistoryProvider();

    final devBle = DeviceInfo(
      id: 'ac276eaefa68',
      name: 'RC_UI',
      rssi: -60,
      bleAddress: 'AC:27:6E:AE:FA:69',
      transportAddress: 'AC:27:6E:AE:FA:69',
      currentTransport: TransportType.ble,
    );
    await history.saveDevice(devBle, 'ble', configName: 'RC_UI');

    final devWifi = DeviceInfo(
      id: 'ac276eaefa68',
      name: 'RC_UI',
      rssi: -60,
      wifiAddress: '192.168.1.100',
      transportAddress: '192.168.1.100',
      currentTransport: TransportType.wifi,
    );
    await history.saveDevice(devWifi, 'wifi', configName: 'RC_UI');

    expect(history.pairedDevices.length, equals(1));
    final saved = history.pairedDevices.first;
    expect(saved.bleAddress, equals('AC:27:6E:AE:FA:69'));
    expect(saved.wifiAddress, equals('192.168.1.100'));
    expect(saved.lastUsedTransport, equals('wifi'));
  });
}
