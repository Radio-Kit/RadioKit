/**
 * RadioKitSettings.cpp
 * Settings/Info protocol frame parser/builder for RadioKit.
 *
 * Uses dedicated start byte 0xDD. Follows same architecture as FS (0xAA)
 * and OTA (0xBB) protocols. No CRC — transport reliability is sufficient.
 */

#include "RadioKitSettings.h"
#include <string.h>

// ── Static state ─────────────────────────────────────────────────────────────
enum SettingsRxState : uint8_t {
    SETTINGS_RX_WAIT_START,
    SETTINGS_RX_SUB_CMD,
    SETTINGS_RX_LEN_LO,
    SETTINGS_RX_LEN_HI,
    SETTINGS_RX_PAYLOAD,
};

static SettingsRxState  s_rxState         = SETTINGS_RX_WAIT_START;
static uint16_t         s_expectedLen     = 0;
static uint16_t         s_bytesRead       = 0;
static uint16_t         s_payloadLen      = 0;
static uint8_t          s_buf[RK_SETTINGS_RX_BUFFER_SIZE];
static RK_SettingsPacketCallback s_callback = nullptr;

// Outgoing scratch buffer
static uint8_t s_txBuf[RK_SETTINGS_HEADER_SIZE + RK_SETTINGS_MAX_PAYLOAD];

// Timestamp of the most recently completed frame reception (millis).
// Set when a complete frame is parsed; consumed by _handleSettingsTelemetry()
// to compute round-trip latency. Transport-agnostic.
static uint32_t s_lastRxTimestamp = 0;

// ── Public API ──────────────────────────────────────────────────────────────

void rk_settingsRxReset() {
    s_rxState     = SETTINGS_RX_WAIT_START;
    s_expectedLen = 0;
    s_bytesRead   = 0;
    s_payloadLen  = 0;
    s_lastRxTimestamp = millis();
}

uint32_t rk_settingsLastRxTimestamp() {
    return s_lastRxTimestamp;
}

bool rk_settingsRxIsActive() {
    return s_rxState != SETTINGS_RX_WAIT_START;
}

bool rk_settingsRxFeedByte(uint8_t byte,
                           uint8_t& outSubCmd,
                           const uint8_t*& outPayload,
                           uint16_t& outPayloadLen)
{
    switch (s_rxState) {
        case SETTINGS_RX_WAIT_START:
            if (byte == RK_SETTINGS_START_BYTE) {
                s_buf[0] = byte;
                s_bytesRead = 1;
                s_rxState  = SETTINGS_RX_SUB_CMD;
            }
            return false;

        case SETTINGS_RX_SUB_CMD:
            s_buf[s_bytesRead++] = byte;
            s_rxState = SETTINGS_RX_LEN_LO;
            return false;

        case SETTINGS_RX_LEN_LO:
            s_buf[s_bytesRead++] = byte;
            s_expectedLen = byte;
            s_rxState     = SETTINGS_RX_LEN_HI;
            return false;

        case SETTINGS_RX_LEN_HI: {
            s_buf[s_bytesRead++] = byte;
            s_expectedLen |= ((uint16_t)byte << 8);
            if (s_expectedLen < RK_SETTINGS_MIN_FRAME ||
                s_expectedLen > RK_SETTINGS_RX_BUFFER_SIZE) {
                rk_settingsRxReset();
                return false;
            }
            s_payloadLen = s_expectedLen - RK_SETTINGS_HEADER_SIZE;
            s_rxState = (s_payloadLen == 0) ? SETTINGS_RX_WAIT_START : SETTINGS_RX_PAYLOAD;
            if (s_payloadLen == 0) {
                s_lastRxTimestamp = millis();
                outSubCmd     = s_buf[1];
                outPayload    = nullptr;
                outPayloadLen = 0;
                rk_settingsRxReset();
                return true;
            }
            return false;
        }

        case SETTINGS_RX_PAYLOAD:
            s_buf[s_bytesRead++] = byte;
            if (s_bytesRead >= s_expectedLen) {
                s_lastRxTimestamp = millis();
                outSubCmd     = s_buf[1];
                outPayload    = &s_buf[RK_SETTINGS_HEADER_SIZE];
                outPayloadLen = s_payloadLen;
                rk_settingsRxReset();
                return true;
            }
            return false;

        default:
            rk_settingsRxReset();
            return false;
    }
}

uint16_t rk_settingsBuildFrame(uint8_t* outBuf,
                               uint8_t subCmd,
                               const uint8_t* payload,
                               uint16_t payloadLen)
{
    if (payloadLen > RK_SETTINGS_MAX_PAYLOAD) return 0;
    uint16_t totalLen = RK_SETTINGS_HEADER_SIZE + payloadLen;
    outBuf[0] = RK_SETTINGS_START_BYTE;
    outBuf[1] = subCmd;
    outBuf[2] = (uint8_t)(totalLen & 0xFF);
    outBuf[3] = (uint8_t)((totalLen >> 8) & 0xFF);
    if (payload && payloadLen > 0) {
        memmove(&outBuf[RK_SETTINGS_HEADER_SIZE], payload, payloadLen);
    }
    return totalLen;
}

void rk_settingsSetCallback(RK_SettingsPacketCallback cb) {
    s_callback = cb;
}

uint8_t* rk_settingsTxBuf() { return s_txBuf; }
uint16_t rk_settingsTxBufSize() { return sizeof(s_txBuf); }

const char* rk_settingsCmdName(uint8_t subCmd) {
    switch (subCmd) {
        case RK_SETTINGS_CMD_GET_TELEMETRY:   return "SETTINGS_GET_TELEMETRY";
        case RK_SETTINGS_CMD_BLE_INFO:        return "SETTINGS_BLE_INFO";
        case RK_SETTINGS_CMD_GET_FEATURES:    return "SETTINGS_GET_FEATURES";
        case RK_SETTINGS_CMD_GET_CHIP_INFO:   return "SETTINGS_GET_CHIP_INFO";
        case RK_SETTINGS_CMD_SET_CONF:        return "SETTINGS_SET_CONF";
        case RK_SETTINGS_CMD_PWD_AUTH:        return "SETTINGS_PWD_AUTH";
        case RK_SETTINGS_CMD_FACTORY_RESET:   return "SETTINGS_FACTORY_RESET";
        case RK_SETTINGS_CMD_GET_DEVICE_INFO: return "SETTINGS_GET_DEVICE_INFO";
        case RK_SETTINGS_CMD_NVS_RAW_READ:    return "SETTINGS_NVS_RAW_READ";
        case RK_SETTINGS_CMD_NVS_RAW_WRITE:   return "SETTINGS_NVS_RAW_WRITE";
        case RK_SETTINGS_CMD_GET_CLOUD_INFO:    return "SETTINGS_GET_CLOUD_INFO";
        case RK_SETTINGS_CMD_SET_CLOUD_INFO:    return "SETTINGS_SET_CLOUD_INFO";
        case RK_SETTINGS_CMD_REBOOT:            return "SETTINGS_REBOOT";
        case RK_SETTINGS_RESP_CLOUD_INFO_DATA:  return "SETTINGS_CLOUD_INFO_DATA";
        case RK_SETTINGS_RESP_SET_CLOUD_INFO_ACK: return "SETTINGS_SET_CLOUD_INFO_ACK";
        case RK_SETTINGS_RESP_REBOOT_ACK:       return "SETTINGS_REBOOT_ACK";
        case RK_SETTINGS_RESP_NVS_RAW_READ_DATA: return "SETTINGS_NVS_RAW_READ_DATA";
        case RK_SETTINGS_RESP_NVS_RAW_WRITE_ACK: return "SETTINGS_NVS_RAW_WRITE_ACK";
        case RK_SETTINGS_RESP_TELEMETRY_DATA:     return "SETTINGS_TELEMETRY_DATA";
        case RK_SETTINGS_RESP_BLE_INFO_DATA:      return "SETTINGS_BLE_INFO_DATA";
        case RK_SETTINGS_RESP_FEATURES_DATA:      return "SETTINGS_FEATURES_DATA";
        case RK_SETTINGS_RESP_CHIP_INFO_DATA:     return "SETTINGS_CHIP_INFO_DATA";
        case RK_SETTINGS_RESP_SET_CONF_ACK:       return "SETTINGS_SET_CONF_ACK";
        case RK_SETTINGS_RESP_PWD_AUTH_ACK:       return "SETTINGS_PWD_AUTH_ACK";
        case RK_SETTINGS_RESP_FACTORY_RESET_ACK:  return "SETTINGS_FACTORY_RESET_ACK";
        case RK_SETTINGS_RESP_DEVICE_INFO_DATA:   return "SETTINGS_DEVICE_INFO_DATA";
        default:                                  return "SETTINGS_UNKNOWN";
    }
}
