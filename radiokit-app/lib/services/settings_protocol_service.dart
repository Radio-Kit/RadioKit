import 'dart:convert';
import 'dart:typed_data';
import '../models/protocol.dart';

/// Result of parsing a 0xDD Settings frame.
class ParsedSettingsPacket {
  final int subCmd;
  final Uint8List payload;
  const ParsedSettingsPacket({required this.subCmd, required this.payload});

  @override
  String toString() =>
      'ParsedSettingsPacket(sub=0x${subCmd.toRadixString(16).padLeft(2, "0")}, '
      'payloadLen=${payload.length})';
}

/// Build and parse 0xDD Settings frames. Mirrors the Arduino side
/// (RadioKitSettings.h / RadioKitSettings.cpp). No CRC.
class SettingsProtocolService {
  // ── Frame building ──────────────────────────────────────────────────────

  /// Build a complete Settings frame:
  ///   [0xDD] [SUB_CMD(1)] [LEN_LO(1)] [LEN_HI(1)] [PAYLOAD(N)]
  static Uint8List buildFrame(int subCmd, [List<int>? payload]) {
    final p = payload ?? const [];
    final total = kSettingsHeaderSize + p.length;
    if (total > 0xFFFF) {
      throw ArgumentError('Settings frame too large: $total bytes');
    }
    final frame = Uint8List(total);
    frame[0] = kSettingsStartByte;
    frame[1] = subCmd & 0xFF;
    frame[2] = total & 0xFF;
    frame[3] = (total >> 8) & 0xFF;
    for (int i = 0; i < p.length; i++) {
      frame[kSettingsHeaderSize + i] = p[i] & 0xFF;
    }
    return frame;
  }

  // ── Request builders ────────────────────────────────────────────────────

  /// Build GET_TELEMETRY with a 2-byte LE timestamp for round-trip RTT measurement.
  /// The device echoes this timestamp in response bytes 2-3.
  static Uint8List buildGetTelemetry([int timestamp = 0]) {
    return buildFrame(kSettingsCmdGetTelemetry, [timestamp & 0xFF, (timestamp >> 8) & 0xFF]);
  }
  static Uint8List buildBleInfo() => buildFrame(kSettingsCmdBleInfo);
  static Uint8List buildGetFeatures() => buildFrame(kSettingsCmdGetFeatures);
  static Uint8List buildGetChipInfo() => buildFrame(kSettingsCmdGetChipInfo);
  static Uint8List buildGetDeviceInfo() => buildFrame(kSettingsCmdGetDeviceInfo);
  static Uint8List buildFactoryReset() => buildFrame(kSettingsCmdFactoryReset);
  static Uint8List buildGetCloudInfo() => buildFrame(kSettingsCmdGetCloudInfo);
  static Uint8List buildReboot() => buildFrame(kSettingsCmdReboot);

  /// Build NVS_RAW_READ frame. Payload: [KEY_LEN(1)][KEY...]
  static Uint8List buildNvsRawRead(String key) {
    final encoded = utf8.encode(key);
    final payload = [encoded.length, ...encoded];
    return buildFrame(kSettingsCmdNvsRawRead, payload);
  }

  /// Build NVS_RAW_WRITE frame. Payload: [KEY_LEN(1)][KEY...][VALUE(1)]
  static Uint8List buildNvsRawWrite(String key, int value) {
    final encoded = utf8.encode(key);
    final payload = [encoded.length, ...encoded, value & 0xFF];
    return buildFrame(kSettingsCmdNvsRawWrite, payload);
  }

  /// Build SETTINGS_SET_CLOUD_INFO frame. Payload: [FIELD_MASK(2 LE)] [URL_LEN(1)?][URL...?][ACCT_LEN(1)?][ACCT...?]
  /// Fields: URL (mask bit 0), Account (mask bit 1).
  static Uint8List buildSetCloudInfo({
    String? url,
    String? account,
  }) {
    final payload = <int>[];
    int fieldMask = 0;

    if (url != null) fieldMask |= kSettingsSetCloudUrl;
    if (account != null) fieldMask |= kSettingsSetCloudAccount;

    payload.add(fieldMask & 0xFF);
    payload.add((fieldMask >> 8) & 0xFF);

    if (url != null) {
      final encoded = utf8.encode(url);
      final len = encoded.length.clamp(0, 128);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    if (account != null) {
      final encoded = utf8.encode(account);
      final len = encoded.length.clamp(0, 128);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    return buildFrame(kSettingsCmdSetCloudInfo, payload);
  }

  /// Build SETTINGS_SET_WIFI frame. Payload: [FIELD_MASK(2 LE)] [SSID_LEN(1)?][SSID...?][PWD_LEN(1)?][PWD...?]
  /// Fields: SSID (mask bit 0), Password (mask bit 1).
  static Uint8List buildSetWifi({
    String? ssid,
    String? password,
  }) {
    final payload = <int>[];
    int fieldMask = 0;

    if (ssid != null) fieldMask |= kSettingsSetWifiSsid;
    if (password != null) fieldMask |= kSettingsSetWifiPwd;

    payload.add(fieldMask & 0xFF);
    payload.add((fieldMask >> 8) & 0xFF);

    if (ssid != null) {
      final encoded = utf8.encode(ssid);
      final len = encoded.length.clamp(0, kMaxWifiSsid);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    if (password != null) {
      final encoded = utf8.encode(password);
      final len = encoded.length.clamp(0, kMaxWifiPwd);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    return buildFrame(kSettingsCmdSetWifi, payload);
  }

  /// Build SETTINGS_SET_CONF frame. Payload: [FIELD_MASK(2 LE)] [FIELD_DATA...]
  /// Field mask bits (must match RadioKitSettings.h):
  ///   bit 0 = name, bit 1 = description, bit 2 = device pwd, bit 3 = user pwd, bit 4 = icon
  static Uint8List buildSetConf({
    String? name,
    String? description,
    String? password,
    String? adminPassword,
    String? icon,
    bool clearIcon = false,
  }) {
    final payload = <int>[];
    int fieldMask = 0;

    if (name != null) fieldMask |= kSettingsSetConfName;
    if (description != null) fieldMask |= kSettingsSetConfDesc;
    if (password != null) fieldMask |= kSettingsSetConfDevicePwd;
    if (adminPassword != null) fieldMask |= kSettingsSetConfUserPwd;
    if (icon != null || clearIcon) fieldMask |= kSettingsSetConfIcon;

    payload.add(fieldMask & 0xFF);
    payload.add((fieldMask >> 8) & 0xFF);

    void addString(String s, int maxLen) {
      final encoded = utf8.encode(s);
      final len = encoded.length.clamp(0, maxLen);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    if (name != null) addString(name, kMaxConfigName);
    if (description != null) addString(description, kMaxConfigDesc);
    if (password != null) addString(password, kMaxConfigPwd);
    if (adminPassword != null) addString(adminPassword, kMaxConfigPwd);
    if (icon != null) addString(icon, kMaxDeviceIcon);
    if (clearIcon) addString('', kMaxDeviceIcon);

    return buildFrame(kSettingsCmdSetConf, payload);
  }

  /// Build SETTINGS_PWD_AUTH frame. Payload: [PWD_LEN(1)][PWD]
  /// No flags byte needed — the new auth uses a single PWD_AUTH command
  /// and the device determines the auth level (device or user) from the
  /// password itself.
  /// @param password The password to authenticate with.
  /// @param admin Ignored for new firmware (kept for backward compat with old firmware).
  static Uint8List buildPwdAuth(String password, {bool admin = false}) {
    final encoded = utf8.encode(password);
    final len = encoded.length.clamp(0, kMaxConfigPwd);
    final payload = [len, ...encoded.take(len)];
    // For old firmware (< v5), append admin flag if requested
    if (admin) {
      payload.add(kSettingsPwdAuthFlagAdmin);
    }
    return buildFrame(kSettingsCmdPwdAuth, payload);
  }

  // ── Frame parsing ───────────────────────────────────────────────────────

  /// Parse a complete 0xDD frame from raw bytes.
  static ParsedSettingsPacket? parseFrame(List<int> data) {
    if (data.length < kSettingsHeaderSize) return null;
    if (data[0] != kSettingsStartByte) return null;
    final subCmd = data[1];
    final payload = Uint8List.fromList(data.sublist(kSettingsHeaderSize));
    return ParsedSettingsPacket(subCmd: subCmd, payload: payload);
  }

  // ── Response parsers ────────────────────────────────────────────────────

  /// Parse NVS_RAW_READ_DATA: [STATUS(1)][VALUE_LEN(1)][VALUE...]
  /// Returns (status, value, rawBytes) on success, null on parse failure.
  /// - For uint8 values: value = payload[2], rawBytes = null
  /// - For string values: value = null, rawBytes = payload[2..2+valueLen]
  static ({int status, int? value, List<int>? rawBytes})? parseNvsRawReadData(List<int> payload) {
    if (payload.length < 2) return null;
    final status = payload[0];
    final valueLen = payload[1];
    int? value;
    List<int>? rawBytes;
    if (status == kSettingsNvsRawOk && valueLen >= 1 && payload.length >= 2 + valueLen) {
      if (valueLen == 1) {
        // uint8 value
        value = payload[2];
      } else {
        // string value — return raw bytes for decoding
        rawBytes = payload.sublist(2, 2 + valueLen);
      }
    }
    return (status: status, value: value, rawBytes: rawBytes);
  }

  /// Parse NVS_RAW_WRITE_ACK: single byte status code.
  static int? parseNvsRawWriteAck(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }

  /// Parse PWD_AUTH_ACK: single byte status code.
  static int? parsePwdAuthAck(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }

  /// Parse TELEMETRY_DATA: [RSSI(1)] [LATENCY(1)] [...]
  static ({int rssi, int latency})? parseTelemetryData(List<int> payload) {
    if (payload.isEmpty) return null;
    final rawRssi = payload[0];
    final rssi = rawRssi > 127 ? rawRssi - 256 : rawRssi;
    final latency = payload.length >= 2 ? payload[1] : 0;
    return (rssi: rssi, latency: latency);
  }

  /// Parse BLE_INFO_DATA: [CONN_INTERVAL_MS(2 LE)][MTU(2 LE)][RSSI(1)]
  static ({int connIntervalMs, int mtu, int rssi})? parseBleInfoData(
      List<int> payload) {
    if (payload.length < 5) return null;
    final connIntervalMs = payload[0] | (payload[1] << 8);
    final mtu = payload[2] | (payload[3] << 8);
    final rawRssi = payload[4];
    final rssi = rawRssi > 127 ? rawRssi - 256 : rawRssi;
    return (connIntervalMs: connIntervalMs, mtu: mtu, rssi: rssi);
  }

  /// Parse FEATURES_DATA: [BITMASK(1)]
  static int? parseFeaturesData(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }

  /// Parse CLOUD_INFO_DATA: [URL_LEN(1)][URL...][ACCOUNT_LEN(1)][ACCOUNT...]
  /// Returns (url, account) on success, null on parse failure.
  static ({String url, String account})? parseCloudInfoData(List<int> payload) {
    if (payload.length < 2) return null;
    int offset = 0;
    final urlLen = payload[offset++];
    if (offset + urlLen > payload.length) return null;
    final url = utf8.decode(payload.sublist(offset, offset + urlLen),
        allowMalformed: true);
    offset += urlLen;
    if (offset >= payload.length) return null;
    final accLen = payload[offset++];
    final account = (offset + accLen <= payload.length)
        ? utf8.decode(payload.sublist(offset, offset + accLen),
            allowMalformed: true)
        : '';
    return (url: url, account: account);
  }

  /// Parse DEVICE_INFO_DATA: [PROTO_VER(1)][NAME_LEN(1)][NAME][DESC_LEN(1)][DESC][UID_LEN(1)][UID][ICON_LEN(1)][ICON...]
  /// Icon field is optional (protocol v5+). Returns null if icon is absent.
  static ({int version, String name, String description, String uid, String? icon})? parseDeviceInfoData(
      List<int> payload) {
    if (payload.length < 3) return null;
    int offset = 0;
    final version = payload[offset++];
    final nameLen = payload[offset++];
    if (offset + nameLen > payload.length) return null;
    final name = utf8.decode(payload.sublist(offset, offset + nameLen),
        allowMalformed: true);
    offset += nameLen;
    if (offset >= payload.length) return null;
    final descLen = payload[offset++];
    final description = (offset + descLen <= payload.length)
        ? utf8.decode(payload.sublist(offset, offset + descLen),
            allowMalformed: true)
        : '';
    offset += descLen;
    // Parse UID (always present in protocol v5)
    String uid = '';
    if (offset + 1 <= payload.length) {
      final uidLen = payload[offset++];
      if (offset + uidLen <= payload.length && uidLen == 16) {
        uid = utf8.decode(payload.sublist(offset, offset + uidLen),
            allowMalformed: true);
        offset += uidLen;
      }
    }
    // Parse optional icon string (protocol v5+)
    String? icon;
    if (offset + 1 <= payload.length) {
      final iconLen = payload[offset++];
      if (iconLen > 0 && offset + iconLen <= payload.length) {
        icon = utf8.decode(payload.sublist(offset, offset + iconLen),
            allowMalformed: true);
      }
      // If iconLen == 0, icon remains null (not set)
    }
    return (version: version, name: name, description: description, uid: uid, icon: icon);
  }
}
