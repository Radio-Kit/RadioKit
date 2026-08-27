/**
 * RadioKitSettings.h
 * Settings/Info protocol for RadioKit — dedicated protocol for device settings,
 * telemetry, features, chip info, authentication, and config management.
 *
 * Uses a dedicated start byte (0xDD) and a parallel state machine, following
 * the same architecture as the FS protocol (0xAA) and OTA protocol (0xBB).
 *
 * Frame format (no CRC — transport is reliable):
 *   [0xDD][SUB_CMD(1)][LEN_LO(1)][LEN_HI(1)][...PAYLOAD(N)...]
 *   LEN = total frame bytes (header(4) + payload)
 *   MAX payload per frame = RK_SETTINGS_MAX_PAYLOAD (1024)
 *
 * Sub-commands (App → MCU):
 *   0x01  SETTINGS_GET_TELEMETRY   (empty)                                → SETTINGS_TELEMETRY_DATA
 *   0x02  SETTINGS_BLE_INFO        (empty)                                → SETTINGS_BLE_INFO_DATA
 *   0x03  SETTINGS_GET_FEATURES    (empty)                                → SETTINGS_FEATURES_DATA
 *   0x04  SETTINGS_GET_CHIP_INFO   (empty)                                → SETTINGS_CHIP_INFO_DATA
 *   0x05  SETTINGS_SET_CONF        [FIELD_MASK(2 LE)][FIELD_DATA...]       → SETTINGS_SET_CONF_ACK
 *   0x06  SETTINGS_PWD_AUTH        [PWD_LEN(1)][PWD(N)][FLAGS(1)?]        → SETTINGS_PWD_AUTH_ACK
 *   0x07  SETTINGS_FACTORY_RESET   (empty)                                → SETTINGS_FACTORY_RESET_ACK
 *
 * Sub-commands (MCU → App):
 *   0x81  SETTINGS_TELEMETRY_DATA   [RSSI(1)][LATENCY(1)][...]
 *   0x82  SETTINGS_BLE_INFO_DATA    [CONN_INTERVAL_MS(2 LE)][MTU(2 LE)][RSSI(1)]
 *   0x83  SETTINGS_FEATURES_DATA    [BITMASK(1)]
 *   0x84  SETTINGS_CHIP_INFO_DATA   [MODEL_LEN(1)][MODEL...][REV(1)][CORES(1)][FLASH_SIZE(4 LE)][PSRAM_SIZE(4 LE)][SDK_LEN(1)][SDK...][MAC(6)]
 *   0x85  SETTINGS_SET_CONF_ACK     [STATUS(1)]  — echoed field mask or error
 *   0x86  SETTINGS_PWD_AUTH_ACK     [STATUS(1)]  — 0x00 OK, 0x01 mismatch, 0x02 already
 *   0x87  SETTINGS_FACTORY_RESET_ACK [STATUS(1)]
 *
 * Auth codes (PWD_AUTH_ACK):
 *   0x00  OK
 *   0x01  MISMATCH
 *   0x02  ALREADY
 */

#ifndef RADIOKIT_SETTINGS_H
#define RADIOKIT_SETTINGS_H

#include <Arduino.h>
#include <stdint.h>

// ── Frame constants ─────────────────────────────────────────────────────────
#define RK_SETTINGS_START_BYTE      0xDD
#define RK_SETTINGS_HEADER_SIZE     4   // START(1) + SUB_CMD(1) + LEN_LO(1) + LEN_HI(1)
#define RK_SETTINGS_MIN_FRAME       RK_SETTINGS_HEADER_SIZE
#define RK_SETTINGS_MAX_PAYLOAD     1024
#define RK_SETTINGS_RX_BUFFER_SIZE  (RK_SETTINGS_HEADER_SIZE + RK_SETTINGS_MAX_PAYLOAD)

// ── Sub-commands (App → MCU) ────────────────────────────────────────────────
#define RK_SETTINGS_CMD_GET_TELEMETRY    0x01
#define RK_SETTINGS_CMD_BLE_INFO         0x02
#define RK_SETTINGS_CMD_GET_FEATURES     0x03
#define RK_SETTINGS_CMD_GET_CHIP_INFO    0x04
#define RK_SETTINGS_CMD_SET_CONF         0x05
#define RK_SETTINGS_CMD_PWD_AUTH         0x06
#define RK_SETTINGS_CMD_FACTORY_RESET    0x07
#define RK_SETTINGS_CMD_GET_DEVICE_INFO  0x08
#define RK_SETTINGS_CMD_NVS_RAW_READ     0x09
#define RK_SETTINGS_CMD_NVS_RAW_WRITE    0x0A
#define RK_SETTINGS_CMD_SET_WIFI         0x0B
#define RK_SETTINGS_CMD_GET_CLOUD_INFO  0x0C
#define RK_SETTINGS_CMD_REBOOT            0x0D
#define RK_SETTINGS_CMD_SET_CLOUD_INFO   0x0E

// ── Sub-commands (MCU → App) ────────────────────────────────────────────────
// Response = subCmd | 0x80
#define RK_SETTINGS_RESP_TELEMETRY_DATA     0x81
#define RK_SETTINGS_RESP_BLE_INFO_DATA      0x82
#define RK_SETTINGS_RESP_FEATURES_DATA      0x83
#define RK_SETTINGS_RESP_CHIP_INFO_DATA     0x84
#define RK_SETTINGS_RESP_SET_CONF_ACK       0x85
#define RK_SETTINGS_RESP_PWD_AUTH_ACK       0x86
#define RK_SETTINGS_RESP_FACTORY_RESET_ACK  0x87
#define RK_SETTINGS_RESP_DEVICE_INFO_DATA   0x88
#define RK_SETTINGS_RESP_NVS_RAW_READ_DATA  0x89
#define RK_SETTINGS_RESP_NVS_RAW_WRITE_ACK  0x8A
#define RK_SETTINGS_RESP_SET_WIFI_ACK       0x8B
#define RK_SETTINGS_RESP_CLOUD_INFO_DATA    0x8C
#define RK_SETTINGS_RESP_REBOOT_ACK          0x8D
#define RK_SETTINGS_RESP_SET_CLOUD_INFO_ACK   0x8E

// ── SET_CLOUD_INFO field mask bits ──────────────────────────────────────────
#define RK_SETTINGS_SET_CLOUD_URL       (1 << 0)
#define RK_SETTINGS_SET_CLOUD_ACCOUNT   (1 << 1)

// ── NVS_RAW_READ/WRITE status codes ─────────────────────────────────────────
#define RK_SETTINGS_NVS_RAW_OK        0x00
#define RK_SETTINGS_NVS_RAW_ERROR     0x01

// ── PWD_AUTH status codes ───────────────────────────────────────────────────
#define RK_SETTINGS_PWD_DEVICE      0x00   ///< Authenticated as device (full access)
#define RK_SETTINGS_PWD_USER        0x01   ///< Authenticated as user (widgets-only)
#define RK_SETTINGS_PWD_DENIED      0x02   ///< Password did not match

// ── PWD_AUTH flags byte (deprecated — no longer sent by new apps) ──────────
#define RK_SETTINGS_PWD_FLAG_ADMIN   (1 << 0)

// ── SET_CONF field mask bits ────────────────────────────────────────────────
#define RK_SETTINGS_SET_CONF_NAME        (1 << 0)
#define RK_SETTINGS_SET_CONF_DESC        (1 << 1)
#define RK_SETTINGS_SET_CONF_DEVICE_PWD  (1 << 2)   ///< Device password (was SET_CONF_PWD)
#define RK_SETTINGS_SET_CONF_USER_PWD    (1 << 3)   ///< User password (was SET_CONF_ADMIN_PWD)
#define RK_SETTINGS_SET_CONF_ICON        (1 << 4)   ///< Device icon string
#define RK_SETTINGS_SET_CONF_ERROR       (1 << 7)

// ── SET_WIFI field mask bits ────────────────────────────────────────────────
#define RK_SETTINGS_SET_WIFI_SSID        (1 << 0)
#define RK_SETTINGS_SET_WIFI_PWD         (1 << 1)

// ── Feature bitmask bits ────────────────────────────────────────────────────
#define RK_SETTINGS_FEATURE_OTA             (1 << 0)
#define RK_SETTINGS_FEATURE_FILESYSTEM      (1 << 1)
#define RK_SETTINGS_FEATURE_HAS_DEVICE_PWD  (1 << 2)   ///< Device password set (was HAS_CONN_PWD)
#define RK_SETTINGS_FEATURE_HAS_USER_PWD    (1 << 3)   ///< User password set (was HAS_ADMIN_PWD)
#define RK_SETTINGS_FEATURE_WIFI            (1 << 4)
#define RK_SETTINGS_FEATURE_CLOUD           (1 << 5)
#define RK_SETTINGS_FEATURE_BLE             (1 << 6)   ///< BLE transport compiled in
#define RK_SETTINGS_FEATURE_PRINT_STREAM    (1 << 7)   ///< 0xEE print stream supported

// ── Callback signature ───────────────────────────────────────────────────────
typedef void (*RK_SettingsPacketCallback)(uint8_t subCmd,
                                          const uint8_t* payload,
                                          uint16_t payloadLen);

// ── Public API ──────────────────────────────────────────────────────────────

/**
 * Reset the Settings state machine. Call on transport disconnect / timeout.
 */
void rk_settingsRxReset();

/**
 * Returns true if the Settings parser is currently accumulating a frame.
 */
bool rk_settingsRxIsActive();

/**
 * Feed a single byte into the Settings state machine.
 * Returns true when a complete frame is available.
 */
bool rk_settingsRxFeedByte(uint8_t byte,
                           uint8_t& outSubCmd,
                           const uint8_t*& outPayload,
                           uint16_t& outPayloadLen);

/**
 * Build a complete Settings frame into [outBuf].
 * Returns the total frame length, or 0 if [payloadLen] exceeds RK_SETTINGS_MAX_PAYLOAD.
 */
uint16_t rk_settingsBuildFrame(uint8_t* outBuf,
                               uint8_t subCmd,
                               const uint8_t* payload,
                               uint16_t payloadLen);

/**
 * Callback registration. Set once at startup.
 */
void rk_settingsSetCallback(RK_SettingsPacketCallback cb);

/**
 * Get the tx scratch buffer.
 */
uint8_t* rk_settingsTxBuf();
uint16_t rk_settingsTxBufSize();

/**
 * Command/error name helpers (for debug logging).
 */
const char* rk_settingsCmdName(uint8_t subCmd);

/**
 * Returns the millis() value captured when the most recent complete Settings
 * frame was received. Used by the telemetry handler to compute round-trip
 * request-to-response latency. Transport-agnostic.
 */
uint32_t rk_settingsLastRxTimestamp();

#endif // RADIOKIT_SETTINGS_H
