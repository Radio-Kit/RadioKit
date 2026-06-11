/// Protocol constants for the RadioKit binary protocol v3.0
library;

// BLE Service and Characteristic UUIDs
const String kRadioKitServiceUuid     = '0000FFE0-0000-1000-8000-00805F9B34FB';
const String kRadioKitCharWidgetUuid  = '0000FFE1-0000-1000-8000-00805F9B34FB';  // Widget protocol (0x55)
const String kRadioKitCharFsUuid      = '0000FFE2-0000-1000-8000-00805F9B34FB';  // FS protocol (0xAA)
const String kRadioKitCharOtaUuid     = '0000FFE3-0000-1000-8000-00805F9B34FB';  // OTA protocol (0xBB)
const String kRadioKitCharSettingsUuid = '0000FFE4-0000-1000-8000-00805F9B34FB';  // Settings protocol (0xDD)

// Packet framing
const int kStartByte = 0x55;

// Command identifiers  (must match RadioKitProtocol.h exactly)
const int kCmdGetConf     = 0x01;
const int kCmdConfData    = 0x02;
// kCmdPing/kCmdPong were 0x03/0x04 — removed; connection health is transport-driven.
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
const int kCmdGetWifiInfo = 0x1D;
const int kCmdWifiInfoData = 0x1E;

// ── NVS SET_CONF field mask bits ────────────────────────────────────────────
const int kSetConfName       = 1 << 0;
const int kSetConfDesc       = 1 << 1;
const int kSetConfDevicePwd  = 1 << 2;  // Device password (was kSetConfPwd)
const int kSetConfUserPwd    = 1 << 3;  // User password (was kSetConfAdminPwd)
const int kSetConfError      = 1 << 7;

// Legacy aliases for backward compatibility during migration
const int kSetConfPwd = kSetConfDevicePwd;
const int kSetConfAdminPwd = kSetConfUserPwd;

// ── PWD_AUTH response codes (new single-auth model) ─────────────────────────
const int kPwdAuthDevice  = 0x00;   ///< Authenticated as device (full access)
const int kPwdAuthUser    = 0x01;   ///< Authenticated as user (widgets-only)
const int kPwdAuthDenied  = 0x02;   ///< Password did not match

// ── Feature bitmask bits (FEATURES_DATA payload) ──────────────────────────
const int kFeatureOta = 1 << 0;
const int kFeatureFilesystem = 1 << 1;
const int kFeatureHasDevicePassword = 1 << 2;  // Device password set
const int kFeatureHasUserPassword   = 1 << 3;  // User password set
const int kFeatureWiFi = 1 << 4;
const int kFeatureCloud = 1 << 5;

// Legacy alias
const int kFeatureHasPassword = kFeatureHasDevicePassword;
const int kFeatureHasConnPassword = kFeatureHasDevicePassword;
const int kFeatureHasAdminPassword = kFeatureHasUserPassword;

// ── PWD_AUTH flags byte (deprecated, kept for old firmware) ─────────────────
const int kPwdAuthFlagAdmin = 1 << 0;

// ── SET_WIFI field mask bits (settings protocol 0xDD) ─────────────────────
const int kSettingsSetWifiSsid = 1 << 0;
const int kSettingsSetWifiPwd = 1 << 1;

// WiFi mode values
const int kWifiModeSta = 0x00;
const int kWifiModeAp = 0x01;

// WiFi max string lengths
const int kMaxWifiSsid = 32;
const int kMaxWifiPwd = 64;

// Default WebSocket port
const int kDefaultWifiPort = 5555;

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
const int kOtaCmdSetEraseFlag = 0x05;

// OTA sub-commands (MCU → App)
const int kOtaRespAck      = 0x81;
const int kOtaRespProgress = 0x82;

// ── Settings protocol (0xDD) ────────────────────────────────────────────────
const int kSettingsStartByte = 0xDD;
const int kSettingsHeaderSize = 4; // START(1) + SUB_CMD(1) + LEN_LO(1) + LEN_HI(1)
const int kSettingsMaxPayload = 1024;

// App → MCU sub-commands
const int kSettingsCmdGetTelemetry   = 0x01;
const int kSettingsCmdBleInfo        = 0x02;
const int kSettingsCmdGetFeatures    = 0x03;
const int kSettingsCmdGetChipInfo    = 0x04;
const int kSettingsCmdSetConf        = 0x05;
const int kSettingsCmdPwdAuth        = 0x06;
const int kSettingsCmdFactoryReset   = 0x07;
const int kSettingsCmdGetDeviceInfo  = 0x08;
const int kSettingsCmdNvsRawRead     = 0x09;
const int kSettingsCmdNvsRawWrite    = 0x0A;
const int kSettingsCmdSetWifi        = 0x0B;
const int kSettingsCmdGetCloudInfo   = 0x0C;
const int kSettingsCmdReboot          = 0x0D;

// MCU → App sub-commands (response = request | 0x80)
const int kSettingsRespTelemetryData      = 0x81;
const int kSettingsRespBleInfoData        = 0x82;
const int kSettingsRespFeaturesData       = 0x83;
const int kSettingsRespChipInfoData       = 0x84;
const int kSettingsRespSetConfAck         = 0x85;
const int kSettingsRespPwdAuthAck         = 0x86;
const int kSettingsRespFactoryResetAck    = 0x87;
const int kSettingsRespDeviceInfoData     = 0x88;
const int kSettingsRespNvsRawReadData     = 0x89;
const int kSettingsRespNvsRawWriteAck     = 0x8A;
const int kSettingsRespSetWifiAck          = 0x8B;
const int kSettingsRespCloudInfoData       = 0x8C;
const int kSettingsRespRebootAck           = 0x8D;

// NVS raw read/write status codes
const int kSettingsNvsRawOk    = 0x00;
const int kSettingsNvsRawError = 0x01;

// PWD_AUTH status codes (new single-auth model)
const int kSettingsPwdDevice  = 0x00;  ///< Authenticated as device
const int kSettingsPwdUser    = 0x01;  ///< Authenticated as user
const int kSettingsPwdDenied  = 0x02;  ///< Password did not match

// Legacy aliases
const int kSettingsPwdOk       = kSettingsPwdDevice;
const int kSettingsPwdMismatch = kSettingsPwdDenied;
const int kSettingsPwdAlready  = kSettingsPwdDevice;

// PWD_AUTH flags (deprecated)
const int kSettingsPwdAuthFlagAdmin = 1 << 0;

// SET_CONF field mask bits
const int kSettingsSetConfName      = 1 << 0;
const int kSettingsSetConfDesc      = 1 << 1;
const int kSettingsSetConfDevicePwd = 1 << 2;  // Device password
const int kSettingsSetConfUserPwd   = 1 << 3;  // User password
const int kSettingsSetConfError     = 1 << 7;

// Legacy aliases
const int kSettingsSetConfPwd = kSettingsSetConfDevicePwd;
const int kSettingsSetConfAdminPwd = kSettingsSetConfUserPwd;

// Feature bitmask bits
const int kSettingsFeatureOta           = 1 << 0;
const int kSettingsFeatureFilesystem    = 1 << 1;
const int kSettingsFeatureHasDevicePwd  = 1 << 2;  // Device password set
const int kSettingsFeatureHasUserPwd    = 1 << 3;  // User password set
const int kSettingsFeatureWiFi          = 1 << 4;
const int kSettingsFeatureCloud         = 1 << 5;

// Legacy aliases
const int kSettingsFeatureHasConnPwd  = kSettingsFeatureHasDevicePwd;
const int kSettingsFeatureHasAdminPwd = kSettingsFeatureHasUserPwd;

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
const int kFsCmdFormat        = 0x0C;
const int kFsCmdReplace       = 0x0D;
const int kFsCmdCrc32         = 0x0E;

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
const int kFsRespFormatAck        = 0x8C;
const int kFsRespReplaceAck      = 0x8D;
const int kFsRespCrc32Data       = 0x8E;

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
const int kProtocolVersion = 0x05;
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
