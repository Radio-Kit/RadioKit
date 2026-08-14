import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/protocol.dart';
import '../models/widget_config.dart';
import 'fs_protocol_service.dart';
import 'ota_protocol_service.dart';
import 'settings_protocol_service.dart';

/// Result of parsing a CONF_DATA payload.
class ParsedConf {
  final String name;
  final String description;
  final String theme;
  final int orientation;
  final int activePage;
  final int numPages;
  final List<int> pageOrientations;
  final List<WidgetConfig> widgets;
  const ParsedConf({
    required this.name,
    required this.description,
    required this.theme,
    required this.orientation,
    this.activePage = 0,
    this.numPages = 1,
    this.pageOrientations = const [],
    required this.widgets,
  });
}

/// Handles all packet building, parsing, and CRC computation for the
/// RadioKit binary protocol v3.0.
class ProtocolService {
  // ── CRC-16/CCITT-FALSE  (poly 0x1021, init 0xFFFF) ──────────────────────

  static int _crc16(List<int> data) {
    int crc = 0xFFFF;
    for (final byte in data) {
      crc ^= (byte & 0xFF) << 8;
      for (int i = 0; i < 8; i++) {
        crc = ((crc & 0x8000) != 0)
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }

  // ── Packet building ──────────────────────────────────────────────────────

  /// Build a complete RadioKit packet:
  ///   START(1) + LENGTH(2 LE) + CMD(1) + PAYLOAD(N) + CRC(2 LE)
  static Uint8List buildPacket(int cmd, [List<int>? payload]) {
    final p     = payload ?? [];
    final total = 6 + p.length;
    final crc   = _crc16([cmd, ...p]);
    final pkt   = Uint8List(total);
    pkt[0] = kStartByte;
    pkt[1] = total & 0xFF;
    pkt[2] = (total >> 8) & 0xFF;
    pkt[3] = cmd;
    for (int i = 0; i < p.length; i++) {
      pkt[4 + i] = p[i] & 0xFF;
    }
    pkt[total - 2] = crc & 0xFF;
    pkt[total - 1] = (crc >> 8) & 0xFF;
    return pkt;
  }

  static Uint8List buildGetConf()  => buildPacket(kCmdGetConf);
  static Uint8List buildGetVars()  => buildPacket(kCmdGetVars);
  static Uint8List buildGetMeta()  => buildPacket(kCmdGetMeta);
  static Uint8List buildGetTelemetry() => buildPacket(kCmdGetTelemetry);
  static Uint8List buildBleInfo() => buildPacket(kCmdBleInfo);
  static Uint8List buildGetFeatures() => buildPacket(kCmdGetFeatures);
  static Uint8List buildGetChipInfo() => buildPacket(kCmdGetChipInfo);

  /// Build CMD_GET_WIFI_INFO (0x1D) request.
  static Uint8List buildGetWifiInfo() => buildPacket(kCmdGetWifiInfo);

  /// Parse CMD_WIFI_INFO_DATA (0x1E) payload.
  /// Payload: [IP0][IP1][IP2][IP3][MODE(1)][SSID_LEN(1)][SSID...][RSSI(1)]
  /// Returns (ip, mode, ssid, rssi) or null if payload is too short.
  static ({String ip, int mode, String ssid, int rssi})? parseWifiInfoData(
      List<int> payload) {
    if (payload.length < 6) return null;
    final ip = '${payload[0]}.${payload[1]}.${payload[2]}.${payload[3]}';
    final mode = payload[4];
    final ssidLen = payload[5];
    final ssid = (ssidLen > 0 && 6 + ssidLen <= payload.length)
        ? utf8.decode(payload.sublist(6, 6 + ssidLen), allowMalformed: true)
        : '';
    final rssiOffset = 6 + ssidLen;
    final rawRssi = rssiOffset < payload.length ? payload[rssiOffset] : 0;
    final rssi = rawRssi > 127 ? rawRssi - 256 : rawRssi;
    return (ip: ip, mode: mode, ssid: ssid, rssi: rssi);
  }

  // ── NVS SET_CONF / PWD_AUTH ──────────────────────────────────────────────

  /// Build a CMD_SET_CONF (0x19) packet to write config to NVS.
  /// Pass null for fields you don't want to change.
  static Uint8List buildSetConf({
    String? name,
    String? description,
    String? password,
    String? adminPassword,
  }) {
    final payload = <int>[];
    int fieldMask = 0;

    if (name != null) {
      fieldMask |= kSetConfName;
    }
    if (description != null) {
      fieldMask |= kSetConfDesc;
    }
    if (password != null) {
      fieldMask |= kSetConfPwd;
    }
    if (adminPassword != null) {
      fieldMask |= kSetConfAdminPwd;
    }

    // Field mask (2 bytes LE)
    payload.add(fieldMask & 0xFF);
    payload.add((fieldMask >> 8) & 0xFF);

    if (name != null) {
      final encoded = utf8.encode(name);
      final len = encoded.length.clamp(0, kMaxConfigName);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    if (description != null) {
      final encoded = utf8.encode(description);
      final len = encoded.length.clamp(0, kMaxConfigDesc);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    if (password != null) {
      final encoded = utf8.encode(password);
      final len = encoded.length.clamp(0, kMaxConfigPwd);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    if (adminPassword != null) {
      final encoded = utf8.encode(adminPassword);
      final len = encoded.length.clamp(0, kMaxConfigPwd);
      payload.add(len);
      payload.addAll(encoded.take(len));
    }

    return buildPacket(kCmdSetConf, payload);
  }

  /// Build a CMD_PWD_AUTH (0x1A) packet.
  /// If [admin] is true, appends the admin-request flag byte.
  static Uint8List buildPwdAuth(String password, {bool admin = false}) {
    final encoded = utf8.encode(password);
    final len = encoded.length.clamp(0, kMaxConfigPwd);
    final payload = [len, ...encoded.take(len)];
    if (admin) {
      payload.add(kPwdAuthFlagAdmin);
    }
    return buildPacket(kCmdPwdAuth, payload);
  }

  /// Parse a PWD_AUTH response from an ACK payload byte.
  /// Returns null if the payload can't be parsed.
  static int? parsePwdAuthResponse(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }

  /// Build a CMD_FACTORY_RESET (0x1B) packet — erase NVS config and reboot.
  static Uint8List buildFactoryReset() => buildPacket(kCmdFactoryReset);

  /// Build an ACK packet acknowledging a VAR_UPDATE with [seq].
  static Uint8List buildAck(int seq) => buildPacket(kCmdAck, [seq & 0xFF]);

  /// Build a VAR_UPDATE packet: [PAGE(1)] [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  /// The page prefix byte is only emitted when [page] > 0, for v4 firmware compat.
  static Uint8List buildVarUpdate(int widgetId, int seq, List<int> values, {int page = 0}) {
    final payload = <int>[];
    if (page > 0) payload.add(page & 0xFF);
    payload.addAll([widgetId & 0xFF, seq & 0xFF, ...values]);
    return buildPacket(kCmdVarUpdate, payload);
  }

  /// Build a SET_INPUT packet: [PAGE(1)] [WIDGET_ID(1)] [VALUES...]
  /// The page prefix byte is only emitted when [page] > 0, for v4 firmware compat.
  static Uint8List buildSetInput(
      List<WidgetConfig> widgets, RadioWidgetState state, {int page = 0}) {
    final payload = <int>[];
    if (page > 0) payload.add(page & 0xFF);
    final inputWidgets = widgets.where((w) => w.hasInput).toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in inputWidgets) {
      final values = state.inputValues[widget.widgetId] ?? [];
      if (widget.typeId == kWidgetJoystick) {
        final x = values.isNotEmpty ? values[0] : 0;
        final y = values.length > 1  ? values[1] : 0;
        payload.add(x < 0 ? x + 256 : x);
        payload.add(y < 0 ? y + 256 : y);
      } else {
        payload.add((values.isNotEmpty ? values[0] : 0) & 0xFF);
      }
    }
    return buildPacket(kCmdSetInput, payload);
  }

  // ── Packet parsing ────────────────────────────────────────────────────────

  static ParsedPacket? parsePacket(List<int> data) {
    if (data.length < 6) {
      debugPrint('RadioKit parsePacket: too short (${data.length} bytes)');
      return null;
    }
    if (data[0] != kStartByte) {
      debugPrint('RadioKit parsePacket: bad start byte 0x${data[0].toRadixString(16).padLeft(2, "0")}');
      return null;
    }
    final length = data[1] | (data[2] << 8);
    if (data.length < length) {
      debugPrint('RadioKit parsePacket: buffer shorter than declared length (${data.length} < $length)');
      return null;
    }
    final cmd        = data[3];
    final payloadEnd = length - 2;
    final payload    = data.sublist(4, payloadEnd);
    final rxCrc      = data[payloadEnd] | (data[payloadEnd + 1] << 8);
    final calcCrc    = _crc16([cmd, ...payload]);
    if (rxCrc != calcCrc) {
      debugPrint('RadioKit parsePacket: CRC mismatch (got 0x${rxCrc.toRadixString(16)}, calc 0x${calcCrc.toRadixString(16)}) cmd=0x${cmd.toRadixString(16)} len=$length');
      debugPrint('RadioKit parsePacket: raw bytes: ${data.take(length).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
      return null;
    }
    return ParsedPacket(cmd: cmd, payload: Uint8List.fromList(payload));
  }

  // ── Buffer draining (shared by all transports) ───────────────────────────
  //
  // Drains up to one complete frame (0x55 widget OR 0xAA FS) from [buffer].
  // Returns:
  //   null   — no complete frame yet, caller should keep waiting
  //   { kind: 'widget', packet }  — widget-protocol frame ready
  //   { kind: 'fs',     packet }  — FS-protocol frame ready
  // Caller is responsible for removing the consumed bytes from the buffer.

  static DrainResult? drainBuffer(List<int> buffer) {
    while (buffer.length >= 4) {
      // Find the first start byte of any protocol
      int? startIdx;
      int? startByte;
      for (int i = 0; i < buffer.length; i++) {
        if (buffer[i] == kStartByte ||
            buffer[i] == kFsStartByte ||
            buffer[i] == kOtaStartByte ||
            buffer[i] == kSettingsStartByte) {
          startIdx = i;
          startByte = buffer[i];
          break;
        }
      }
      if (startIdx == null) {
        // No start byte — keep at most 3 bytes for recovery
        if (buffer.length > 3) buffer.removeRange(0, buffer.length - 3);
        return null;
      }
      if (startIdx > 0) {
        buffer.removeRange(0, startIdx);
        continue;
      }
      if (buffer.length < 4) return null;

      // Length field position depends on the protocol:
      //   0x55 widget: [START(1)][LEN_LO(1)][LEN_HI(1)][CMD(1)]... → length at [1..2]
      //   0xAA FS:     [START(1)][SUB_CMD(1)][LEN_LO(1)][LEN_HI(1)]... → length at [2..3]
      //   0xBB OTA:    same as FS: [START(1)][SUB_CMD(1)][LEN_LO(1)][LEN_HI(1)]... → length at [2..3]
      //   0xDD Settings: same as FS: [START(1)][SUB_CMD(1)][LEN_LO(1)][LEN_HI(1)]... → length at [2..3]
      final int length = (startByte == kStartByte)
          ? (buffer[1] | (buffer[2] << 8))
          : (buffer[2] | (buffer[3] << 8));

      if (length < 4 || length > 0xFFFF) {
        buffer.removeAt(0);
        continue;
      }
      if (buffer.length < length) return null;

      final frameBytes = buffer.sublist(0, length);
      buffer.removeRange(0, length);

      if (startByte == kStartByte) {
        final pkt = parsePacket(frameBytes);
        if (pkt != null) {
          return DrainResult.widget(pkt);
        }
        // CRC failed — discard and continue
        continue;
      } else if (startByte == kFsStartByte) {
        final pkt = FsProtocolService.parseFrame(frameBytes);
        if (pkt != null) {
          return DrainResult.fs(pkt);
        }
        continue;
      } else if (startByte == kOtaStartByte) {
        final pkt = OtaProtocolService.parseFrame(frameBytes);
        if (pkt != null) {
          return DrainResult.ota(pkt);
        }
        continue;
      } else {
        // 0xDD Settings frame
        final pkt = SettingsProtocolService.parseFrame(frameBytes);
        if (pkt != null) {
          return DrainResult.settings(pkt);
        }
        continue;
      }
    }
    return null;
  }

  // ── CONF_DATA parsing (protocol v4) ────────────────────────────────────
  //
  // v4 global header (NO version/name/desc — those moved to Settings protocol):
  //   [ORIENTATION(1)] [NUM_WIDGETS(1)] [THEME_LEN(1)] [THEME(THEME_LEN)]
  //
  // v3 global header (WITH password field, deprecated, parsed for compat):
  //   [VERSION(1)] [ORIENTATION(1)] [NUM_WIDGETS(1)]
  //   [NAME_LEN(1)] [NAME(NAME_LEN)] [DESC_LEN(1)] [DESC(DESC_LEN)]
  //   [PWD_LEN(1)] [PWD(PWD_LEN)] [THEME_LEN(1)] [THEME(THEME_LEN)]
  //
  // Per widget — 10 fixed bytes:
  //   [TYPE(1)] [ID(1)] [X(1)] [Y(1)] [SCALE(1)] [ASPECT(1)]
  //   [ROT_LO(1)] [ROT_HI(1)] [STYLE(1)] [VARIANT(1)]
  // Then string section:
  //   [STR_MASK(1)] then for each set bit → [LEN(1)][STR(LEN)]
  //   bit order: LABEL (always first, no bit), LABEL_HIDDEN(1), WIDGET_HIDDEN(2),
  //   ICON(3), ONTEXT(4), OFFTEXT(5), CONTENT(6), EXTRA(7)

  static ParsedConf? parseConfData(List<int> payload) {
    if (payload.length < 6) {
      debugPrint('RadioKit CONF_DATA: payload too short (${payload.length} bytes)');
      return null;
    }

    // Determine format: v4 starts directly with ORIENTATION (no version byte),
    // v3 starts with VERSION byte.
    final isV4 = (payload[0] != kProtocolVersionV3);

    int offset;
    int orientation;
    int numWidgets;
    int activePage = 0;
    int numPages = 1;
    String name = '';
    String description = '';

    if (isV4) {
      // v5 (with pages): [ORIENTATION(1)] [NUM_WIDGETS(1)] [ACTIVE_PAGE(1)] [NUM_PAGES(1)] [THEME_LEN(1)] [THEME...]
      // v4 (without pages): [ORIENTATION(1)] [NUM_WIDGETS(1)] [THEME_LEN(1)] [THEME...]
      orientation = payload[0];
      numWidgets = payload[1];
      // Detect v5 format: payload[2] is NUM_PAGES (must be >= 1), payload[3] is THEME_LEN
      // For v4, payload[2] is THEME_LEN which could be 0-255
      // For v5, payload[3] must be THEME_LEN (0-255) and must leave room for theme
      // Key heuristic: in v5, payload[2] is NUM_PAGES (>= 1) and payload[3] is THEME_LEN
      // and 4 + payload[3] <= payload.length
      // In v4, payload[2] is THEME_LEN and 2 + payload[2] <= payload.length
      // We try v5 first: if payload.length >= 4 && payload[2] >= 1 && payload[2] <= 32
      //   && 4 + payload[3] <= payload.length, treat as v5
      // Otherwise fall back to v4
      // v5 format: [ORIENTATION(1)] [NUM_WIDGETS(1)] [ACTIVE_PAGE(1)] [NUM_PAGES(1)] [THEME_LEN(1)] [THEME...]
      // Detect v5: payload[3] is NUM_PAGES (must be >= 1), payload[4] is THEME_LEN
      // activePage (payload[2]) can be 0 on startup, so we check NUM_PAGES instead
      if (payload.length >= 5 && payload[3] >= 1 && payload[3] <= 32 &&
          payload[4] >= 0 && 5 + payload[4] <= payload.length) {
        activePage = payload[2];
        numPages = payload[3];
        offset = 4; // Skip to THEME_LEN at index 4
      } else {
        // v4 fallback: [ORIENTATION(1)] [NUM_WIDGETS(1)] [THEME_LEN(1)] [THEME...]
        offset = 2;
      }
    } else {
      // v3 (backward compat): [VERSION(1)] [ORIENTATION(1)] [NUM_WIDGETS(1)]
      //                       [NAME_LEN(1)] [NAME...] [DESC_LEN(1)] [DESC...]
      //                       [PWD_LEN(1)] [PWD...] [THEME_LEN(1)] [THEME...]
      debugPrint('RadioKit CONF_DATA: v3 format detected (backward compat)');
      orientation = payload[1];
      numWidgets = payload[2];
      offset = 3;

      // Parse name (v3 only)
      if (offset >= payload.length) return null;
      final nameLen = payload[offset++];
      if (offset + nameLen <= payload.length) {
        name = utf8.decode(payload.sublist(offset, offset + nameLen),
            allowMalformed: true);
        offset += nameLen;
      }

      // Parse description (v3 only)
      if (offset >= payload.length) return null;
      final descLen = payload[offset++];
      if (offset + descLen <= payload.length) {
        description = utf8.decode(payload.sublist(offset, offset + descLen),
            allowMalformed: true);
        offset += descLen;
      }

      // Skip password field (v3 only)
      if (offset >= payload.length) return null;
      final pwdLen = payload[offset++];
      if (offset + pwdLen > payload.length) return null;
      offset += pwdLen;
    }

    // Parse theme string (common to v3 and v4)
    if (offset >= payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated before THEME_LEN');
      return null;
    }
    final themeLen = payload[offset++];
    if (offset + themeLen > payload.length) {
      debugPrint('RadioKit CONF_DATA: truncated in THEME field');
      return null;
    }
    final theme = utf8.decode(payload.sublist(offset, offset + themeLen),
        allowMalformed: true);
    offset += themeLen;

    // Parse per-page orientations (1 byte per page when numPages > 1)
    final pageOrientations = <int>[];
    if (numPages > 1) {
      for (int i = 0; i < numPages; i++) {
        if (offset >= payload.length) {
          debugPrint('RadioKit CONF_DATA: truncated at page orientation $i');
          break;
        }
        pageOrientations.add(payload[offset++]);
      }
    }

    final widgets = <WidgetConfig>[];

    for (int i = 0; i < numWidgets; i++) {
      if (offset + 10 > payload.length) {
        debugPrint('RadioKit CONF_DATA: truncated at widget $i fixed header '
            '(offset=$offset, payload=${payload.length})');
        break;
      }

      final typeId   = payload[offset];
      final widgetId = payload[offset + 1];
      final x        = payload[offset + 2].toDouble();
      final y        = payload[offset + 3].toDouble();
      final width    = payload[offset + 4]; // ×10 multiplier
      final height   = payload[offset + 5]; // ×10 multiplier
      // Rotation: signed LE int16
      final rotRaw   = payload[offset + 6] | (payload[offset + 7] << 8);
      final rotation = rotRaw >= 0x8000 ? rotRaw - 0x10000 : rotRaw;
      final styleByte = payload[offset + 8];
      final style    = styleByte & 0x07; // low 3 bits = color variant
      final variant  = payload[offset + 9];
      offset += 10;

      if (offset >= payload.length) {
        debugPrint('RadioKit CONF_DATA: truncated before STR_MASK at widget $i');
        break;
      }
      final strMask = payload[offset++];

      String label = '', icon = '', onText = '', offText = '', content = '', centerIcon = '';
      double minAngle = -135, maxAngle = 135;

      String readStr() {
        if (offset >= payload.length) return '';
        final len = payload[offset++];
        if (len == 0) return '';
        if (offset + len > payload.length) {
          offset = payload.length;
          return '';
        }
        final s = utf8.decode(payload.sublist(offset, offset + len),
            allowMalformed: true);
        offset += len;
        return s;
      }

      // Label is always the first string (no mask bit).
      label = readStr();
      if ((strMask & kStrMaskIcon)    != 0) icon    = readStr();
      if ((strMask & kStrMaskOnText)  != 0) onText  = readStr();
      if ((strMask & kStrMaskOffText) != 0) offText = readStr();
      if ((strMask & kStrMaskContent) != 0) content = readStr();

      if ((strMask & kStrMaskExtra) != 0) {
        if (offset < payload.length) {
          final extraLen = payload[offset++];
          final extraEnd = offset + extraLen;
          if (extraLen >= 5 && typeId == kWidgetKnob) {
            final iconLen = payload[offset++];
            if (iconLen > 0 && offset + iconLen <= extraEnd) {
              centerIcon = utf8.decode(payload.sublist(offset, offset + iconLen),
                  allowMalformed: true);
              offset += iconLen;
            }
            if (offset + 4 <= extraEnd) {
              final miRaw = payload[offset] | (payload[offset + 1] << 8);
              minAngle = (miRaw >= 0x8000 ? miRaw - 0x10000 : miRaw).toDouble();
              offset += 2;
              final maRaw = payload[offset] | (payload[offset + 1] << 8);
              maxAngle = (maRaw >= 0x8000 ? maRaw - 0x10000 : maRaw).toDouble();
            }
          }
          offset = extraEnd;
        }
      }

      final labelHidden = (strMask & kStrMaskLabelHidden) != 0;
      final widgetHidden = (strMask & kStrMaskWidgetHidden) != 0;

      widgets.add(WidgetConfig(
        typeId:      typeId,
        widgetId:    widgetId,
        x:           x,
        y:           y,
        width:       width,
        height:      height,
        rotation:    rotation,
        style:       style,
        variant:     variant,
        strMask:     strMask,
        label:       label,
        icon:        icon,
        onText:      onText,
        offText:     offText,
        content:     content,
        minAngle:    minAngle,
        maxAngle:    maxAngle,
        centerIcon:  centerIcon,
        labelHidden: labelHidden,
        hidden: widgetHidden,
      ));

      debugPrint('  widget[$i]: ${widgets.last}');
    }

    debugPrint('RadioKit CONF_DATA: parsed ${widgets.length}/$numWidgets widgets OK');
    return ParsedConf(
      name: name,
      description: description,
      theme: theme,
      orientation: orientation,
      activePage: activePage,
      numPages: numPages,
      pageOrientations: pageOrientations,
      widgets: widgets,
    );
  }

  // ── VAR_DATA parsing ─────────────────────────────────────────────────────

  static RadioWidgetState? parseVarData(
      List<int> payload, List<WidgetConfig> widgets, RadioWidgetState current) {
    int offset = 0;
    var state  = current;

    final sortedWidgets = widgets.toList()
      ..sort((a, b) => a.widgetId.compareTo(b.widgetId));

    for (final widget in sortedWidgets) {
      final inSz = widget.inputSize;
      final outSz = widget.outputSize;
      final sz = outSz > 0 ? outSz : inSz;
      
      if (sz == 0) continue;
      if (offset >= payload.length) break;

      if (widget.typeId == kWidgetText) {
        // [LEN(1)] [CHARS...]
        final len = payload[offset];
        final remaining = payload.length - (offset + 1);
        final end = (offset + 1 + min(len, remaining)).clamp(0, payload.length).toInt();
        
        final text = utf8.decode(payload.sublist(offset + 1, end), allowMalformed: true);
        state = state.copyWithOutput(widget.widgetId, text);
        offset += 32; // Skip the fixed-size slot
      } else if (widget.typeId == kWidgetLed) {
        if (offset + 5 <= payload.length) {
          final led = List<int>.from(payload.sublist(offset, offset + 5));
          state = state.copyWithOutput(widget.widgetId, led);
        }
        offset += 5;
      } else {
        // Generic 1-byte or N-byte values (Switch, Slider, etc.)
        if (offset + sz <= payload.length) {
          final val = payload[offset]; // For now we assume 1-byte for most
          if (outSz > 0) {
            state = state.copyWithOutput(widget.widgetId, val);
          } else {
            state = state.copyWithInput(widget.widgetId, [val]);
          }
        }
        offset += sz;
      }
    }

    return state;
  }

  /// Parse a VAR_UPDATE payload.
  /// v5: [PAGE(1)] [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  /// v4: [WIDGET_ID(1)] [SEQ(1)] [VALUES...]
  static (int page, int widgetId, int seq, List<int> values)? parseVarUpdate(
      List<int> payload, {bool hasPagePrefix = true}) {
    if (hasPagePrefix) {
      if (payload.length < 3) return null;
      return (payload[0], payload[1], payload[2], payload.sublist(3));
    } else {
      if (payload.length < 2) return null;
      return (0, payload[0], payload[1], payload.sublist(2));
    }
  }

  /// Parse a full META_DATA payload.
  static List<WidgetConfig>? parseMetaData(
      List<int> payload, List<WidgetConfig> currentWidgets) {
    int offset = 0;
    final results = <WidgetConfig>[];
    for (final w in currentWidgets) {
      if (offset >= payload.length) break;
      final (updated, nextOffset) = _readStrings(w, payload, offset);
      results.add(updated);
      offset = nextOffset;
    }
    return results;
  }

  /// Parse a partial META_UPDATE payload: [WIDGET_ID(1)] [SEQ(1)] [STRINGS...]
  static (int, int, WidgetConfig)? parseMetaUpdate(
      List<int> payload, List<WidgetConfig> currentWidgets) {
    if (payload.length < 2) return null;
    final widgetId = payload[0];
    final seq = payload[1];
    final widget = currentWidgets.firstWhere((w) => w.widgetId == widgetId,
        orElse: () => WidgetConfig(
            typeId: 0, widgetId: widgetId, x: 0, y: 0, width: 0, height: 0));
    final (updated, _) = _readStrings(widget, payload, 2);
    return (widgetId, seq, updated);
  }

  // ── Page management commands ─────────────────────────────────────────────

  /// Build CMD_SET_PAGE (0x20): switch to page [pageIndex].
  static Uint8List buildSetPage(int pageIndex) =>
      buildPacket(kCmdSetPage, [pageIndex & 0xFF]);

  /// Build CMD_GET_PAGES (0x22): request page names.
  static Uint8List buildGetPages() => buildPacket(kCmdGetPages);

  /// Parse CMD_PAGE_CHANGED (0x21) or CMD_PAGE_SWITCH (0x24) payload: [PAGE_INDEX(1)].
  static int? parsePageIndex(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload[0];
  }

  /// Parse CMD_PAGES_DATA (0x23) payload: [NUM_PAGES(1)] + per-page [NAME_LEN(1)][NAME...].
  static List<String>? parsePagesData(List<int> payload) {
    if (payload.isEmpty) return null;
    final numPages = payload[0];
    final names = <String>[];
    int offset = 1;
    for (int i = 0; i < numPages; i++) {
      if (offset >= payload.length) return names;
      final nameLen = payload[offset++];
      if (offset + nameLen > payload.length) {
        names.add('');
        break;
      }
      names.add(utf8.decode(payload.sublist(offset, offset + nameLen),
          allowMalformed: true));
      offset += nameLen;
    }
    return names;
  }

  // ── Helper: read strings section ───────────────────────────────────────────

  /// Helper to read the string section [MASK(1)] [LEN(1)][STR...] into a WidgetConfig.
  static (WidgetConfig, int) _readStrings(
      WidgetConfig w, List<int> payload, int offset) {
    if (offset >= payload.length) return (w, offset);
    final strMask = payload[offset++];
    String label = w.label,
        icon = w.icon,
        onText = w.onText,
        offText = w.offText,
        content = w.content;

    int current = offset;
    String readNext() {
      if (current >= payload.length) return '';
      final len = payload[current++];
      if (len == 0) return '';
      if (current + len > payload.length) {
        current = payload.length;
        return '';
      }
      final s = utf8.decode(payload.sublist(current, current + len),
          allowMalformed: true);
      current += len;
      return s;
    }

    // Label is always the first string (no mask bit).
    label = readNext();
    if ((strMask & kStrMaskIcon) != 0) icon = readNext();
    if ((strMask & kStrMaskOnText) != 0) onText = readNext();
    if ((strMask & kStrMaskOffText) != 0) offText = readNext();
    if ((strMask & kStrMaskContent) != 0) content = readNext();

    double minAngle = w.minAngle;
    double maxAngle = w.maxAngle;
    if ((strMask & kStrMaskExtra) != 0) {
      if (current < payload.length) {
        final extraLen = payload[current++];
        if (extraLen >= 4 && w.typeId == kWidgetKnob) {
          final miRaw = payload[current] | (payload[current + 1] << 8);
          minAngle = (miRaw >= 0x8000 ? miRaw - 0x10000 : miRaw).toDouble();
          final maRaw = payload[current + 2] | (payload[current + 3] << 8);
          maxAngle = (maRaw >= 0x8000 ? maRaw - 0x10000 : maRaw).toDouble();
          current += extraLen;
        } else {
          current += extraLen;
        }
      }
    }

    final labelHidden = (strMask & kStrMaskLabelHidden) != 0;
    final widgetHidden = (strMask & kStrMaskWidgetHidden) != 0;

    final updated = w.copyWith(
      label: label,
      icon: icon,
      onText: onText,
      offText: offText,
      content: content,
      strMask: strMask,
      minAngle: minAngle,
      maxAngle: maxAngle,
      labelHidden: labelHidden,
      hidden: widgetHidden,
    );
    return (updated, current);
  }


}

/// Result of a successfully parsed packet.
class ParsedPacket {
  final int cmd;
  final Uint8List payload;
  const ParsedPacket({required this.cmd, required this.payload});

  @override
  String toString() =>
      'ParsedPacket(cmd=0x${cmd.toRadixString(16).padLeft(2, "0")}, '
      'payloadLen=${payload.length})';
}

/// Result of draining the receive buffer. Either a widget-protocol frame,
/// a 0xAA bulk-FS frame, or a 0xBB OTA frame.
class DrainResult {
  final String kind; // 'widget', 'fs', or 'ota'
  final ParsedPacket? widgetPacket;
  final ParsedFsPacket? fsPacket;
  final ParsedOtaPacket? otaPacket;
  final ParsedSettingsPacket? settingsPacket;
  const DrainResult.widget(ParsedPacket this.widgetPacket)
      : kind = 'widget', fsPacket = null, otaPacket = null, settingsPacket = null;
  const DrainResult.fs(ParsedFsPacket this.fsPacket)
      : kind = 'fs', widgetPacket = null, otaPacket = null, settingsPacket = null;
  const DrainResult.ota(ParsedOtaPacket this.otaPacket)
      : kind = 'ota', widgetPacket = null, fsPacket = null, settingsPacket = null;
  const DrainResult.settings(ParsedSettingsPacket this.settingsPacket)
      : kind = 'settings', widgetPacket = null, fsPacket = null, otaPacket = null;
}
