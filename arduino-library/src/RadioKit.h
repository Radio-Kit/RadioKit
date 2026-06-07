/**
 * RadioKit.h
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
    static void _sendFsFrame(const uint8_t* buf, uint16_t len);

    void _handleGetConf();
    void _handleGetVars();
    void _handleGetMeta();
    void _handleSetInput(const uint8_t* payload, uint16_t len);
    void _handlePing();
    void _handleAck(const uint8_t* payload, uint16_t len);
    void _handleVarUpdate(const uint8_t* payload, uint16_t len);
    void _handleMetaUpdate(const uint8_t* payload, uint16_t len);
    void _handleGetTelemetry();
    void _handleBleInfo();
    void _sendPacket(const uint8_t* buf, uint16_t len);
    void _sendPacket(uint16_t len);

    uint16_t _buildConfPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildVarPayload(uint8_t* buf, uint16_t bufSize);
    uint16_t _buildMetaPayload(uint8_t* buf, uint16_t bufSize);
};

extern RadioKitClass RadioKit;

#include "RadioKitWidgets.h"

#endif // RADIOKIT_H
