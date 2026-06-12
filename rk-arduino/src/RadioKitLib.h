/**
 * RadioKitLib.h
 * Main user-facing header for the RadioKit Arduino library (v2.0).
 *
 * Sketch pattern:
 *   1. Declare widget objects globally (they self-register)
 *   2. Set RadioKit.config fields
 *   3. Call RadioKit.begin() then RadioKit.startBLE() or RadioKit.startSerial()
 *   4. Call RadioKit.update() every loop()
 */

#ifndef RADIOKIT_H
#define RADIOKIT_H

#include "RadioKitConfig.h"
#include "RadioKitProtocol.h"
#include "connection/RadioKitTransport.h"
#include "connection/RadioKitBLE.h"
#include "connection/RadioKitSerial.h"
#include "connection/RadioKitFS.h"
#include "connection/RadioKitFsHandlers.h"
#include "connection/RadioKitOTA.h"
#include "connection/RadioKitSettings.h"
#include "connection/RadioKitNVS.h"
#include "connection/RadioKitWiFi.h"
#include "connection/RadioKitCloud.h"

class RadioKit_Widget;

// ── Config object ────────────────────────────────────────────
struct RK_Config {
    // ── User configurable ────────────────────────────────────
    const char* name        = "RadioKit Device";
    const char* password    = "";
    const char* description = "";
    const char* version     = "1.0.0";
    const char* type        = "";
    const char* theme       = RK_DEFAULT;
    uint8_t     orientation = RK_LANDSCAPE;
    uint8_t     width       = 0;  ///< Canvas width  (0 = auto)
    uint8_t     height      = 0;  ///< Canvas height (0 = auto)
    uint8_t     transport   = RK_TRANSPORT_BLE; ///< Transport type
    uint32_t    baudrate    = 1000000; ///< Serial baud rate

    // ── WiFi / Cloud (new) ────────────────────────────────────
    const char* sta_ssid      = "";     ///< STA WiFi SSID (empty = AP-only)
    const char* sta_password  = "";     ///< STA WiFi password
    const char* cloud_url     = "";      ///< Cloud relay URL (e.g. "wss://relay.radiokit.com")
    const char* cloud_account = "";      ///< Account identifier for cloud relay

    // ── Device icon (from kDesignerIcons registry) ────────────
    const char* device_icon   = "";      ///< Icon name for this device

    // ── Read-only (set by library) ────────────────────────────
    uint8_t     architecture = RK_ARCH_DETECTED;
    const char* libversion   = RK_LIB_VERSION;
};

// ── Main class ───────────────────────────────────────────────
class RadioKitClass {
public:
    RadioKitClass();

    /** Global configuration — set before begin(). */
    RK_Config config;

    // ── Setup ────────────────────────────────────────────────

    /** Commits configuration. Must be called in setup() before startBLE/startSerial. */
    void begin();

    /**
     * Initialise BLE and start advertising.
     * @param deviceName  Overrides config.name for BLE advertising if provided.
     */
    void startBLE(const char* deviceName = nullptr);

    /**
     * Attach to a pre-initialised serial stream.
     * The sketch MUST call Serial.begin() before this.
     */
    void startSerial(Stream& stream);

    /**
     * Start the WiFi transport — WebSocket server on port 5555.
     * If STA credentials are configured in NVS, connects to the network;
     * otherwise starts in AP mode with SSID "RK_<device_name>".
     * Must be called after begin(). May be combined with startBLE() or startSerial().
     */
    void startWiFi();

    /**
     * Start the cloud relay client (optional). Requires startWiFi() to have
     * been called first. Connects to the configured relay server via WSS:443.
     */
    void startCloud();

    // ── Settings protocol (0xDD) ─────────────────────────────────
    /**
     * Send a pre-built Settings frame to the device.
     */
    void sendSettingsFrame(const uint8_t* buf, uint16_t len);

    // ── Main loop ────────────────────────────────────────────
    void update();

    // ── Manual Sync ──────────────────────────────────────────
    /**
     * Enqueues a reliable VAR_UPDATE broadcast for the specified widget.
     * Useful when a widget's state is modified programmatically in the firmware.
     */
    void pushUpdate(uint8_t widgetId);

    /**
     * Enqueues a reliable META_UPDATE broadcast for the specified widget.
     * Use this when you change a label, icon, or other metadata at runtime.
     */
    void pushMetaUpdate(uint8_t widgetId);

    // ── NVS config editing ───────────────────────────────────────
    /**
     * Update device name, description, and/or passwords at runtime.
     * Writes to NVS, updates BLE advertisement name if changed,
     * and re-broadcasts CONF_DATA.
     * Pass nullptr for fields you don't want to change.
     * @param devicePassword  Device password (full access). Empty string clears it.
     * @param userPassword    User password (widgets-only). Ignored if devicePassword is empty.
     */
    void setConfig(const char* name, const char* description,
                   const char* devicePassword = nullptr,
                   const char* userPassword = nullptr);

    /**
     * Authenticate with a password. The device checks against both
     * stored device and user passwords and returns the granted level.
     * @param password   The password to authenticate with.
     * Returns 0x00 (device/full), 0x01 (user/widgets-only), 0x02 (denied).
     */
    uint8_t authenticate(const char* password);

    /// True if any level of authentication has succeeded (or no passwords set).
    bool isAuthenticated() const { return _deviceAuthenticated || _userAuthenticated; }

    /// True if device-level (full) access has been granted.
    /// Returns true when no device password is set (pre-authenticated).
    bool hasFullAccess() const { return _deviceAuthenticated || _nvsPwd[0] == '\0'; }

    // ── Status ───────────────────────────────────────────────
    bool    isConnected() const;
    int8_t  getRssi();
    uint8_t widgetCount() const { return _widgetCount; }

    // ── Filesystem (bulk protocol) ───────────────────────────
    /**
     * Mount the default filesystem (LittleFS when available).
     * Idempotent: subsequent calls are no-ops once mounted.
     * Returns true on success. If the user sketch defines a custom
     * filesystem, override RKFs::begin() in user code instead.
     */
    bool beginFs();

    /// True once the FS is mounted and ready to serve requests.
    bool isFsReady() const;

    /// Format and remount the FS. Returns true on success.
    bool formatFs();

    /// Send a pre-built FS frame to the device. Used by external code
    /// (e.g. user-supplied handlers) to inject their own FS traffic.
    void sendFsFrame(const uint8_t* buf, uint16_t len);

    // ── Internal ─────────────────────────────────────────────
    void _registerWidget(RadioKit_Widget* widget);

private:
    RadioKit_Widget*   _widgets[RADIOKIT_MAX_WIDGETS];
    uint8_t            _widgetCount;
    RadioKitTransport* _transport;

    // Additional transport pointers (WiFi, Cloud) — separate from _transport
    bool _wifiActive;       ///< True after startWiFi() called
    bool _cloudActive;      ///< True after startCloud() called

    // VAR_UPDATE / SET_INPUT batch dispatch
    uint32_t _pendingUpdatesMask;
    uint8_t _varUpdateSeq;

    // META_UPDATE batch dispatch
    uint32_t _pendingMetaMask;
    uint8_t _metaUpdateSeq;
    
    // Shadow state to track implicit input changes by firmware
    uint8_t _shadowInput[RADIOKIT_MAX_WIDGETS][4];

    uint8_t _txBuf[RK_MAX_PACKET_SIZE];

    static void _onPacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen);
    static void _onFsPacket(uint8_t subCmd, const uint8_t* payload, uint16_t payloadLen);
    static void _onSettingsPacket(uint8_t subCmd, const uint8_t* payload, uint16_t payloadLen);
    static void _sendFsFrame(const uint8_t* buf, uint16_t len);
    static void _sendSettingsFrame(const uint8_t* buf, uint16_t len);

    void _handleGetConf();
    void _handleGetVars();
    void _handleGetMeta();
    void _handleSetInput(const uint8_t* payload, uint16_t len);
    void _handleAck(const uint8_t* payload, uint16_t len);
    void _handleVarUpdate(const uint8_t* payload, uint16_t len);
    void _handleMetaUpdate(const uint8_t* payload, uint16_t len);

    // ── Settings protocol handlers (0xDD) ─────────────────────
    void _handleSettingsTelemetry(const uint8_t* payload, uint16_t payloadLen);
    void _handleSettingsBleInfo();
    void _handleSettingsGetFeatures();
    void _handleSettingsGetChipInfo();
    void _handleSettingsSetConf(const uint8_t* payload, uint16_t len);
    void _handleSettingsPwdAuth(const uint8_t* payload, uint16_t len);
    void _handleSettingsFactoryReset();
    void _handleSettingsDeviceInfo();
    void _handleSettingsNvsRawRead(const uint8_t* payload, uint16_t len);
    void _handleSettingsNvsRawWrite(const uint8_t* payload, uint16_t len);
    void _handleSettingsSetWifi(const uint8_t* payload, uint16_t len);
    void _handleSettingsGetCloudInfo();
    void _handleSettingsReboot();
    void _handleGetWifiInfo();
    void _sendSettingsFrame(uint16_t len);

    void _sendPacket(const uint8_t* buf, uint16_t len);
    void _sendPacket(uint16_t len);
    void _sendToAllTransports(const uint8_t* buf, uint16_t len);

    // ── OTA handlers ────────────────────────────────────────────────
    static void _onOtaPacket(uint8_t subCmd,
                              const uint8_t* payload,
                              uint16_t payloadLen);
    void _handleOtaBegin(const uint8_t* payload, uint16_t len);
    void _handleOtaChunk(const uint8_t* payload, uint16_t len);
    void _handleOtaEnd(const uint8_t* payload, uint16_t len);
    void _handleOtaAbort();
    void _handleOtaSetEraseFlag(const uint8_t* payload, uint16_t len);
    void _sendOtaFrame(const uint8_t* buf, uint16_t len);

    // NVS-backed buffers (override compile-time RK_Config values)
    char _nvsName[RADIOKIT_MAX_NAME + 1];
    char _nvsDesc[RADIOKIT_MAX_DESC + 1];
    char _nvsPwd[RADIOKIT_MAX_PWD + 1];
    char _nvsUserPwd[RADIOKIT_MAX_USER_PWD + 1];
    bool _nvsActive;        ///< True once NVS values have been loaded
    bool _deviceAuthenticated;   ///< Device-level (full) auth flag
    bool _userAuthenticated;     ///< User-level (widgets-only) auth flag

    // WiFi / Cloud NVS buffers
    char _nvsStaSsid[RADIOKIT_MAX_SSID + 1];
    char _nvsStaPwd[RADIOKIT_MAX_WIFI_PWD + 1];
    char _nvsCloudUrl[RADIOKIT_MAX_CLOUD_URL + 1];
    char _nvsCloudAccount[RADIOKIT_MAX_CLOUD_ACCOUNT + 1];

    // Device icon name (from kDesignerIcons registry)
    char _nvsDeviceIcon[RADIOKIT_MAX_DEVICE_ICON + 1];

    // Device UID (16 hex chars + null)
    char _nvsDeviceUid[17];

    // Internal helpers
    void _syncNvsToBuffers();
    void _setBleAdvertisingName(const char* name);

    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildMetaPayload(uint8_t* buf, uint16_t bufSize);
};

extern RadioKitClass RadioKit;

#include "RadioKitWidgets.h"

#endif // RADIOKIT_H
