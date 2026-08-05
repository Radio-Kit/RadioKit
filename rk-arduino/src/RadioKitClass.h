/**
 * RadioKitClass.h
 * Minimal header with the RadioKitClass definition and RK_Config.
 *
 * This header exists so that compilation units like RadioKitBLE.cpp can
 * access the RadioKitClass definition (for RadioKit.print() etc.) without
 * pulling in transport-specific headers (RadioKitWiFi.h → WebSocketsServer.h)
 * that may not be resolvable for symlinked library builds.
 *
 * Transport headers (RadioKitWiFi.h, RadioKitCloud.h) are included only
 * by RadioKitLib.h, which is the full user-facing header.
 */

#ifndef RADIOKIT_CLASS_H
#define RADIOKIT_CLASS_H

#include "RadioKitConfig.h"
#include "RadioKitProtocol.h"
#include "connection/RadioKitTransport.h"
#include "core/ICommandHandler.h"
#include "core/TransportManager.h"
#include "core/CommandDispatcher.h"

class RadioKit_Widget;

// ── Config object ────────────────────────────────────────────
struct RK_Config {
    // ── User configurable ────────────────────────────────────
    const char* name        = "RadioKit Device";
    const char* password    = "";
    const char* description = "";
    const char* version     = "1.0.0";
    const char* type        = "";
    const char* theme       = "dragon";
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
    void pushUpdate(uint8_t widgetId);
    void pushMetaUpdate(uint8_t widgetId);

    // ── NVS config editing ───────────────────────────────────────
    void setConfig(const char* name, const char* description,
                   const char* devicePassword = nullptr,
                   const char* userPassword = nullptr);
    uint8_t authenticate(const char* password);

    /// True if any level of authentication has succeeded (or no passwords set).
    bool isAuthenticated() const { return _deviceAuthenticated || _userAuthenticated; }

    /// True if device-level (full) access has been granted.
    /// Returns true when no device password is set (pre-authenticated).
    bool hasFullAccess() const { return _deviceAuthenticated || _nvsPwd[0] == '\0'; }

    // ── Print API (transport-agnostic) ─────────────────────────
    size_t print(const char* s);
    size_t print(const String& s);
    size_t print(int val, int base = DEC);
    size_t print(unsigned int val, int base = DEC);
    size_t print(long val, int base = DEC);
    size_t print(unsigned long val, int base = DEC);
    size_t print(double val, int precision = 2);
    size_t print(char c);
    size_t println(const char* s);
    size_t println(const String& s);
    size_t println(int val, int base = DEC);
    size_t println(unsigned int val, int base = DEC);
    size_t println(long val, int base = DEC);
    size_t println(unsigned long val, int base = DEC);
    size_t println(double val, int precision = 2);
    size_t println(char c);
    size_t println();
    size_t printf(const char* format, ...);
    void printFlush();

    // ── Status ───────────────────────────────────────────────
    bool    isConnected() const;
    int8_t  getRssi();
    uint8_t widgetCount() const { return _widgetCount; }

    // ── Filesystem (bulk protocol) ───────────────────────────
    bool enableFS();
    bool beginFs();
    bool isFsReady() const;
    bool formatFs();
    void sendFsFrame(const uint8_t* buf, uint16_t len);

    // ── Internal ─────────────────────────────────────────────
    void _registerWidget(RadioKit_Widget* widget);

private:
    RadioKit_Widget*   _widgets[RADIOKIT_MAX_WIDGETS];
    uint8_t            _widgetCount;
    RadioKitTransport* _transport;

    // ── Page management ──────────────────────────────────────
    uint8_t _activePage = 0;
    uint8_t _numPages   = 1;
    const char* const* _pageNames = nullptr;

    // ── Visibility dirty flag ────────────────────────────────
    bool _confDirty = false;

public:
    /** Switch to a new active page. Sends PAGE_CHANGED + CONF_DATA + VAR_DATA.
     *  If called from user code (not from protocol), also sends CMD_PAGE_SWITCH.
     */
    void setActivePage(uint8_t page);
    uint8_t getActivePage() const { return _activePage; }
    uint8_t getNumPages() const { return _numPages; }
    void setNumPages(uint8_t n) { _numPages = n; }
    void setPageNames(const char* const* names) { _pageNames = names; }

    /// Mark CONF_DATA as needing rebuild (called by Widget on hidden/labelHidden change).
    static void markConfDirty();

private:

    // Additional transport pointers (WiFi, Cloud, Serial) — separate from _transport
    bool _wifiActive;
    bool _cloudActive;
    bool _serialActive;

    // VAR_UPDATE / SET_INPUT batch dispatch
    uint32_t _pendingUpdatesMask;
    uint8_t _varUpdateSeq;

    // META_UPDATE / SET_INPUT batch dispatch
    uint32_t _pendingMetaMask;
    uint8_t _metaUpdateSeq;

    // Shadow state to track implicit input changes by firmware
    uint8_t _shadowInput[RADIOKIT_MAX_WIDGETS][4];
    // Shadow state for output changes (LED, Text, Telemetry)
    uint8_t _shadowOutput[RADIOKIT_MAX_WIDGETS][RADIOKIT_TEXT_LEN + 1];

    uint8_t _txBuf[RK_MAX_PACKET_SIZE];

    friend class ControlCommandHandler;
    friend class FsCommandHandler;
    friend class SettingsCommandHandler;
    friend class OtaCommandHandler;
    friend class PrintCommandHandler;

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
    void _handleSettingsSetCloud(const uint8_t* payload, uint16_t len);
    void _handleSettingsGetCloudInfo();
    void _handleSettingsReboot();
    void _handleGetWifiInfo();
    void _handleSetPage(const uint8_t* payload, uint16_t len);
    void _handleGetPages();
    void _sendSettingsFrame(uint16_t len);

    void _sendPacket(const uint8_t* buf, uint16_t len);
    void _sendPacket(uint16_t len);
    void _sendToAllTransports(const uint8_t* buf, uint16_t len);

    // ── OTA handlers ────────────────────────────────────────────────
    static void _onOtaPacket(uint8_t subCmd,
                              const uint8_t* payload,
                              uint16_t payloadLen);
    static void _onPrintPacket(const uint8_t* payload,
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
    bool _nvsActive;
    bool _deviceAuthenticated;
    bool _userAuthenticated;

    // WiFi / Cloud NVS buffers
    char _nvsStaSsid[RADIOKIT_MAX_SSID + 1];
    char _nvsStaPwd[RADIOKIT_MAX_WIFI_PWD + 1];
    char _nvsCloudUrl[RADIOKIT_MAX_CLOUD_URL + 1];
    char _nvsCloudAccount[RADIOKIT_MAX_CLOUD_ACCOUNT + 1];

    // Device icon name (from kDesignerIcons registry)
    char _nvsDeviceIcon[RADIOKIT_MAX_DEVICE_ICON + 1];

    // Device UID (16 hex chars + null)
    char _nvsDeviceUid[17];

    // Per-transport auth source tracking
    volatile uint8_t _packetSource;

    // ── Print stream circular buffer ─────────────────────────
    static constexpr uint16_t kPrintBufSize = RK_PRINT_BUF_SIZE;
    uint8_t  _printBuf[kPrintBufSize];
    uint16_t _printHead;
    uint16_t _printTail;
    uint16_t _printLineStart;

    void _flushPrintBuffer();
    uint16_t _printSpace() const;
    void _printByte(uint8_t b);

    // Per-transport source wrapper templates (private — used by startXxx())
    template<int S>
    static void _onPktW(uint8_t cmd, const uint8_t* p, uint16_t l);
    template<int S>
    static void _onFsPktW(uint8_t subCmd, const uint8_t* p, uint16_t l);
    template<int S>
    static void _onOtaPktW(uint8_t subCmd, const uint8_t* p, uint16_t l);
    template<int S>
    static void _onSetPktW(uint8_t subCmd, const uint8_t* p, uint16_t l);
    template<int S>
    static void _onPrnPktW(const uint8_t* p, uint16_t l);

    // Internal helpers
    void _syncNvsToBuffers();
    void _setBleAdvertisingName(const char* name);

    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildMetaPayload(uint8_t* buf, uint16_t bufSize);
};

extern RadioKitClass RadioKit;

#endif // RADIOKIT_CLASS_H
