/**
 * RadioKitOTA.cpp
 * OTA protocol frame parser/builder for RadioKit.
 *
 * Designed to share the same byte stream as the widget (0x55) and FS (0xAA)
 * protocols; the OTA protocol uses 0xBB as its start byte. The transport's
 * byte-feeder dispatches to whichever state machine based on frame ownership.
 *
 * Buffer size: 4 KB header + 4 KB payload = ~4.1 KB. This matches the 4 KB
 * OTA chunk size and keeps memory usage low compared to the FS parser's 16 KB.
 *
 * Implementation uses ESP32's Update.h for OTA partition management.
 */

#include "RadioKitOTA.h"
#include <string.h>

// ── Static state (independent of widget/FS state machines) ─────────────────
enum OtaRxState : uint8_t {
    OTA_RX_WAIT_START,
    OTA_RX_SUB_CMD,
    OTA_RX_LEN_LO,
    OTA_RX_LEN_HI,
    OTA_RX_PAYLOAD,
};

static OtaRxState  s_otaRxState       = OTA_RX_WAIT_START;
static uint16_t    s_otaExpectedLen   = 0;
static uint16_t    s_otaBytesRead     = 0;
static uint16_t    s_otaPayloadLen    = 0;
static uint8_t     s_otaBuf[RK_OTA_RX_BUFFER_SIZE];

static RK_OtaPacketCallback s_otaCallback = nullptr;

// Outgoing scratch buffer.
static uint8_t s_otaTxBuf[RK_OTA_HEADER_SIZE + RK_OTA_MAX_PAYLOAD];

// ── Public API ──────────────────────────────────────────────────────────────

void rk_otaRxReset() {
    s_otaRxState     = OTA_RX_WAIT_START;
    s_otaExpectedLen = 0;
    s_otaBytesRead   = 0;
    s_otaPayloadLen  = 0;
}

bool rk_otaRxIsActive() {
    return s_otaRxState != OTA_RX_WAIT_START;
}

bool rk_otaRxFeedByte(uint8_t byte,
                      uint8_t& outSubCmd,
                      const uint8_t*& outPayload,
                      uint16_t& outPayloadLen)
{
    switch (s_otaRxState) {
        case OTA_RX_WAIT_START:
            if (byte == RK_OTA_START_BYTE) {
                s_otaBuf[0] = byte;
                s_otaBytesRead = 1;
                s_otaRxState  = OTA_RX_SUB_CMD;
            }
            return false;

        case OTA_RX_SUB_CMD:
            s_otaBuf[s_otaBytesRead++] = byte;
            s_otaRxState = OTA_RX_LEN_LO;
            return false;

        case OTA_RX_LEN_LO:
            s_otaBuf[s_otaBytesRead++] = byte;
            s_otaExpectedLen = byte;
            s_otaRxState     = OTA_RX_LEN_HI;
            return false;

        case OTA_RX_LEN_HI: {
            s_otaBuf[s_otaBytesRead++] = byte;
            s_otaExpectedLen |= ((uint16_t)byte << 8);
            if (s_otaExpectedLen < RK_OTA_MIN_FRAME || s_otaExpectedLen > RK_OTA_RX_BUFFER_SIZE) {
                rk_otaRxReset();
                return false;
            }
            s_otaPayloadLen = s_otaExpectedLen - RK_OTA_HEADER_SIZE;
            s_otaRxState = (s_otaPayloadLen == 0) ? OTA_RX_WAIT_START : OTA_RX_PAYLOAD;
            // Edge case: empty frame, deliver immediately
            if (s_otaPayloadLen == 0) {
                outSubCmd     = s_otaBuf[1];
                outPayload    = nullptr;
                outPayloadLen = 0;
                rk_otaRxReset();
                return true;
            }
            return false;
        }

        case OTA_RX_PAYLOAD:
            s_otaBuf[s_otaBytesRead++] = byte;
            if (s_otaBytesRead >= s_otaExpectedLen) {
                outSubCmd     = s_otaBuf[1];
                outPayload    = &s_otaBuf[RK_OTA_HEADER_SIZE];
                outPayloadLen = s_otaPayloadLen;
                rk_otaRxReset();
                return true;
            }
            return false;

        default:
            rk_otaRxReset();
            return false;
    }
}

uint16_t rk_otaBuildFrame(uint8_t* outBuf,
                          uint8_t subCmd,
                          const uint8_t* payload,
                          uint16_t payloadLen)
{
    if (payloadLen > RK_OTA_MAX_PAYLOAD) return 0;
    uint16_t totalLen = RK_OTA_HEADER_SIZE + payloadLen;
    outBuf[0] = RK_OTA_START_BYTE;
    outBuf[1] = subCmd;
    outBuf[2] = (uint8_t)(totalLen & 0xFF);
    outBuf[3] = (uint8_t)((totalLen >> 8) & 0xFF);
    if (payload && payloadLen > 0) {
        memmove(&outBuf[RK_OTA_HEADER_SIZE], payload, payloadLen);
    }
    return totalLen;
}

void rk_otaSetCallback(RK_OtaPacketCallback cb) {
    s_otaCallback = cb;
}

uint8_t* rk_otaTxBuf() { return s_otaTxBuf; }
uint16_t rk_otaTxBufSize() { return sizeof(s_otaTxBuf); }

const char* rk_otaCmdName(uint8_t subCmd) {
    switch (subCmd) {
        case RK_OTA_CMD_BEGIN:          return "OTA_BEGIN";
        case RK_OTA_CMD_CHUNK:          return "OTA_CHUNK";
        case RK_OTA_CMD_END:            return "OTA_END";
        case RK_OTA_CMD_ABORT:          return "OTA_ABORT";
        case RK_OTA_CMD_SET_ERASE_FLAG: return "OTA_SET_ERASE";
        case RK_OTA_RESP_ACK:           return "OTA_ACK";
        case RK_OTA_RESP_PROGRESS:      return "OTA_PROGRESS";
        default:                        return "OTA_UNKNOWN";
    }
}

const char* rk_otaErrorName(uint8_t err) {
    switch (err) {
        case RK_OTA_ERR_OK:            return "OK";
        case RK_OTA_ERR_NO_SPACE:      return "NO_SPACE";
        case RK_OTA_ERR_CRC:           return "CRC_MISMATCH";
        case RK_OTA_ERR_FLASH:         return "FLASH_ERROR";
        case RK_OTA_ERR_SEQ:           return "SEQ_ERROR";
        case RK_OTA_ERR_INVALID_STATE: return "INVALID_STATE";
        case RK_OTA_ERR_NOT_SUPPORTED: return "NOT_SUPPORTED";
        default:                       return "UNKNOWN";
    }
}
