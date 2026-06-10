/**
 * RadioKit.cpp
 * OOP widget registry, protocol dispatch, serialization (v2.0 / Protocol v3).
 */

#include "RadioKitLib.h"
#include "connection/RadioKitFsHandlers.h"
#include "connection/RadioKitOTA.h"
#include <string.h>

// ── OTA support (ESP32 Update.h + esp_ota_ops) ──────────────────────────────
#if defined(ESP32)
#include <Update.h>
#include <esp_ota_ops.h>
#define RK_HAS_OTA 1
#else
#define RK_HAS_OTA 0
#endif

// ── Debug logging (enabled by default for debugging) ────────────────────
// Set to 1 to enable verbose debug output
#define RK_DEBUG_VERBOSE 0

#if RK_DEBUG_VERBOSE
#define RK_DEBUG_PRINT(fmt, ...) Serial.printf(fmt, ##__VA_ARGS__)
#else
#define RK_DEBUG_PRINT(fmt, ...)
#endif

// ── CONF_DATA / META_DATA payload buffer sizes ──────────────────────────
#define RK_STR_BUF_SIZE 640

RadioKitClass RadioKit;
static RadioKitClass* s_instance = nullptr;

// Forward-declared in Widget.cpp
extern void RadioKit_Widget_drainDeferred();

RadioKitClass::RadioKitClass()
    : _widgetCount(0)
    , _transport(nullptr)
    , _pendingUpdatesMask(0)
    , _varUpdateSeq(0)
    , _pendingMetaMask(0)
    , _metaUpdateSeq(0)
    , _nvsActive(false)
    , _wifiActive(false)
    , _cloudActive(false)
    , _authenticated(false)
    , _authenticatedAdmin(false)
{
    memset(_widgets, 0, sizeof(_widgets));
    memset(_txBuf,   0, sizeof(_txBuf));
    memset(_shadowInput, 0, sizeof(_shadowInput));
    memset(_nvsName, 0, sizeof(_nvsName));
    memset(_nvsDesc, 0, sizeof(_nvsDesc));
    memset(_nvsPwd,  0, sizeof(_nvsPwd));
    memset(_nvsAdminPwd, 0, sizeof(_nvsAdminPwd));
    memset(_nvsStaSsid, 0, sizeof(_nvsStaSsid));
    memset(_nvsStaPwd, 0, sizeof(_nvsStaPwd));
    memset(_nvsCloudUrl, 0, sizeof(_nvsCloudUrl));
    memset(_nvsCloudAccount, 0, sizeof(_nvsCloudAccount));
    s_instance = this;
}

void RadioKitClass::_registerWidget(RadioKit_Widget* widget) {
    if (_widgetCount >= RADIOKIT_MAX_WIDGETS) return;
    widget->widgetId = _widgetCount;
    _widgets[_widgetCount++] = widget;
}

void RadioKitClass::begin() {
    RadioKit_Widget_drainDeferred();
    // Auto-mount the FS. The handler namespace is a no-op when LittleFS
    // is unavailable, in which case all FS commands reply with NO_FS.
    RKFs::setSender(&RadioKitClass::_sendFsFrame);
    rk_fsSetCallback(&RadioKitClass::_onFsPacket);
    RKFs::begin();

    // ── Initialise NVS and load config ──────────────────────────────
    _nvsActive = RKNvs::init();

    if (_nvsActive) {
        // ── Check for deferred erase from OTA ──────────────────────
        // The rk_pend_erase key is written to NVS before an OTA update
        // with erase. NVS is a separate flash partition from the app
        // partition (ota_0/ota_1), so it survives OTA and esp_restart().
        // If non-zero, we perform the requested erase, then reboot to
        // let the new firmware boot with empty NVS (which will populate
        // compile-time defaults on first boot).
        uint8_t pendingErase = 0;
        if (RKNvs::readU8(RK_NVS_KEY_PENDING_ERASE, &pendingErase) &&
            pendingErase != RK_PENDING_ERASE_NONE) {
            Serial.printf("BOOT: Pending erase flag=%d — performing erase...\n", pendingErase);

            if (pendingErase == RK_PENDING_ERASE_BOTH || pendingErase == RK_PENDING_ERASE_NVS) {
                Serial.println("BOOT: Erasing NVS config...");
                RKNvs::eraseAll();
                RKNvs::commit();
            }

            if (pendingErase == RK_PENDING_ERASE_BOTH || pendingErase == RK_PENDING_ERASE_FS) {
                Serial.println("BOOT: Formatting LittleFS...");
                RKFs::format();
            }

            // Clear the flag so we don't loop on next boot
            RKNvs::eraseKey(RK_NVS_KEY_PENDING_ERASE);
            RKNvs::commit();

            Serial.println("BOOT: Erase complete — rebooting...");
            delay(100);
            esp_restart();
        }

        // Check if NVS already has our config keys
        char testName[RADIOKIT_MAX_NAME + 1];
        bool hasExisting = RKNvs::readString(RK_NVS_KEY_NAME, testName, sizeof(testName));

        if (!hasExisting) {
            // First boot — write compile-time defaults to NVS
            RKNvs::writeString(RK_NVS_KEY_NAME, config.name ? config.name : "");
            RKNvs::writeString(RK_NVS_KEY_DESC, config.description ? config.description : "");
            RKNvs::writeString(RK_NVS_KEY_PWD,  config.password ? config.password : "");
            RKNvs::writeString(RK_NVS_KEY_STA_SSID, config.sta_ssid ? config.sta_ssid : "");
            RKNvs::writeString(RK_NVS_KEY_STA_PWD, config.sta_password ? config.sta_password : "");
            RKNvs::writeString(RK_NVS_KEY_CLOUD_URL, config.cloud_url ? config.cloud_url : "");
            RKNvs::writeString(RK_NVS_KEY_CLOUD_ACCOUNT, config.cloud_account ? config.cloud_account : "");
            RKNvs::commit();
        }

        // Load NVS values into internal buffers (these override RK_Config)
        _syncNvsToBuffers();
    } else {
        // NVS not available — copy compile-time defaults as fallback
        strncpy(_nvsName, config.name ? config.name : "", sizeof(_nvsName) - 1);
        strncpy(_nvsDesc, config.description ? config.description : "", sizeof(_nvsDesc) - 1);
        strncpy(_nvsPwd,  config.password ? config.password : "", sizeof(_nvsPwd) - 1);
        _nvsAdminPwd[0] = '\0';
        memset(_nvsStaSsid, 0, sizeof(_nvsStaSsid));
        memset(_nvsStaPwd, 0, sizeof(_nvsStaPwd));
        memset(_nvsCloudUrl, 0, sizeof(_nvsCloudUrl));
        memset(_nvsCloudAccount, 0, sizeof(_nvsCloudAccount));
    }

    // Reset auth state on boot
    // If no passwords set → pre-authenticated as both user and admin
    // If no connection pwd but admin pwd set → pre-authenticated as user, not admin
    _authenticated = (_nvsPwd[0] == '\0');       // No connection pwd = pre-authenticated user
    _authenticatedAdmin = (_nvsAdminPwd[0] == '\0');  // No admin pwd = pre-authenticated admin
}

void RadioKitClass::pushUpdate(uint8_t widgetId) {
    if (widgetId < _widgetCount && widgetId < 32) {
        _pendingUpdatesMask |= (1UL << widgetId);
    }
}

void RadioKitClass::pushMetaUpdate(uint8_t widgetId) {
    if (widgetId < _widgetCount && widgetId < 32) {
        _pendingMetaMask |= (1UL << widgetId);
    }
}

void RadioKitClass::startBLE(const char* deviceName) {
    // Use NVS-backed name if available, else fall back to provided name or config.name
    const char* baseName;
    if (_nvsActive && _nvsName[0] != '\0') {
        baseName = _nvsName;
    } else if (deviceName && deviceName[0] != '\0') {
        baseName = deviceName;
    } else {
        baseName = config.name;
    }
    // Prefix "RK_" to the BLE broadcast name so the app can reliably filter
    // by name prefix. The config.name (without prefix) is sent in CONF_DATA
    // and displayed in the app UI.
    static char bleAdvName[RADIOKIT_MAX_NAME + 4]; // 3 for "RK_" + null
    snprintf(bleAdvName, sizeof(bleAdvName), "RK_%s", baseName ? baseName : "RadioKit");
    _transport = &RadioKitBLEInstance;
    _transport->begin(bleAdvName, RadioKitClass::_onPacket);
    _transport->setFsCallback(RadioKitClass::_onFsPacket);
    rk_otaSetCallback(RadioKitClass::_onOtaPacket);
    _transport->setOtaCallback(RadioKitClass::_onOtaPacket);
    rk_settingsSetCallback(RadioKitClass::_onSettingsPacket);
    _transport->setSettingsCallback(RadioKitClass::_onSettingsPacket);
}

void RadioKitClass::startSerial(Stream& stream) {
    _transport = &RadioKitSerialInstance;
    RadioKitSerialInstance.begin(stream, RadioKitClass::_onPacket);
    RadioKitSerialInstance.setFsCallback(RadioKitClass::_onFsPacket);
    rk_otaSetCallback(RadioKitClass::_onOtaPacket);
    RadioKitSerialInstance.setOtaCallback(RadioKitClass::_onOtaPacket);
    rk_settingsSetCallback(RadioKitClass::_onSettingsPacket);
    RadioKitSerialInstance.setSettingsCallback(RadioKitClass::_onSettingsPacket);
}

void RadioKitClass::startWiFi() {
#if defined(ESP32)
    const char* baseName = (_nvsActive && _nvsName[0]) ? _nvsName :
                           (config.name ? config.name : "RadioKit");

    // Pass NVS-stored credentials to the WiFi transport
    RadioKitWiFiInstance.setCredentials(_nvsStaSsid, _nvsStaPwd);
    RadioKitWiFiInstance.setApPassword(_nvsActive && _nvsPwd[0] ? _nvsPwd : nullptr);

    // Register all callbacks
    RadioKitWiFiInstance.begin(baseName, RadioKitClass::_onPacket);
    RadioKitWiFiInstance.setFsCallback(RadioKitClass::_onFsPacket);
    rk_otaSetCallback(RadioKitClass::_onOtaPacket);
    RadioKitWiFiInstance.setOtaCallback(RadioKitClass::_onOtaPacket);
    rk_settingsSetCallback(RadioKitClass::_onSettingsPacket);
    RadioKitWiFiInstance.setSettingsCallback(RadioKitClass::_onSettingsPacket);

    _wifiActive = true;
    Serial.println("WiFi: Transport started");
#else
    Serial.println("WiFi: Transport not available on this platform");
#endif
}

void RadioKitClass::startCloud() {
    if (!_wifiActive) {
        Serial.println("Cloud: startWiFi() must be called before startCloud() — ignoring");
        return;
    }
    Serial.println("Cloud: Transport not yet implemented (Phase 4)");
    // _cloudActive = true;  // Uncomment in Phase 4
}

void RadioKitClass::update() {
    // Poll existing primary transport (BLE or Serial)
    if (_transport) _transport->update();

    // Poll WiFi transport (priority: WiFi first)
    if (_wifiActive) RadioKitWiFiInstance.update();

    // Poll Cloud transport (lower priority)
    if (_cloudActive) RadioKitCloudInstance.update();

    // Track connection state — reset auth on all-transport disconnect
    static bool s_lastConnected = false;
    bool nowConnected = isConnected();
    if (s_lastConnected && !nowConnected) {
        // All transports disconnected — reset auth
        _authenticated = (_nvsPwd[0] == '\0');
        _authenticatedAdmin = (_nvsAdminPwd[0] == '\0');
    }
    s_lastConnected = nowConnected;

    if (isConnected()) {
        for (uint8_t i = 0; i < _widgetCount; i++) {
            RadioKit_Widget* w = _widgets[i];
            uint8_t inSz = w->inputSize();
            if (inSz > 0 && inSz <= 4) {
                uint8_t currentBuf[4] = {0};
                w->serializeInput(currentBuf);
                bool match = (memcmp(currentBuf, _shadowInput[i], inSz) == 0);
                if (!match) {
                    RK_DEBUG_PRINT("[DBG]   -> shadow MISMATCH for widget %d! Updating and pushing\n", i);
                    memcpy(_shadowInput[i], currentBuf, inSz);
                    pushUpdate(i);
                }
            }
        }
    }

    // ── Batch-fire all pending VAR_UPDATE / SET_INPUT ─────────────
    if (_pendingUpdatesMask != 0 && isConnected()) {
        for (uint8_t i = 0; i < 32; i++) {
            if (_pendingUpdatesMask & (1UL << i)) {
                RadioKit_Widget* w = _widgets[i];
                uint8_t inSz = w->inputSize();
                uint8_t outSz = w->outputSize();
                uint8_t dataSz = inSz > 0 ? inSz : outSz;
                if (dataSz == 0) continue;

                uint8_t payload[2 + dataSz];
                payload[0] = i;
                payload[1] = ++_varUpdateSeq;
                uint8_t cmd;
                if (inSz > 0) {
                    w->serializeInput(&payload[2]);
                    cmd = RK_CMD_SET_INPUT;
                } else {
                    w->serializeOutput(&payload[2]);
                    cmd = RK_CMD_VAR_UPDATE;
                }
                uint8_t pktBuf[RK_MAX_PACKET_SIZE];
                uint16_t pktLen = rk_buildPacket(pktBuf, cmd, payload, 2 + dataSz);
                _sendPacket(pktBuf, pktLen);
            }
        }
        _pendingUpdatesMask = 0;
    }

    // ── Batch-fire all pending META_UPDATE ────────────────────────
    if (_pendingMetaMask != 0 && isConnected()) {
        for (uint8_t i = 0; i < 32; i++) {
            if (_pendingMetaMask & (1UL << i)) {
                RadioKit_Widget* w = _widgets[i];
                uint8_t pktBuf[RK_MAX_PACKET_SIZE];
                uint8_t payload[2 + RK_STR_BUF_SIZE];
                payload[0] = i;
                payload[1] = ++_metaUpdateSeq;
                uint16_t strLen = w->serializeStrings(&payload[2]);
                uint16_t pktLen = rk_buildPacket(pktBuf, RK_CMD_META_UPDATE, payload, 2 + strLen);
                _sendPacket(pktBuf, pktLen);
            }
        }
        _pendingMetaMask = 0;
    }
}

bool RadioKitClass::isConnected() const {
    if (_transport && _transport->isConnected()) return true;
    if (_wifiActive && RadioKitWiFiInstance.isConnected()) return true;
    if (_cloudActive && RadioKitCloudInstance.isConnected()) return true;
    return false;
}

void RadioKitClass::_onPacket(uint8_t cmd,
                              const uint8_t* payload,
                              uint16_t payloadLen)
{
    if (!s_instance) return;

    // ── Auth gate (minimal — settings/auth moved to 0xDD) ─────────────
    // Only widget commands live here now. Unauthenticated clients can
    // GET_CONF (to display UI). Auth is gated in the Settings protocol.
    bool isUserAuthd = s_instance->_authenticated || s_instance->_nvsPwd[0] == '\0';
    if (!isUserAuthd && cmd != RK_CMD_GET_CONF) {
        Serial.printf("RK: Rejected CMD 0x%02X — not authenticated\n", cmd);
        uint8_t err = RK_SETTINGS_PWD_MISMATCH;
        uint16_t len = rk_buildPacket(s_instance->_txBuf, RK_CMD_ACK, &err, 1);
        s_instance->_sendPacket(len);
        return;
    }

    RK_DEBUG_PRINT("RK: Dispatching CMD %s (0x%02X), len %d\n", rk_cmdName(cmd), cmd, payloadLen);
    switch (cmd) {
        case RK_CMD_GET_CONF:   s_instance->_handleGetConf();                       break;
        case RK_CMD_GET_VARS:   s_instance->_handleGetVars();                       break;
        case RK_CMD_GET_META:   s_instance->_handleGetMeta();                       break;
        case RK_CMD_SET_INPUT:  s_instance->_handleSetInput(payload, payloadLen);   break;
        case RK_CMD_ACK:        s_instance->_handleAck(payload, payloadLen);        break;
        case RK_CMD_VAR_UPDATE: s_instance->_handleVarUpdate(payload, payloadLen);  break;
        case RK_CMD_META_UPDATE:s_instance->_handleMetaUpdate(payload, payloadLen); break;
        case RK_CMD_GET_WIFI_INFO: s_instance->_handleGetWifiInfo();                          break;
        default: 
            Serial.printf("RK: Unknown CMD %s (0x%02X)\n", rk_cmdName(cmd), cmd);
            break;
    }
}

// ── Settings protocol (0xDD) dispatch ───────────────────────────────────

void RadioKitClass::_onSettingsPacket(uint8_t subCmd,
                                      const uint8_t* payload,
                                      uint16_t payloadLen)
{
    if (!s_instance) return;

    // ── Auth gate (dual-auth) ────────────────────────────────────────
    bool isUserAuthd = s_instance->_authenticated || s_instance->_nvsPwd[0] == '\0';
    bool isAdminAuthd = s_instance->_authenticatedAdmin || s_instance->_nvsAdminPwd[0] == '\0';
    
    if (!isUserAuthd) {
        // Not authenticated: allow PWD_AUTH, GET_FEATURES, GET_DEVICE_INFO
        if (subCmd != RK_SETTINGS_CMD_PWD_AUTH &&
            subCmd != RK_SETTINGS_CMD_GET_FEATURES &&
            subCmd != RK_SETTINGS_CMD_GET_DEVICE_INFO) {
            Serial.printf("RK: Rejected SETTINGS 0x%02X — not authenticated\n", subCmd);
            uint8_t status = RK_SETTINGS_PWD_MISMATCH;
            uint8_t respSub = subCmd | 0x80;
            uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(), respSub, &status, 1);
            s_instance->_sendToAllTransports(rk_settingsTxBuf(), frameLen);
            return;
        }
    } else if (!isAdminAuthd) {
        // User-authenticated: block admin-only commands
        if (subCmd == RK_SETTINGS_CMD_SET_CONF || subCmd == RK_SETTINGS_CMD_FACTORY_RESET ||
            subCmd == RK_SETTINGS_CMD_NVS_RAW_WRITE || subCmd == RK_SETTINGS_CMD_SET_WIFI) {
            Serial.printf("RK: Rejected SETTINGS 0x%02X — admin required\n", subCmd);
            uint8_t status = RK_SETTINGS_PWD_MISMATCH;
            uint8_t respSub = subCmd | 0x80;
            uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(), respSub, &status, 1);
            s_instance->_sendToAllTransports(rk_settingsTxBuf(), frameLen);
            return;
        }
    }

    RK_DEBUG_PRINT("RK: Dispatching SETTINGS %s (0x%02X), len %d\n",
                   rk_settingsCmdName(subCmd), subCmd, payloadLen);
    switch (subCmd) {
        case RK_SETTINGS_CMD_GET_TELEMETRY:  s_instance->_handleSettingsTelemetry(payload, payloadLen);                break;
        case RK_SETTINGS_CMD_BLE_INFO:       s_instance->_handleSettingsBleInfo();                   break;
        case RK_SETTINGS_CMD_GET_FEATURES:   s_instance->_handleSettingsGetFeatures();              break;
        case RK_SETTINGS_CMD_GET_CHIP_INFO:  s_instance->_handleSettingsGetChipInfo();              break;
        case RK_SETTINGS_CMD_SET_CONF:       s_instance->_handleSettingsSetConf(payload, payloadLen); break;
        case RK_SETTINGS_CMD_PWD_AUTH:       s_instance->_handleSettingsPwdAuth(payload, payloadLen); break;
        case RK_SETTINGS_CMD_FACTORY_RESET:  s_instance->_handleSettingsFactoryReset();              break;
        case RK_SETTINGS_CMD_GET_DEVICE_INFO: s_instance->_handleSettingsDeviceInfo();               break;
        case RK_SETTINGS_CMD_NVS_RAW_READ:  s_instance->_handleSettingsNvsRawRead(payload, payloadLen); break;
        case RK_SETTINGS_CMD_NVS_RAW_WRITE: s_instance->_handleSettingsNvsRawWrite(payload, payloadLen); break;
        case RK_SETTINGS_CMD_SET_WIFI:      s_instance->_handleSettingsSetWifi(payload, payloadLen);      break;
        default:
            Serial.printf("RK: Unknown SETTINGS sub-command 0x%02X\n", subCmd);
            break;
    }
}

int8_t RadioKitClass::getRssi() {
    if (_transport && _transport->isConnected()) return _transport->getRssi();
    if (_wifiActive && RadioKitWiFiInstance.isConnected()) return RadioKitWiFiInstance.getRssi();
    return 0;
}

// ── Settings protocol handlers ─────────────────────────────────────────

void RadioKitClass::sendSettingsFrame(const uint8_t* buf, uint16_t len) {
    _sendToAllTransports(buf, len);
}

void RadioKitClass::_sendSettingsFrame(const uint8_t* buf, uint16_t len) {
    if (s_instance) s_instance->sendSettingsFrame(buf, len);
}

void RadioKitClass::_sendSettingsFrame(uint16_t len) {
    _sendToAllTransports(rk_settingsTxBuf(), len);
}

void RadioKitClass::_handleSettingsTelemetry(const uint8_t* payload, uint16_t payloadLen) {
    if (!_transport) return;
    uint8_t buf[4];
    int r = getRssi();
    buf[0] = (uint8_t)r;
    // Device-side latency: elapsed ms since the request frame was fully received.
    uint32_t rxTime = rk_settingsLastRxTimestamp();
    uint32_t elapsed = millis() - rxTime;
    buf[1] = (elapsed > 255) ? 255 : (uint8_t)elapsed;
    // Echo the app's 2-byte LE timestamp (bytes 0-1 of request) back in bytes 2-3
    // so the app can compute true round-trip time.
    if (payloadLen >= 2) {
        buf[2] = payload[0];
        buf[3] = payload[1];
    } else {
        buf[2] = 0;
        buf[3] = 0;
    }
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_TELEMETRY_DATA, buf, 4);
    _sendSettingsFrame(frameLen);
}

void RadioKitClass::_handleSettingsBleInfo() {
    if (!_transport) return;
    uint8_t payload[5];
    uint16_t interval = RadioKitBLEInstance.getConnIntervalMs();
    uint16_t mtu = RadioKitBLEInstance.getNegotiatedMtu();
    int r = getRssi();
    payload[0] = interval & 0xFF;
    payload[1] = (interval >> 8) & 0xFF;
    payload[2] = mtu & 0xFF;
    payload[3] = (mtu >> 8) & 0xFF;
    payload[4] = (uint8_t)r;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_BLE_INFO_DATA, payload, 5);
    _sendSettingsFrame(frameLen);
}

void RadioKitClass::_handleSettingsGetFeatures() {
    if (!_transport) return;
    uint8_t bitmask = 0;
#if RK_HAS_OTA
    bitmask |= RK_SETTINGS_FEATURE_OTA;
#endif
#if RK_FS_HAS_LITTLEFS
    bitmask |= RK_SETTINGS_FEATURE_FILESYSTEM;
#endif
    if (_nvsActive && _nvsPwd[0] != '\0') {
        bitmask |= RK_SETTINGS_FEATURE_HAS_CONN_PWD;
    }
    if (_nvsActive && _nvsAdminPwd[0] != '\0') {
        bitmask |= RK_SETTINGS_FEATURE_HAS_ADMIN_PWD;
    }
    if (_wifiActive) {
        bitmask |= RK_SETTINGS_FEATURE_WIFI;
    }
    if (_cloudActive) {
        bitmask |= RK_SETTINGS_FEATURE_CLOUD;
    }
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_FEATURES_DATA, &bitmask, 1);
    _sendSettingsFrame(frameLen);
}

void RadioKitClass::_handleSettingsGetChipInfo() {
#if defined(ESP32)
    uint8_t payload[64];
    uint16_t offset = 0;
    String modelStr = ESP.getChipModel();
    uint8_t modelLen = modelStr.length();
    if (modelLen > 20) modelLen = 20;
    payload[offset++] = modelLen;
    memcpy(&payload[offset], modelStr.c_str(), modelLen);
    offset += modelLen;
    payload[offset++] = ESP.getChipRevision();
    payload[offset++] = ESP.getChipCores();
    uint32_t flashSize = ESP.getFlashChipSize();
    payload[offset++] = flashSize & 0xFF;
    payload[offset++] = (flashSize >> 8) & 0xFF;
    payload[offset++] = (flashSize >> 16) & 0xFF;
    payload[offset++] = (flashSize >> 24) & 0xFF;
    uint32_t psramSize = ESP.getPsramSize();
    payload[offset++] = psramSize & 0xFF;
    payload[offset++] = (psramSize >> 8) & 0xFF;
    payload[offset++] = (psramSize >> 16) & 0xFF;
    payload[offset++] = (psramSize >> 24) & 0xFF;
    String sdkVer = ESP.getSdkVersion();
    uint8_t sdkLen = sdkVer.length();
    if (sdkLen > 30) sdkLen = 30;
    payload[offset++] = sdkLen;
    memcpy(&payload[offset], sdkVer.c_str(), sdkLen);
    offset += sdkLen;
    uint64_t macInt = ESP.getEfuseMac();
    uint8_t mac[6];
    mac[0] = (uint8_t)(macInt & 0xFF);
    mac[1] = (uint8_t)((macInt >> 8) & 0xFF);
    mac[2] = (uint8_t)((macInt >> 16) & 0xFF);
    mac[3] = (uint8_t)((macInt >> 24) & 0xFF);
    mac[4] = (uint8_t)((macInt >> 32) & 0xFF);
    mac[5] = (uint8_t)((macInt >> 40) & 0xFF);
    memcpy(&payload[offset], mac, 6);
    offset += 6;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_CHIP_INFO_DATA, payload, offset);
    _sendSettingsFrame(frameLen);
#else
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_CHIP_INFO_DATA, nullptr, 0);
    _sendSettingsFrame(frameLen);
#endif
}

void RadioKitClass::_handleSettingsDeviceInfo() {
    if (!_transport) return;
    // Payload: [PROTO_VER(1)][NAME_LEN(1)][NAME][DESC_LEN(1)][DESC]
    uint8_t buf[1 + 1 + RADIOKIT_MAX_NAME + 1 + RADIOKIT_MAX_DESC];
    uint16_t offset = 0;
    buf[offset++] = RK_PROTOCOL_VERSION;
    const char* name = _nvsActive && _nvsName[0] ? _nvsName : (config.name ? config.name : "");
    const char* desc = _nvsActive && _nvsDesc[0] ? _nvsDesc : (config.description ? config.description : "");
    uint8_t nameLen = (uint8_t)strnlen(name, RADIOKIT_MAX_NAME);
    uint8_t descLen = (uint8_t)strnlen(desc, RADIOKIT_MAX_DESC);
    buf[offset++] = nameLen;
    memcpy(&buf[offset], name, nameLen); offset += nameLen;
    buf[offset++] = descLen;
    memcpy(&buf[offset], desc, descLen); offset += descLen;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_DEVICE_INFO_DATA, buf, offset);
    _sendSettingsFrame(frameLen);
}

void RadioKitClass::_handleGetConf() {
    uint8_t* payloadPtr = &_txBuf[RK_HEADER_SIZE];
    uint16_t payloadLen = _buildConfPayload(payloadPtr,
                                            RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_CONF_DATA, payloadPtr, payloadLen);
    _sendPacket(totalLen);
}

void RadioKitClass::_handleGetVars() {
    uint16_t payloadLen = _buildVarPayload(&_txBuf[RK_HEADER_SIZE],
                                           RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_VAR_DATA, nullptr, payloadLen);
    _sendPacket(totalLen);
}

void RadioKitClass::_handleGetMeta() {
    uint16_t payloadLen = _buildMetaPayload(&_txBuf[RK_HEADER_SIZE],
                                            RK_MAX_PACKET_SIZE - RK_HEADER_SIZE - RK_CRC_SIZE);
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_META_DATA, nullptr, payloadLen);
    _sendPacket(totalLen);
}

void RadioKitClass::_handleGetWifiInfo() {
#if defined(ESP32) && defined(RADIOKIT_ENABLE_WIFI)
    // Build WIFI_INFO_DATA payload:
    // [ip0][ip1][ip2][ip3][mode(1)][ssid_len][ssid...][rssi(1)]
    uint8_t buf[4 + 1 + 1 + RADIOKIT_MAX_SSID + 1];
    uint16_t offset = 0;

    // IP address (4 bytes)
    IPAddress ip;
    if (_wifiActive && RadioKitWiFiInstance.isApMode()) {
        ip = WiFi.softAPIP();
    } else {
        ip = WiFi.localIP();
    }
    buf[offset++] = ip[0];
    buf[offset++] = ip[1];
    buf[offset++] = ip[2];
    buf[offset++] = ip[3];

    // Mode: 0x00 = STA, 0x01 = AP
    buf[offset++] = _wifiActive && RadioKitWiFiInstance.isApMode() ? 0x01 : 0x00;

    // STA SSID (from NVS buffer)
    uint8_t ssidLen = (uint8_t)strnlen(_nvsStaSsid, RADIOKIT_MAX_SSID);
    buf[offset++] = ssidLen;
    memcpy(&buf[offset], _nvsStaSsid, ssidLen);
    offset += ssidLen;

    // RSSI
    int rssi = 0;
    if (_wifiActive && !RadioKitWiFiInstance.isApMode()) {
        rssi = WiFi.RSSI();
    }
    buf[offset++] = (uint8_t)(rssi > 0 ? rssi : (rssi < 0 ? (uint8_t)rssi : 0));

    // Send as 0x55 widget-protocol packet
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_WIFI_INFO_DATA, buf, offset);
    _sendPacket(totalLen);
#else
    // WiFi not available: send empty response
    uint8_t empty = 0;
    uint16_t totalLen = rk_buildPacket(_txBuf, RK_CMD_WIFI_INFO_DATA, &empty, 1);
    _sendPacket(totalLen);
#endif
}

void RadioKitClass::_handleSetInput(const uint8_t* payload, uint16_t len) {
    RK_DEBUG_PRINT("[DBG] _handleSetInput: len=%d\n", len);
    uint16_t offset = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t sz = w->inputSize();
        if (sz == 0) continue;
        if (offset + sz > len) break;
        w->deserializeInput(payload + offset);
        if (sz <= 4) {
            memcpy(_shadowInput[i], payload + offset, sz);
        }
        RK_DEBUG_PRINT("[DBG]   widget[%d]: sz=%d, val=%d\n", i, sz, payload[offset]);
        offset += sz;
    }
    uint8_t seq = 0;
    uint16_t pkt = rk_buildPacket(_txBuf, RK_CMD_ACK, &seq, 1);
    _sendPacket(pkt);
}

void RadioKitClass::_handleAck(const uint8_t* payload, uint16_t len) {
    // ACKs are informational only — shadow comparison provides reliability.
}

void RadioKitClass::_handleVarUpdate(const uint8_t* payload, uint16_t len) {
    if (len < 2) {
        RK_DEBUG_PRINT("[DBG] _handleVarUpdate: too short (%d)\n", len);
        return;
    }
    uint8_t widgetId = payload[0];
    uint8_t seq = payload[1];
    if (widgetId >= _widgetCount) {
        RK_DEBUG_PRINT("[DBG] _handleVarUpdate: invalid widgetId %d\n", widgetId);
        return;
    }

    RadioKit_Widget* w = _widgets[widgetId];
    uint8_t inSz = w->inputSize();
    uint8_t outSz = w->outputSize();
    RK_DEBUG_PRINT("[DBG] _handleVarUpdate: wid=%d seq=%d inSz=%d outSz=%d\n",
        widgetId, seq, inSz, outSz);
    
    if (inSz > 0 && 2 + inSz <= len) {
        uint8_t oldVal = 0;
        w->serializeInput(&oldVal);  // need actual state
        uint8_t newVal = payload[2];
        w->deserializeInput(&payload[2]);
        if (inSz <= 4) {
            RK_DEBUG_PRINT("[DBG]   input: old=%d new=%d, updating shadow\n", oldVal, newVal);
            memcpy(_shadowInput[widgetId], &payload[2], inSz);
        }
    } else if (outSz > 0 && 2 + outSz <= len) {
        // Output widgets (LED, Text) receive VAR_UPDATE for value updates
        // (No deserializeOutput method exists in the base Widget interface)
        RK_DEBUG_PRINT("[DBG]   output: len=%d (ignored, no deserializeOutput)\n", outSz);
    }

    // Ack back to sender
    uint16_t pkt = rk_buildAck(_txBuf, seq);
    _sendPacket(pkt);
}

void RadioKitClass::_handleMetaUpdate(const uint8_t* payload, uint16_t len) {
    if (len < 2) return;
    uint8_t widgetId = payload[0];
    uint8_t seq = payload[1];
    if (widgetId >= _widgetCount) return;

    RadioKit_Widget* w = _widgets[widgetId];
    // Meta update from App to Arduino: App wants to change labels?
    // Not usually used, but we handle it.
    // (Actual implementation would need a deserializeStrings, but we leave it for now)
    
    // Ack back to sender
    uint16_t pkt = rk_buildAck(_txBuf, seq);
    _sendPacket(pkt);
}

// ── CONF_DATA payload builder (Protocol v3) ──────────────────────────────
//
// strBuf worst-case per widget:
//   mask(1)
//   + label:   len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + icon:    len(1) + RADIOKIT_MAX_ICON(24)     = 25
//   + onText:  len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + offText: len(1) + RADIOKIT_MAX_LABEL(32)   = 33
//   + content: len(1) + RADIOKIT_MAX_ITEMS*(RADIOKIT_MAX_LABEL+RADIOKIT_MAX_ICON+2) pipes
//            = 1 + 8*(32+24+2) = 1 + 464 = 465  (Multiple widget worst case)
// Total worst case = 1+33+25+33+33+465 = 590 bytes → use 640 to be safe.

uint16_t RadioKitClass::_buildConfPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;

    const char* themeStr = config.theme ? config.theme : RK_DEFAULT;
    uint8_t themeLen = (uint8_t)strnlen(themeStr, 64);

    // Minimal CONF_DATA: orientation + widget count + theme + per-widget layout
    // Name, description, protocol version moved to Settings protocol (GET_DEVICE_INFO)
    if (out + 3 + themeLen > bufSize) return 0;

    buf[out++] = config.orientation;
    buf[out++] = _widgetCount;
    buf[out++] = themeLen;
    memcpy(&buf[out], themeStr, themeLen); out += themeLen;

    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];

        if (out + 10 > bufSize) break;
        buf[out++] = w->typeId;
        buf[out++] = w->widgetId;
        buf[out++] = w->x();
        buf[out++] = w->y();
        buf[out++] = w->width();
        buf[out++] = w->height();
        int16_t rot = w->rotation();
        buf[out++] = (uint8_t)(rot & 0xFF);
        buf[out++] = (uint8_t)((rot >> 8) & 0xFF);
        buf[out++] = w->style();
        buf[out++] = w->variant();

        uint16_t strLen = w->serializeStrings(&buf[out]);
        if (out + strLen <= bufSize) {
            out += strLen;
        } else {
            break;
        }
    }
    return out;
}

// ── VAR_DATA payload builder ──────────────────────────────────────────
uint16_t RadioKitClass::_buildVarPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint8_t inSz = w->inputSize();
        uint8_t outSz = w->outputSize();
        uint8_t sz = (outSz > 0) ? outSz : inSz;
        
        if (sz == 0) continue;
        if (out + sz > bufSize) break;
        
        if (outSz > 0) w->serializeOutput(&buf[out]);
        else w->serializeInput(&buf[out]);
        
        out += sz;
    }
    return out;
}

uint16_t RadioKitClass::_buildMetaPayload(uint8_t* buf, uint16_t bufSize) {
    uint16_t out = 0;
    for (uint8_t i = 0; i < _widgetCount; i++) {
        RadioKit_Widget* w = _widgets[i];
        uint16_t strLen = w->serializeStrings(&buf[out]);
        if (out + strLen <= bufSize) {
            out += strLen;
        } else {
            break;
        }
    }
    return out;
}

void RadioKitClass::_sendPacket(const uint8_t* buf, uint16_t len) {
    _sendToAllTransports(buf, len);
}

void RadioKitClass::_sendPacket(uint16_t len) {
    RK_DEBUG_PRINT("RK: Sending CMD %s (0x%02X), len %d\n", rk_cmdName(_txBuf[3]), _txBuf[3], len);
    _sendToAllTransports(_txBuf, len);
}

void RadioKitClass::_sendToAllTransports(const uint8_t* buf, uint16_t len) {
    if (_transport) _transport->sendPacket(buf, len);
    if (_wifiActive) RadioKitWiFiInstance.sendPacket(buf, len);
    if (_cloudActive) RadioKitCloudInstance.sendPacket(buf, len);
}

// ── Filesystem bulk protocol ────────────────────────────────────────────────

bool RadioKitClass::beginFs() {
    return RKFs::begin();
}

bool RadioKitClass::isFsReady() const {
    return RKFs::isReady();
}

bool RadioKitClass::formatFs() {
    return RKFs::format();
}

void RadioKitClass::sendFsFrame(const uint8_t* buf, uint16_t len) {
    _sendToAllTransports(buf, len);
}

void RadioKitClass::_sendFsFrame(const uint8_t* buf, uint16_t len) {
    if (s_instance) s_instance->sendFsFrame(buf, len);
}

void RadioKitClass::_onFsPacket(uint8_t subCmd,
                                const uint8_t* payload,
                                uint16_t payloadLen)
{
    // ── Admin gate ─────────────────────────────────────────────────────
    // FS operations require admin auth. If only user-authenticated, reject.
    if (s_instance) {
        bool isAdmin = s_instance->_authenticatedAdmin || s_instance->_nvsAdminPwd[0] == '\0';
        if (!isAdmin) {
            RK_DEBUG_PRINT("RK: Rejected FS 0x%02X — admin required\n", subCmd);
            // Reply with ACCESS_DENIED (0x04) for the specific sub-command
            uint8_t err = RK_FS_ERR_ACCESS_DENIED;
            uint8_t ackResp = subCmd | 0x80;
            uint16_t frameLen = rk_fsBuildFrame(rk_fsTxBuf(), ackResp, &err, 1);
            s_instance->_sendToAllTransports(rk_fsTxBuf(), frameLen);
            return;
        }
    }
    
    RK_DEBUG_PRINT("RK: Dispatching FS %s (0x%02X), len %d\n",
                   rk_fsCmdName(subCmd), subCmd, payloadLen);
    RKFs::dispatch(subCmd, payload, payloadLen);
}

// ── CHIP_INFO handler ─────────────────────────────────────────────────────

// (moved to _handleSettingsGetChipInfo via Settings protocol)

// ── OTA protocol ────────────────────────────────────────────────────────────

// Progress tracking for OTA — persisted across Begin/Chunk calls
static uint32_t s_otaLastProgressPct = 0;
static uint32_t s_otaLastProgressChunk = 0;
static uint32_t s_otaChunkCount = 0;

// OTA bytes written counter, tracked ourselves because ESP32's
// Update.progress() only increments when a full flash sector (4096 bytes)
// is flushed, not after every Update.write() call with partial sectors.
static uint32_t s_otaBytesWritten = 0;

void RadioKitClass::_onOtaPacket(uint8_t subCmd,
                                 const uint8_t* payload,
                                 uint16_t payloadLen)
{
    if (!s_instance) return;
    
    // ── Admin gate ─────────────────────────────────────────────────────
    // OTA operations require admin auth. If only user-authenticated, reject.
    bool isAdmin = s_instance->_authenticatedAdmin || s_instance->_nvsAdminPwd[0] == '\0';
    if (!isAdmin) {
        RK_DEBUG_PRINT("RK: Rejected OTA 0x%02X — admin required\n", subCmd);
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        s_instance->_sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }
    
    RK_DEBUG_PRINT("RK: Dispatching OTA %s (0x%02X), len %d\n",
                   rk_otaCmdName(subCmd), subCmd, payloadLen);
    switch (subCmd) {
        case RK_OTA_CMD_BEGIN:          s_instance->_handleOtaBegin(payload, payloadLen); break;
        case RK_OTA_CMD_CHUNK:          s_instance->_handleOtaChunk(payload, payloadLen); break;
        case RK_OTA_CMD_END:            s_instance->_handleOtaEnd(payload, payloadLen);   break;
        case RK_OTA_CMD_ABORT:          s_instance->_handleOtaAbort();                    break;
        case RK_OTA_CMD_SET_ERASE_FLAG: s_instance->_handleOtaSetEraseFlag(payload, payloadLen); break;
        default:
            Serial.printf("RK: Unknown OTA sub-command 0x%02X\n", subCmd);
            break;
    }
}

void RadioKitClass::_sendOtaFrame(const uint8_t* buf, uint16_t len) {
    if (s_instance) {
        s_instance->_sendToAllTransports(buf, len);
    }
}

void RadioKitClass::_handleOtaBegin(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 4) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint32_t firmwareSize = (uint32_t)payload[0] |
                           ((uint32_t)payload[1] << 8) |
                           ((uint32_t)payload[2] << 16) |
                           ((uint32_t)payload[3] << 24);

    RK_DEBUG_PRINT("OTA: Begin firmware update, size=%u\n", firmwareSize);

    // Reset progress tracking for fresh OTA session
    s_otaLastProgressPct = 0;
    s_otaLastProgressChunk = 0;
    s_otaChunkCount = 0;
    s_otaBytesWritten = 0;

    // Abort any stale OTA in progress
    Update.abort();
    s_otaBytesWritten = 0;

    if (!Update.begin(firmwareSize)) {
        uint8_t err = RK_OTA_ERR_NO_SPACE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Serial.printf("OTA: Update.begin failed (no space?)\n");
        return;
    }

    uint8_t err = RK_OTA_ERR_OK;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

void RadioKitClass::_handleOtaChunk(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 4) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    if (!Update.isRunning()) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint32_t chunkOffset = (uint32_t)payload[0] |
                          ((uint32_t)payload[1] << 8) |
                          ((uint32_t)payload[2] << 16) |
                          ((uint32_t)payload[3] << 24);
    uint16_t dataLen = len - 4;

    // Use our own progress tracking instead of Update.progress() because
    // ESP32's Update class only increments progress when a full flash sector
    // (4096 bytes) is flushed, not on every Update.write() call.
    if (chunkOffset != s_otaBytesWritten) {
        Serial.printf("OTA: Offset mismatch — got %u, expected %u\n",
            chunkOffset, s_otaBytesWritten);
        uint8_t err = RK_OTA_ERR_SEQ;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    size_t written = Update.write((uint8_t*)(&payload[4]), dataLen);
    if (written != dataLen) {
        Serial.printf("OTA: Write error — wrote %u of %u bytes\n", written, dataLen);
        uint8_t err = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }
    s_otaBytesWritten += written;

    // Send ACK
    uint8_t err = RK_OTA_ERR_OK;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);

    // Send periodic progress notification (every ~5% or every 50 chunks)
    uint32_t total = Update.size();
    uint32_t received = s_otaBytesWritten;
    if (total > 0) {
        uint32_t pct = (received * 100) / total;
        s_otaChunkCount++;
        if (pct >= s_otaLastProgressPct + 5 || s_otaChunkCount - s_otaLastProgressChunk >= 50) {
            s_otaLastProgressPct = pct;
            s_otaLastProgressChunk = s_otaChunkCount;
            uint8_t progBuf[8];
            progBuf[0] = (uint8_t)(received & 0xFF);
            progBuf[1] = (uint8_t)((received >> 8) & 0xFF);
            progBuf[2] = (uint8_t)((received >> 16) & 0xFF);
            progBuf[3] = (uint8_t)((received >> 24) & 0xFF);
            progBuf[4] = (uint8_t)(total & 0xFF);
            progBuf[5] = (uint8_t)((total >> 8) & 0xFF);
            progBuf[6] = (uint8_t)((total >> 16) & 0xFF);
            progBuf[7] = (uint8_t)((total >> 24) & 0xFF);
            uint16_t pLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_PROGRESS, progBuf, 8);
            _sendOtaFrame(rk_otaTxBuf(), pLen);
        }
    }
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

void RadioKitClass::_handleOtaEnd(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 4) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    if (!Update.isRunning()) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint32_t expectedCrc = (uint32_t)payload[0] |
                          ((uint32_t)payload[1] << 8) |
                          ((uint32_t)payload[2] << 16) |
                          ((uint32_t)payload[3] << 24);

    RK_DEBUG_PRINT("OTA: End — expected CRC32=0x%08X\n", expectedCrc);

    if (!Update.end()) {
        // Flash write error during finalisation
        Serial.printf("OTA: Update.end() failed\n");
        uint8_t err = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Update.abort();
        return;
    }

    // Update.end() verifies its own SHA-256 digest internally.
    // Set the boot partition to the new firmware.
    const esp_partition_t* running = esp_ota_get_running_partition();
    const esp_partition_t* next = esp_ota_get_next_update_partition(running);
    if (!next) {
        Serial.printf("OTA: No next OTA partition found\n");
        uint8_t err = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Update.abort();
        return;
    }

    esp_err_t err = esp_ota_set_boot_partition(next);
    if (err != ESP_OK) {
        Serial.printf("OTA: esp_ota_set_boot_partition failed: %d\n", err);
        uint8_t errCode = RK_OTA_ERR_FLASH;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &errCode, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        Update.abort();
        return;
    }

    // Send success ACK before rebooting
    uint8_t errCode = RK_OTA_ERR_OK;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &errCode, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);

    RK_DEBUG_PRINT("OTA: Complete — rebooting in 100ms...\n");
    delay(100);
    esp_restart();
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

void RadioKitClass::_handleOtaAbort() {
#if RK_HAS_OTA
    RK_DEBUG_PRINT("OTA: Abort requested\n");
    Update.abort();
    s_otaBytesWritten = 0;
    Serial.println("OTA: Aborted — partition released, ready for new OTA");
#else
    Serial.println("OTA: Abort ignored — OTA not supported");
#endif
}

void RadioKitClass::_handleOtaSetEraseFlag(const uint8_t* payload, uint16_t len) {
#if RK_HAS_OTA
    if (len < 1) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    uint8_t eraseMode = payload[0];
    if (eraseMode > RK_PENDING_ERASE_FS) {
        uint8_t err = RK_OTA_ERR_INVALID_STATE;
        uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
        _sendOtaFrame(rk_otaTxBuf(), frameLen);
        return;
    }

    // Write the erase flag to NVS. NVS is a separate flash partition and
    // survives OTA update (which only writes to the app partition). On the
    // next boot, begin() reads this key after RKNvs::init() and performs
    // the requested erase before continuing.
    bool ok = RKNvs::writeU8(RK_NVS_KEY_PENDING_ERASE, eraseMode);
    ok = RKNvs::commit() && ok;

    if (ok) {
        Serial.printf("OTA: Erase flag=%d written to NVS\n", eraseMode);
    } else {
        Serial.printf("OTA: Erase flag=%d NVS write FAILED\n", eraseMode);
    }

    uint8_t err = ok ? RK_OTA_ERR_OK : RK_OTA_ERR_FLASH;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
#else
    uint8_t err = RK_OTA_ERR_NOT_SUPPORTED;
    uint16_t frameLen = rk_otaBuildFrame(rk_otaTxBuf(), RK_OTA_RESP_ACK, &err, 1);
    _sendOtaFrame(rk_otaTxBuf(), frameLen);
    (void)payload; (void)len;
#endif
}

// ── NVS Raw Read / Write ─────────────────────────────────────────────────────

void RadioKitClass::_handleSettingsNvsRawRead(const uint8_t* payload, uint16_t len) {
    // Request: [KEY_LEN(1)][KEY...]
    // Response: [STATUS(1)][VALUE_LEN(1)][VALUE...]
    if (!_nvsActive || len < 1) {
        uint8_t resp[2] = {RK_SETTINGS_NVS_RAW_ERROR, 0};
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_NVS_RAW_READ_DATA, resp, 2);
        _sendSettingsFrame(frameLen);
        return;
    }

    uint8_t keyLen = payload[0];
    if (keyLen < 1 || keyLen > 16 || 1 + keyLen > len) {
        uint8_t resp[2] = {RK_SETTINGS_NVS_RAW_ERROR, 0};
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_NVS_RAW_READ_DATA, resp, 2);
        _sendSettingsFrame(frameLen);
        return;
    }

    char key[32];
    memcpy(key, &payload[1], keyLen);
    key[keyLen] = '\0';

    uint8_t value = 0;
    bool found = RKNvs::readU8(key, &value);

    if (found) {
        uint8_t resp[3] = {RK_SETTINGS_NVS_RAW_OK, 1, value};
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_NVS_RAW_READ_DATA, resp, 3);
        _sendSettingsFrame(frameLen);
        Serial.printf("NVS: Raw read key='%s' = %u\n", key, value);
    } else {
        uint8_t resp[2] = {RK_SETTINGS_NVS_RAW_ERROR, 0};
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_NVS_RAW_READ_DATA, resp, 2);
        _sendSettingsFrame(frameLen);
        Serial.printf("NVS: Raw read key='%s' not found\n", key);
    }
}

void RadioKitClass::_handleSettingsNvsRawWrite(const uint8_t* payload, uint16_t len) {
    // Request: [KEY_LEN(1)][KEY...][VALUE(1)]
    // Response: [STATUS(1)]
    if (!_nvsActive || len < 3) {
        uint8_t resp = RK_SETTINGS_NVS_RAW_ERROR;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_NVS_RAW_WRITE_ACK, &resp, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    uint8_t keyLen = payload[0];
    if (keyLen < 1 || keyLen > 16 || 1 + keyLen > len) {
        uint8_t resp = RK_SETTINGS_NVS_RAW_ERROR;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_NVS_RAW_WRITE_ACK, &resp, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    char key[32];
    memcpy(key, &payload[1], keyLen);
    key[keyLen] = '\0';

    uint8_t value = payload[1 + keyLen];

    bool ok = RKNvs::writeU8(key, value);
    ok = RKNvs::commit() && ok;

    uint8_t resp = ok ? RK_SETTINGS_NVS_RAW_OK : RK_SETTINGS_NVS_RAW_ERROR;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_NVS_RAW_WRITE_ACK, &resp, 1);
    _sendSettingsFrame(frameLen);

    if (ok) {
        Serial.printf("NVS: Raw write key='%s' = %u\n", key, value);
    } else {
        Serial.printf("NVS: Raw write key='%s' FAILED\n", key);
    }
}

// ── Factory Reset ───────────────────────────────────────────────────────────

void RadioKitClass::_handleSettingsFactoryReset() {
    Serial.println("FACTORY RESET: Erasing NVS config and rebooting...");
    
    // Send ACK before reboot
    uint8_t status = RK_SETTINGS_PWD_OK;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_FACTORY_RESET_ACK, &status, 1);
    _sendSettingsFrame(frameLen);
    
    if (_nvsActive) {
        RKNvs::eraseAll();
        RKNvs::commit();
    }
    
    memset(_nvsName, 0, sizeof(_nvsName));
    memset(_nvsDesc, 0, sizeof(_nvsDesc));
    memset(_nvsPwd,  0, sizeof(_nvsPwd));
    memset(_nvsAdminPwd, 0, sizeof(_nvsAdminPwd));
    memset(_nvsStaSsid, 0, sizeof(_nvsStaSsid));
    memset(_nvsStaPwd, 0, sizeof(_nvsStaPwd));
    memset(_nvsCloudUrl, 0, sizeof(_nvsCloudUrl));
    memset(_nvsCloudAccount, 0, sizeof(_nvsCloudAccount));
    _authenticated = true;
    _authenticatedAdmin = true;
    
    delay(100);
#if defined(ESP32)
    esp_restart();
#else
    Serial.println("FACTORY RESET: Reboot not supported on this platform");
#endif
}

// ── NVS Config Helpers ──────────────────────────────────────────────────────

void RadioKitClass::_syncNvsToBuffers() {
    // Clear buffers first
    memset(_nvsName, 0, sizeof(_nvsName));
    memset(_nvsDesc, 0, sizeof(_nvsDesc));
    memset(_nvsPwd,  0, sizeof(_nvsPwd));
    memset(_nvsAdminPwd, 0, sizeof(_nvsAdminPwd));

    if (!_nvsActive) {
        // Fall back to compile-time defaults
        strncpy(_nvsName, config.name ? config.name : "", sizeof(_nvsName) - 1);
        strncpy(_nvsDesc, config.description ? config.description : "", sizeof(_nvsDesc) - 1);
        strncpy(_nvsPwd,  config.password ? config.password : "", sizeof(_nvsPwd) - 1);
        _nvsAdminPwd[0] = '\0';
        return;
    }

    // Read from NVS — if a key doesn't exist, use compile-time default
    if (!RKNvs::readString(RK_NVS_KEY_NAME, _nvsName, sizeof(_nvsName))) {
        strncpy(_nvsName, config.name ? config.name : "", sizeof(_nvsName) - 1);
    }
    if (!RKNvs::readString(RK_NVS_KEY_DESC, _nvsDesc, sizeof(_nvsDesc))) {
        strncpy(_nvsDesc, config.description ? config.description : "", sizeof(_nvsDesc) - 1);
    }
    if (!RKNvs::readString(RK_NVS_KEY_PWD, _nvsPwd, sizeof(_nvsPwd))) {
        strncpy(_nvsPwd, config.password ? config.password : "", sizeof(_nvsPwd) - 1);
    }
    if (!RKNvs::readString(RK_NVS_KEY_ADMIN_PWD, _nvsAdminPwd, sizeof(_nvsAdminPwd))) {
        _nvsAdminPwd[0] = '\0';
    }

    // ── WiFi STA SSID ──────────────────────────────────────────────
    if (!RKNvs::readString(RK_NVS_KEY_STA_SSID, _nvsStaSsid, sizeof(_nvsStaSsid))) {
        strncpy(_nvsStaSsid, config.sta_ssid ? config.sta_ssid : "", sizeof(_nvsStaSsid) - 1);
    }
    // ── STA Password ────────────────────────────────────────────────
    if (!RKNvs::readString(RK_NVS_KEY_STA_PWD, _nvsStaPwd, sizeof(_nvsStaPwd))) {
        strncpy(_nvsStaPwd, config.sta_password ? config.sta_password : "", sizeof(_nvsStaPwd) - 1);
    }
    // ── Cloud URL ───────────────────────────────────────────────────
    if (!RKNvs::readString(RK_NVS_KEY_CLOUD_URL, _nvsCloudUrl, sizeof(_nvsCloudUrl))) {
        strncpy(_nvsCloudUrl, config.cloud_url ? config.cloud_url : "", sizeof(_nvsCloudUrl) - 1);
    }
    // ── Cloud account ───────────────────────────────────────────────
    if (!RKNvs::readString(RK_NVS_KEY_CLOUD_ACCOUNT, _nvsCloudAccount, sizeof(_nvsCloudAccount))) {
        strncpy(_nvsCloudAccount, config.cloud_account ? config.cloud_account : "", sizeof(_nvsCloudAccount) - 1);
    }

    RK_DEBUG_PRINT("NVS: Loaded name='%s', desc='%s', conn_pwd=%s, admin_pwd=%s\n",
        _nvsName, _nvsDesc,
        _nvsPwd[0] ? "***" : "(none)",
        _nvsAdminPwd[0] ? "***" : "(none)");
}

void RadioKitClass::_setBleAdvertisingName(const char* name) {
#if defined(ESP32)
    // Re-start BLE advertising with the new name.
    // NimBLE allows updating the advertiser's name and re-starting.
    extern RadioKitBLE RadioKitBLEInstance;
    if (_transport == &RadioKitBLEInstance && RadioKitBLEInstance.isConnected()) {
        static char bleAdvName[RADIOKIT_MAX_NAME + 4];
        snprintf(bleAdvName, sizeof(bleAdvName), "RK_%s", name ? name : "RadioKit");
        RadioKitBLEInstance.updateAdvertisingName(bleAdvName);
        Serial.printf("NVS: BLE advertising name updated to '%s'\n", bleAdvName);
    }
#else
    (void)name;
#endif
}

// ── Public NVS config API ───────────────────────────────────────────────────

void RadioKitClass::setConfig(const char* name, const char* description, const char* password, const char* adminPassword) {
    if (!_nvsActive) {
        Serial.println("NVS: Cannot set config — NVS not available");
        return;
    }

    bool changed = false;

    if (name && name[0] != '\0' && strncmp(name, _nvsName, RADIOKIT_MAX_NAME) != 0) {
        strncpy(_nvsName, name, sizeof(_nvsName) - 1);
        RKNvs::writeString(RK_NVS_KEY_NAME, _nvsName);
        changed = true;
        // Update BLE advertisement name
        _setBleAdvertisingName(_nvsName);
    }

    if (description && description[0] != '\0' && strncmp(description, _nvsDesc, RADIOKIT_MAX_DESC) != 0) {
        strncpy(_nvsDesc, description, sizeof(_nvsDesc) - 1);
        RKNvs::writeString(RK_NVS_KEY_DESC, _nvsDesc);
        changed = true;
    }

    if (password && strncmp(password, _nvsPwd, RADIOKIT_MAX_PWD) != 0) {
        strncpy(_nvsPwd, password, sizeof(_nvsPwd) - 1);
        RKNvs::writeString(RK_NVS_KEY_PWD, _nvsPwd);
        changed = true;
        // If password was cleared, mark as pre-authenticated
        if (_nvsPwd[0] == '\0') {
            _authenticated = true;
        } else {
            _authenticated = false;  // New password set — re-auth required
        }
    }

    if (adminPassword && strncmp(adminPassword, _nvsAdminPwd, RADIOKIT_MAX_ADMIN_PWD) != 0) {
        strncpy(_nvsAdminPwd, adminPassword, sizeof(_nvsAdminPwd) - 1);
        RKNvs::writeString(RK_NVS_KEY_ADMIN_PWD, _nvsAdminPwd);
        changed = true;
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;
        } else {
            _authenticatedAdmin = false;  // New admin password set — re-auth required
        }
    }

    if (changed) {
        RKNvs::commit();
        Serial.println("NVS: Config updated and committed");
    }
}

uint8_t RadioKitClass::authenticate(const char* password, bool asAdmin) {
    if (!password) return RK_PWD_AUTH_MISMATCH;
    
    if (asAdmin) {
        // ── Admin auth ────────────────────────────────────────────────
        bool alreadyAdmin = _authenticatedAdmin || _nvsAdminPwd[0] == '\0';
        if (alreadyAdmin) {
            _authenticatedAdmin = true;
            _authenticated = true;
            return RK_PWD_AUTH_ALREADY;
        }
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;
            return RK_PWD_AUTH_OK;
        }
        if (strncmp(password, _nvsAdminPwd, RADIOKIT_MAX_ADMIN_PWD) == 0) {
            _authenticatedAdmin = true;
            _authenticated = true;  // Admin implies user
            return RK_PWD_AUTH_OK;
        }
        return RK_PWD_AUTH_MISMATCH;
    }
    
    // ── User (connection) auth ───────────────────────────────────────
    if (_authenticated) {
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;  // Auto-promote to admin
        }
        return RK_PWD_AUTH_ALREADY;
    }
    
    if (_nvsPwd[0] == '\0') {
        _authenticated = true;
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;  // Auto-promote to admin
        }
        return RK_PWD_AUTH_OK;
    }
    
    // Try connection password
    if (strncmp(password, _nvsPwd, RADIOKIT_MAX_PWD) == 0) {
        _authenticated = true;
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;  // Auto-promote to admin
        }
        return RK_PWD_AUTH_OK;
    }
    
    // Fallback: try admin password (admin can be used for connection)
    if (_nvsAdminPwd[0] != '\0' && strncmp(password, _nvsAdminPwd, RADIOKIT_MAX_ADMIN_PWD) == 0) {
        _authenticated = true;
        _authenticatedAdmin = true;
        return RK_PWD_AUTH_OK;
    }
    
    return RK_PWD_AUTH_MISMATCH;
}

// ── CMD_SET_CONF handler (0x19) ─────────────────────────────────────────────

void RadioKitClass::_handleSettingsSetConf(const uint8_t* payload, uint16_t len) {
    if (!_nvsActive || len < 2) {
        Serial.println("NVS: SETTINGS_SET_CONF ignored — NVS not available or payload too short");
        uint8_t status = RK_SETTINGS_SET_CONF_ERROR;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_SET_CONF_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    uint16_t fieldMask = (uint16_t)payload[0] | ((uint16_t)payload[1] << 8);
    uint16_t offset = 2;
    bool appliedOk = true;

    // Name
    if (fieldMask & RK_SETTINGS_SET_CONF_NAME) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_NAME) strLen = RADIOKIT_MAX_NAME;
            if (offset + strLen <= len) {
                memcpy(_nvsName, &payload[offset], strLen);
                _nvsName[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_NAME, _nvsName);
                _setBleAdvertisingName(_nvsName);
            }
            offset += strLen;
        }
    }

    // Description
    if (fieldMask & RK_SETTINGS_SET_CONF_DESC) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_DESC) strLen = RADIOKIT_MAX_DESC;
            if (offset + strLen <= len) {
                memcpy(_nvsDesc, &payload[offset], strLen);
                _nvsDesc[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_DESC, _nvsDesc);
            }
            offset += strLen;
        }
    }

    // Connection password
    if (fieldMask & RK_SETTINGS_SET_CONF_PWD) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_PWD) strLen = RADIOKIT_MAX_PWD;
            if (offset + strLen <= len) {
                memcpy(_nvsPwd, &payload[offset], strLen);
                _nvsPwd[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_PWD, _nvsPwd);
            }
            offset += strLen;
        }
    }

    // Admin password
    if (fieldMask & RK_SETTINGS_SET_CONF_ADMIN_PWD) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_ADMIN_PWD) strLen = RADIOKIT_MAX_ADMIN_PWD;
            if (offset + strLen <= len) {
                memcpy(_nvsAdminPwd, &payload[offset], strLen);
                _nvsAdminPwd[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_ADMIN_PWD, _nvsAdminPwd);
            }
            offset += strLen;
        }
    }

    RKNvs::commit();

    if (fieldMask & RK_SETTINGS_SET_CONF_PWD) {
        if (_nvsPwd[0] == '\0') {
            _authenticated = true;
        } else {
            _authenticated = false;
        }
    }
    if (fieldMask & RK_SETTINGS_SET_CONF_ADMIN_PWD) {
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;
        } else {
            _authenticatedAdmin = false;
        }
    }

    // Send ACK via settings protocol
    uint8_t status = appliedOk ? (fieldMask & 0x7F) : RK_SETTINGS_SET_CONF_ERROR;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_SET_CONF_ACK, &status, 1);
    _sendSettingsFrame(frameLen);

    // Re-broadcast device info so app can refresh cached name/desc
    // (CONF_DATA no longer carries name/desc — use GET_DEVICE_INFO)
    if (appliedOk && (fieldMask & (RK_SETTINGS_SET_CONF_NAME | RK_SETTINGS_SET_CONF_DESC)) != 0) {
        _handleSettingsDeviceInfo();
    }

    Serial.printf("NVS: SETTINGS_SET_CONF applied mask=0x%04X\n", fieldMask);
}

// ── SETTINGS_SET_WIFI handler (0x0B) ─────────────────────────────────────────

void RadioKitClass::_handleSettingsSetWifi(const uint8_t* payload, uint16_t len) {
    if (!_nvsActive || len < 2) {
        uint8_t status = RK_SETTINGS_SET_CONF_ERROR;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_SET_WIFI_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    uint16_t fieldMask = (uint16_t)payload[0] | ((uint16_t)payload[1] << 8);
    uint16_t offset = 2;
    bool appliedOk = true;

    // STA SSID
    if (fieldMask & RK_SETTINGS_SET_WIFI_SSID) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_SSID) strLen = RADIOKIT_MAX_SSID;
            if (offset + strLen <= len) {
                memcpy(_nvsStaSsid, &payload[offset], strLen);
                _nvsStaSsid[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_STA_SSID, _nvsStaSsid);
            }
            offset += strLen;
        }
    }

    // STA Password
    if (fieldMask & RK_SETTINGS_SET_WIFI_PWD) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_WIFI_PWD) strLen = RADIOKIT_MAX_WIFI_PWD;
            if (offset + strLen <= len) {
                memcpy(_nvsStaPwd, &payload[offset], strLen);
                _nvsStaPwd[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_STA_PWD, _nvsStaPwd);
            }
            offset += strLen;
        }
    }

    RKNvs::commit();

    // Send ACK
    uint8_t status = appliedOk ? (fieldMask & 0x7F) : RK_SETTINGS_SET_CONF_ERROR;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_SET_WIFI_ACK, &status, 1);
    _sendSettingsFrame(frameLen);

    Serial.printf("NVS: SETTINGS_SET_WIFI applied mask=0x%04X — rebooting...\n", fieldMask);

    // Auto-reboot to apply new credentials
    delay(100);
#if defined(ESP32)
    esp_restart();
#endif
}

// ── SETTINGS_PWD_AUTH handler (0x06) ───────────────────────────────────────

void RadioKitClass::_handleSettingsPwdAuth(const uint8_t* payload, uint16_t len) {
    if (len < 1) {
        uint8_t status = RK_SETTINGS_PWD_MISMATCH;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    uint8_t pwdLen = payload[0];
    if (pwdLen > RADIOKIT_MAX_PWD) pwdLen = RADIOKIT_MAX_PWD;

    bool adminRequested = false;
    if (len >= 1 + pwdLen + 1) {
        adminRequested = (payload[1 + pwdLen] & RK_SETTINGS_PWD_FLAG_ADMIN) != 0;
    }

    if (adminRequested) {
        bool alreadyAdmin = _authenticatedAdmin || _nvsAdminPwd[0] == '\0';
        if (alreadyAdmin) {
            _authenticatedAdmin = true;
            _authenticated = true;
            uint8_t status = RK_SETTINGS_PWD_ALREADY;
            uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
                RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
            _sendSettingsFrame(frameLen);
            return;
        }
        if (len >= 1 + pwdLen && strncmp((const char*)&payload[1], _nvsAdminPwd, pwdLen) == 0) {
            _authenticatedAdmin = true;
            _authenticated = true;
            uint8_t status = RK_SETTINGS_PWD_OK;
            uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
                RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
            _sendSettingsFrame(frameLen);
            Serial.println("NVS: Admin authentication successful");
        } else {
            uint8_t status = RK_SETTINGS_PWD_MISMATCH;
            uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
                RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
            _sendSettingsFrame(frameLen);
            Serial.println("NVS: Admin authentication failed — password mismatch");
        }
        return;
    }

    // User auth
    if (_authenticated) {
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;
        }
        uint8_t status = RK_SETTINGS_PWD_ALREADY;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    if (_nvsPwd[0] == '\0') {
        _authenticated = true;
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;
        }
        uint8_t status = RK_SETTINGS_PWD_OK;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        return;
    }

    // Try connection password
    if (len >= 1 + pwdLen && strncmp((const char*)&payload[1], _nvsPwd, pwdLen) == 0) {
        _authenticated = true;
        if (_nvsAdminPwd[0] == '\0') {
            _authenticatedAdmin = true;
        }
        uint8_t status = RK_SETTINGS_PWD_OK;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        Serial.println("NVS: Connection authentication successful");
        return;
    }

    // Fallback: try admin password
    if (_nvsAdminPwd[0] != '\0' && len >= 1 + pwdLen && strncmp((const char*)&payload[1], _nvsAdminPwd, pwdLen) == 0) {
        _authenticated = true;
        _authenticatedAdmin = true;
        uint8_t status = RK_SETTINGS_PWD_OK;
        uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
            RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
        _sendSettingsFrame(frameLen);
        Serial.println("NVS: Connection auth via admin password — admin mode granted");
        return;
    }

    uint8_t status = RK_SETTINGS_PWD_MISMATCH;
    uint16_t frameLen = rk_settingsBuildFrame(rk_settingsTxBuf(),
        RK_SETTINGS_RESP_PWD_AUTH_ACK, &status, 1);
    _sendSettingsFrame(frameLen);
    Serial.println("NVS: Authentication failed — password mismatch");
}
