/// Protocol constants for the RadioKit binary protocol v3.0
library;

// BLE Service and Characteristic UUIDs
const String kRadioKitServiceUuid     = '0000FFE0-0000-1000-8000-00805F9B34FB';
const String kRadioKitCharWidgetUuid  = '0000FFE1-0000-1000-8000-00805F9B34FB';  // Widget protocol (0x55)
const String kRadioKitCharFsUuid      = '0000FFE2-0000-1000-8000-00805F9B34FB';  // FS protocol (0xAA)
const String kRadioKitCharOtaUuid     = '0000FFE3-0000-1000-8000-00805F9B34FB';  // OTA protocol (0xBB)

// Packet framing
const int kStartByte = 0x55;

// Command identifiers  (must match RadioKitProtocol.h exactly)
const int kCmdGetConf     = 0x01;
const int kCmdConfData    = 0x02;
const int kCmdPing        = 0x03;
const int kCmdPong        = 0x04;
const int kCmdAck         = 0x05;
const int kCmdGetVars     = 0x06;
const int kCmdVarData     = 0x07;
const int kCmdVarUpdate   = 0x08;
const int kCmdGetMeta     = 0x09;
const int kCmdMetaData    = 0x0A;
const int kCmdMetaUpdate  = 0x0B;
const int kCmdSetInput    = 0x0C;
const int kCmdGetTelemetry = 0x0D;
const int kCmdTelemetryData = 0x0E;
const int kCmdBleInfo = 0x14;
const int kCmdBleInfoData = 0x0F;
const int kCmdGetFeatures = 0x15;
const int kCmdFeaturesData = 0x16;
const int kCmdGetChipInfo = 0x17;
const int kCmdChipInfoData = 0x18;
const int kCmdSetConf = 0x19;
const int kCmdPwdAuth = 0x1A;
const int kCmdFactoryReset = 0x1B;

// ── NVS SET_CONF field mask bits ────────────────────────────────────────────
const int kSetConfName = 1 << 0;
const int kSetConfDesc = 1 << 1;
const int kSetConfPwd  = 1 << 2;
const int kSetConfAdminPwd = 1 << 3;
const int kSetConfError = 1 << 7;

// ── PWD_AUTH response codes ─────────────────────────────────────────────────
const int kPwdAuthOk       = 0x00;
const int kPwdAuthMismatch = 0x01;
const int kPwdAuthAlready  = 0x02;

// ── Feature bitmask bits (FEATURES_DATA payload) ──────────────────────────
const int kFeatureOta = 1 << 0;
const int kFeatureFilesystem = 1 << 1;
const int kFeatureHasConnPassword = 1 << 2;
const int kFeatureHasAdminPassword = 1 << 3;

// Legacy alias
const int kFeatureHasPassword = kFeatureHasConnPassword;

// ── PWD_AUTH flags byte ─────────────────────────────────────────────────────
const int kPwdAuthFlagAdmin = 1 << 0;

// ── NVS config limits (must match RadioKitConfig.h) ─────────────────────────
const int kMaxConfigName = 32;
const int kMaxConfigDesc = 128;
const int kMaxConfigPwd  = 32;

// ── OTA protocol constants ─────────────────────────────────────────────────
const int kOtaStartByte = 0xBB;
const int kOtaHeaderSize = 4;
const int kOtaMaxPayload = 4096;

// OTA sub-commands (App → MCU)
const int kOtaCmdBegin = 0x01;
const int kOtaCmdChunk = 0x02;
const int kOtaCmdEnd   = 0x03;
const int kOtaCmdAbort = 0x04;

// OTA sub-commands (MCU → App)
const int kOtaRespAck      = 0x81;
const int kOtaRespProgress = 0x82;

// OTA error codes
const int kOtaErrOk           = 0x00;
const int kOtaErrNoSpace      = 0x01;
const int kOtaErrCrc          = 0x02;
const int kOtaErrFlash        = 0x03;
const int kOtaErrSeq          = 0x04;
const int kOtaErrInvalidState = 0x05;
const int kOtaErrNotSupported = 0x06;

String otaErrorName(int code) {
  switch (code) {
    case kOtaErrOk:           return 'OK';
    case kOtaErrNoSpace:      return 'NO_SPACE';
    case kOtaErrCrc:          return 'CRC_MISMATCH';
    case kOtaErrFlash:        return 'FLASH_ERROR';
    case kOtaErrSeq:          return 'SEQ_ERROR';
    case kOtaErrInvalidState: return 'INVALID_STATE';
    case kOtaErrNotSupported: return 'NOT_SUPPORTED';
    default:                  return 'UNKNOWN';
  }
}

// ── Filesystem bulk protocol ─────────────────────────────────────────────────
// Uses a different start byte (0xAA) and has its own sub-command namespace.
// Sub-commands are NOT in the 0x55 command table — see FsProtocolService.

const int kFsStartByte = 0xAA;
const int kFsHeaderSize = 4; // START(1) + SUB_CMD(1) + LEN_LO(1) + LEN_HI(1)
const int kFsMaxPayload = 16384;

// App → MCU sub-commands
const int kFsCmdList          = 0x01;
const int kFsCmdRead          = 0x02;
const int kFsCmdWrite         = 0x03;
const int kFsCmdDelete        = 0x04;
const int kFsCmdInfo          = 0x05;
const int kFsCmdMkdir         = 0x06;
const int kFsCmdRename        = 0x07;
const int kFsCmdUploadBegin   = 0x08;
const int kFsCmdUploadChunk   = 0x09;
const int kFsCmdUploadEnd     = 0x0A;
const int kFsCmdPing          = 0x0B;
const int kFsCmdFormat        = 0x0C;

// MCU → App sub-commands
const int kFsRespListData         = 0x81;
const int kFsRespReadData         = 0x82;
const int kFsRespWriteAck         = 0x83;
const int kFsRespDeleteAck        = 0x84;
const int kFsRespInfoData         = 0x85;
const int kFsRespMkdirAck         = 0x86;
const int kFsRespRenameAck        = 0x87;
const int kFsRespUploadBeginAck   = 0x88;
const int kFsRespUploadChunkAck   = 0x89;
const int kFsRespUploadEndAck     = 0x8A;
const int kFsRespPingAck          = 0x8B;
const int kFsRespFormatAck        = 0x8C;

// FS error codes (single byte returned in *Ack frames)
const int kFsErrOk             = 0x00;
const int kFsErrNotFound       = 0x01;
const int kFsErrIo             = 0x02;
const int kFsErrNoFs           = 0x03;
const int kFsErrAccessDenied   = 0x04;
const int kFsErrInvalidPath    = 0x05;
const int kFsErrOutOfSpace     = 0x06;
const int kFsErrInvalidState   = 0x07;

// File type flags (in LIST_DATA entries)
const int kFsTypeFile = 0x00;
const int kFsTypeDir  = 0x01;

String fsErrorName(int code) {
  switch (code) {
    case kFsErrOk:           return 'OK';
    case kFsErrNotFound:     return 'NOT_FOUND';
    case kFsErrIo:           return 'IO_ERROR';
    case kFsErrNoFs:         return 'NO_FS';
    case kFsErrAccessDenied: return 'ACCESS_DENIED';
    case kFsErrInvalidPath:  return 'INVALID_PATH';
    case kFsErrOutOfSpace:   return 'OUT_OF_SPACE';
    case kFsErrInvalidState: return 'INVALID_STATE';
    default:                 return 'UNKNOWN';
  }
}

// Widget type identifiers
const int kWidgetButton      = 0x01;
const int kWidgetSwitch      = 0x02;
const int kWidgetSlider      = 0x03;
const int kWidgetJoystick    = 0x04;
const int kWidgetLed         = 0x05;
const int kWidgetText        = 0x06;
const int kWidgetMultiple    = 0x07;
const int kWidgetSlideSwitch = 0x08;
const int kWidgetKnob        = 0x09;

// Widget input sizes in bytes (app → device)
const Map<int, int> kWidgetInputSize = {
  kWidgetButton:      1,
  kWidgetSwitch:      1,
  kWidgetSlider:      1,
  kWidgetJoystick:    2,
  kWidgetLed:         0,
  kWidgetText:        0,
  kWidgetMultiple:    1,
  kWidgetSlideSwitch: 1,
  kWidgetKnob:        1,
};

// Widget output sizes in bytes (device → app)
// LED v3: 5 bytes — STATE(1) R(1) G(1) B(1) OPACITY(1)
const Map<int, int> kWidgetOutputSize = {
  kWidgetButton:      0,
  kWidgetSwitch:      0,
  kWidgetSlider:      0,
  kWidgetJoystick:    0,
  kWidgetLed:         5,
  kWidgetText:        32,
  kWidgetMultiple:    0,
  kWidgetSlideSwitch: 0,
  kWidgetKnob:        0,
};

// Protocol version (v4 — NVS-backed config)
const int kProtocolVersion = 0x04;
const int kProtocolVersionV3 = 0x03;
const int kProtocolVersionV4 = 0x04;

// Orientation wire values
const int kOrientationLandscape = 0x00;
const int kOrientationPortrait  = 0x01;

// Virtual canvas dimensions per orientation
const double kCanvasLandscapeW = 200.0;
const double kCanvasLandscapeH = 100.0;
const double kCanvasPortraitW  = 100.0;
const double kCanvasPortraitH  = 200.0;

// Poll intervals
const Duration kPingInterval    = Duration(seconds: 1);
const Duration kTelemetryInterval = Duration(seconds: 5);
// Increased to 8 s to handle slow USB CDC enumeration on some boards
const Duration kConfTimeout     = Duration(seconds: 8);

// VAR_UPDATE reliability (v3)
const int kVarUpdateTimeoutMs  = 200;
const int kVarUpdateMaxRetries = 5;

// Theme is now string-based (e.g. "default", "retro")

// ── Self-centering modes (Slider / Knob variant bits [1:0]) ────────────────────
const int kCenterNone  = 0; ///< No spring return
const int kCenterMin   = 1; ///< Springs to −100
const int kCenterMid   = 2; ///< Springs to 0
const int kCenterMax   = 3; ///< Springs to +100

/// Extract centering mode from variant byte (bits [1:0]).
int variantCentering(int variant) => variant & 0x03;

/// Extract detent count from variant byte (bits [6:2]).
int variantDetents(int variant) => (variant >> 2) & 0x1F;

/// Extract alternate visual shape from variant byte (bit 7).
bool variantIsAlternateShape(int variant) => (variant & 0x80) != 0;

/// Snap a signed value (-100..100) to the nearest detent position.
/// Returns [val] unchanged when [detents] <= 1.
int snapToDetents(int val, int detents) {
  if (detents <= 1) return val;
  final step = 200.0 / (detents - 1);
  final idx = ((val + 100) / step).round();
  return (-100 + idx * step).round().clamp(-100, 100);
}

// ── Style / variant IDs ───────────────────────────────────────────────────
const int kStyleDefault = 0;
const int kStylePrimary = 1;
const int kStyleDim     = 2;
const int kStyleSuccess = 3;
const int kStyleWarning = 4;
const int kStyleDanger  = 5;

// ── String bitmask bits ───────────────────────────────────────────────────
const int kStrMaskLabel   = 0x01;
const int kStrMaskIcon    = 0x02;
const int kStrMaskOnText  = 0x04;
const int kStrMaskOffText = 0x08;
const int kStrMaskContent = 0x10;
const int kStrMaskExtra   = 0x20;
const int kStrMaskLabelHidden = 0x40;

// Widget type name for display
String widgetTypeName(int typeId) {
  switch (typeId) {
    case kWidgetButton:      return 'Button';
    case kWidgetSwitch:      return 'Switch';
    case kWidgetSlider:      return 'Slider';
    case kWidgetJoystick:    return 'Joystick';
    case kWidgetLed:         return 'LED';
    case kWidgetText:        return 'Text';
    case kWidgetMultiple:    return 'Multiple';
    case kWidgetSlideSwitch: return 'SlideSwitch';
    case kWidgetKnob:        return 'Knob';
    default:                 return 'Unknown';
  }
}

/// Returns a human-readable name for a widget variant.
String widgetVariantName(int typeId, int variant) {
  switch (typeId) {
    case kWidgetButton:
      return variant == 1 ? 'Toggle' : '';
    case kWidgetMultiple:
      return variant == 1 ? 'Bitmask' : 'Index';
  }

  // Common logic for centering/detents (Slider, Knob, Joystick)
  if (typeId == kWidgetSlider || typeId == kWidgetKnob || typeId == kWidgetJoystick) {
    final center = variantCentering(variant);
    final detents = variantDetents(variant);
    final isAlt = variantIsAlternateShape(variant);
    
    final parts = <String>[];
    
    if (isAlt) {
      if (typeId == kWidgetSlider) {
        parts.add('GasPedal');
      } else if (typeId == kWidgetKnob) {
        parts.add('Steering');
      } else {
        parts.add('Alt');
      }
    }

    if (center != kCenterNone) {
      if (center == kCenterMin) {
        parts.add('Min');
      } else if (center == kCenterMid) {
        parts.add('Mid');
      } else if (center == kCenterMax) {
        parts.add('Max');
      }
    }
    if (detents > 1) {
      parts.add('D$detents');
    }
    
    if (parts.isEmpty) {
      return variant == 0 ? '' : 'V:$variant';
    }
    return parts.join('+');
  }

  return variant == 0 ? '' : 'V:$variant';
}
