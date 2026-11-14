import 'dart:typed_data';
import 'transport_service.dart';
import '../models/debug_log_entry.dart';
import '../models/protocol.dart';
import 'protocol_service.dart';
import 'ble_transport.dart';
import 'fs_protocol_service.dart';
import 'ota_protocol_service.dart';
import 'settings_protocol_service.dart';

/// Transparent [TransportService] decorator that logs every APP/MCU packet
/// to a [DebugLogSink] without altering transport behaviour.
///
/// Usage:
///   final debug = DebugTransport(inner: realService, sink: debugProvider);
///   deviceProvider.setTransport(debug);
class DebugTransport implements TransportService {
  final TransportService _inner;
  final DebugLogSink sink;

  DebugTransport({required TransportService inner, required this.sink})
      : _inner = inner;

  TransportService get inner => _inner;

  @override
  Stream<String> get logStream => _inner.logStream;

  Map<String, dynamic>? getDiagnostics() {
    final inn = _inner;
    if (inn is BleTransport) return inn.getDiagnostics();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Delegate callbacks — intercept MCU
  // ---------------------------------------------------------------------------

  @override
  set onPacketReceived(PacketReceivedCallback? cb) {
    _inner.onPacketReceived = cb == null
        ? null
        : (packet) {
            // Log before forwarding
            final entry = _makeEntry(
              direction: PacketDirection.mcu,
              bytes: _rebuildFramedBytes(packet),
              crcOk: true, // ProtocolService only calls back on valid CRC
              forcedChannel: 'widget',
            );
            sink.addEntry(entry);
            cb(packet);
          };
  }

  @override
  PacketReceivedCallback? get onPacketReceived => _inner.onPacketReceived;

  @override
  set onFsPacketReceived(FsPacketReceivedCallback? cb) {
    _inner.onFsPacketReceived = cb == null
        ? null
        : (packet) {
            final entry = _makeFsEntry(
              direction: PacketDirection.mcu,
              packet: packet,
            );
            sink.addEntry(entry);
            cb(packet);
          };
  }

  @override
  FsPacketReceivedCallback? get onFsPacketReceived => _inner.onFsPacketReceived;

  @override
  set onOtaPacketReceived(OtaPacketReceivedCallback? cb) {
    _inner.onOtaPacketReceived = cb == null
        ? null
        : (packet) {
            final entry = _makeOtaEntry(
              direction: PacketDirection.mcu,
              packet: packet,
            );
            sink.addEntry(entry);
            cb(packet);
          };
  }

  @override
  OtaPacketReceivedCallback? get onOtaPacketReceived => _inner.onOtaPacketReceived;

  @override
  set onSettingsPacketReceived(SettingsPacketReceivedCallback? cb) {
    _inner.onSettingsPacketReceived = cb == null
        ? null
        : (packet) {
            final entry = _makeSettingsEntry(
              direction: PacketDirection.mcu,
              packet: packet,
            );
            sink.addEntry(entry);
            cb(packet);
          };
  }

  @override
  SettingsPacketReceivedCallback? get onSettingsPacketReceived =>
      _inner.onSettingsPacketReceived;

  @override
  set onConnectionLost(ConnectionLostCallback? cb) =>
      _inner.onConnectionLost = cb;

  @override
  ConnectionLostCallback? get onConnectionLost => _inner.onConnectionLost;

  // ---------------------------------------------------------------------------
  // Delegate core methods — intercept APP
  // ---------------------------------------------------------------------------

  @override
  bool get isConnected => _inner.isConnected;

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) =>
      _inner.connect(deviceId, baudRate: baudRate);

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<void> writePacket(Uint8List data) async {
    final entry = _makeEntry(
      direction: PacketDirection.app,
      bytes: data,
      crcOk: _verifyCrc(data),
    );
    sink.addEntry(entry);
    await _inner.writePacket(data);
  }

  @override
  Future<void> dispose() => _inner.dispose();

  @override
  Future<int?> getRssi() => _inner.getRssi();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Rebuild the full framed packet bytes from a [ParsedPacket] (MCU path).
  List<int> _rebuildFramedBytes(ParsedPacket packet) {
    final rebuilt = ProtocolService.buildPacket(packet.cmd, packet.payload);
    return rebuilt.toList();
  }

  DebugLogEntry _makeFsEntry({
    required PacketDirection direction,
    required ParsedFsPacket packet,
  }) {
    final frame = FsProtocolService.buildFrame(packet.subCmd, packet.payload);
    return _makeEntry(
      direction: direction,
      bytes: frame.toList(),
      crcOk: true,
      forcedChannel: 'fs',
    );
  }

  DebugLogEntry _makeOtaEntry({
    required PacketDirection direction,
    required ParsedOtaPacket packet,
  }) {
    final frame = OtaProtocolService.buildFrame(packet.subCmd, packet.payload);
    return _makeEntry(
      direction: direction,
      bytes: frame.toList(),
      crcOk: true,
      forcedChannel: 'ota',
    );
  }

  DebugLogEntry _makeSettingsEntry({
    required PacketDirection direction,
    required ParsedSettingsPacket packet,
  }) {
    final frame = SettingsProtocolService.buildFrame(packet.subCmd, packet.payload);
    return _makeEntry(
      direction: direction,
      bytes: frame.toList(),
      crcOk: true,
      forcedChannel: 'settings',
    );
  }

  DebugLogEntry _makeEntry({
    required PacketDirection direction,
    required List<int> bytes,
    bool? crcOk,
    String? forcedChannel,
  }) {
    if (bytes.isEmpty) {
      return DebugLogEntry(
        timestamp: DateTime.now(),
        direction: direction,
        bytes: bytes,
        cmdName: 'EMPTY',
        payloadHex: '',
        crcOk: crcOk,
        channel: forcedChannel ?? 'widget',
      );
    }

    final startByte = bytes[0];
    String channel = forcedChannel ?? 'widget';
    String cmdName = '?';
    String payloadHex = '';

    if (startByte == kStartByte) {
      channel = 'widget';
      if (bytes.length >= 4) {
        cmdName = _widgetCmdName(bytes[3]);
      }
      if (bytes.length > 6) {
        final payloadBytes = bytes.sublist(4, bytes.length - 2);
        payloadHex = payloadBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      }
    } else if (startByte == kFsStartByte) {
      channel = 'fs';
      if (bytes.length >= 2) {
        cmdName = _fsCmdName(bytes[1]);
      }
      if (bytes.length > 6) {
        final payloadBytes = bytes.sublist(4, bytes.length - 2);
        payloadHex = payloadBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      }
    } else if (startByte == kOtaStartByte) {
      channel = 'ota';
      if (bytes.length >= 2) {
        cmdName = _otaCmdName(bytes[1]);
      }
      if (bytes.length > 6) {
        final payloadBytes = bytes.sublist(4, bytes.length - 2);
        payloadHex = payloadBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      }
    } else if (startByte == kSettingsStartByte) {
      channel = 'settings';
      if (bytes.length >= 2) {
        cmdName = _settingsCmdName(bytes[1]);
      }
      if (bytes.length > 6) {
        final payloadBytes = bytes.sublist(4, bytes.length - 2);
        payloadHex = payloadBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      }
    } else if (startByte == kPrintStartByte) {
      channel = 'print';
      cmdName = 'PRINT';
      if (bytes.length > 3) {
        payloadHex = bytes
            .sublist(3)
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      }
    } else {
      channel = forcedChannel ?? 'raw';
      cmdName = 'RAW[0x${startByte.toRadixString(16).padLeft(2, '0').toUpperCase()}]';
      payloadHex = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    }

    return DebugLogEntry(
      timestamp: DateTime.now(),
      direction: direction,
      bytes: bytes,
      cmdName: cmdName,
      payloadHex: payloadHex,
      crcOk: crcOk,
      channel: channel,
    );
  }

  bool _verifyCrc(List<int> data) {
    if (data.isEmpty) return false;
    final startByte = data[0];
    if (startByte == kStartByte) {
      return ProtocolService.parsePacket(data) != null;
    } else if (startByte == kFsStartByte) {
      return FsProtocolService.parseFrame(data) != null;
    } else if (startByte == kOtaStartByte) {
      return OtaProtocolService.parseFrame(data) != null;
    } else if (startByte == kSettingsStartByte) {
      return SettingsProtocolService.parseFrame(data) != null;
    }
    return true;
  }

  String _widgetCmdName(int cmd) {
    switch (cmd) {
      case kCmdGetConf:        return 'GET_CONF';
      case kCmdConfData:       return 'CONF_DATA';
      case kCmdGetVars:        return 'GET_VARS';
      case kCmdVarData:        return 'VAR_DATA';
      case kCmdSetInput:       return 'SET_INPUT';
      case kCmdAck:            return 'ACK';
      case kCmdVarUpdate:      return 'VAR_UPDATE';
      case kCmdGetMeta:        return 'GET_META';
      case kCmdMetaData:       return 'META_DATA';
      case kCmdMetaUpdate:     return 'META_UPDATE';
      case kCmdGetTelemetry:   return 'GET_TELEMETRY';
      case kCmdTelemetryData: return 'TELEMETRY_DATA';
      default: return '0x${cmd.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }
  }

  String _fsCmdName(int subCmd) {
    switch (subCmd) {
      case kFsCmdList:        return 'FS_LIST';
      case kFsCmdRead:        return 'FS_READ';
      case kFsCmdWrite:       return 'FS_WRITE';
      case kFsCmdDelete:      return 'FS_DELETE';
      case kFsCmdInfo:        return 'FS_INFO';
      case kFsCmdMkdir:       return 'FS_MKDIR';
      case kFsCmdRename:      return 'FS_RENAME';
      case kFsCmdUploadBegin: return 'FS_UPLOAD_BEGIN';
      case kFsCmdUploadChunk: return 'FS_UPLOAD_CHUNK';
      case kFsCmdUploadEnd:   return 'FS_UPLOAD_END';
      case kFsCmdFormat:      return 'FS_FORMAT';
      case kFsCmdReplace:     return 'FS_REPLACE';
      case kFsCmdCrc32:       return 'FS_CRC32';
      default: return 'FS_0x${subCmd.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }
  }

  String _otaCmdName(int subCmd) {
    switch (subCmd) {
      case kOtaCmdBegin:       return 'OTA_BEGIN';
      case kOtaCmdChunk:       return 'OTA_CHUNK';
      case kOtaCmdEnd:         return 'OTA_END';
      case kOtaCmdAbort:       return 'OTA_ABORT';
      case kOtaCmdSetEraseFlag:return 'OTA_SET_ERASE';
      default: return 'OTA_0x${subCmd.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }
  }

  String _settingsCmdName(int subCmd) {
    switch (subCmd) {
      case kSettingsCmdBleInfo:       return 'SETTINGS_BLE_INFO';
      case kSettingsCmdGetFeatures:   return 'SETTINGS_GET_FEATURES';
      case kSettingsCmdGetChipInfo:   return 'SETTINGS_GET_CHIP_INFO';
      case kSettingsCmdGetDeviceInfo: return 'SETTINGS_GET_DEVICE_INFO';
      case kSettingsCmdFactoryReset:  return 'SETTINGS_FACTORY_RESET';
      case kSettingsCmdGetCloudInfo:  return 'SETTINGS_GET_CLOUD_INFO';
      case kSettingsCmdGetLinksInfo:  return 'SETTINGS_GET_LINKS_INFO';
      case kSettingsCmdReboot:        return 'SETTINGS_REBOOT';
      case kSettingsCmdNvsRawRead:    return 'SETTINGS_NVS_READ';
      case kSettingsCmdNvsRawWrite:   return 'SETTINGS_NVS_WRITE';
      case kSettingsCmdSetCloudInfo:  return 'SETTINGS_SET_CLOUD_INFO';
      case kSettingsCmdSetWifi:       return 'SETTINGS_SET_WIFI';
      case kSettingsCmdSetConf:       return 'SETTINGS_SET_CONF';
      case kSettingsCmdPwdAuth:       return 'SETTINGS_PWD_AUTH';
      default: return 'SETTINGS_0x${subCmd.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }
  }
}

/// Interface implemented by [DebugProvider] so that [DebugTransport]
/// has no dependency on the provider layer.
abstract class DebugLogSink {
  void addEntry(DebugLogEntry entry);
}
