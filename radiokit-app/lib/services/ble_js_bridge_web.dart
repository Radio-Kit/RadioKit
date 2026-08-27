import 'dart:js_interop';
import 'ble_service_impl.dart';

@JS('injectBlePacket')
external set _injectBlePacket(JSFunction f);

/// Exposes packet injection to JavaScript for the unified Web simulator.
void setupBleJsBridge(BleService service) {
  _injectBlePacket = (JSArray<JSNumber> bytes) {
    service.injectDebugPacket(bytes.toDart.map((e) => e.toDartInt).toList());
  }.toJS;
}
