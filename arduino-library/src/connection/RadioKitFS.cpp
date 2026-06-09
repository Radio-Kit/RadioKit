/**
 * RadioKitFS.cpp
 * Bulk filesystem frame parser/builder for RadioKit.
 *
 * Designed to share the same byte stream as the widget protocol (0x55);
 * the FS protocol uses 0xAA as a different start byte. The transport's
 * byte-feeder dispatches to either state machine.
 *
 * Buffer size: 16 KB. This allows up to 16 KB payload chunks for large
 * file transfers without depending on the widget protocol's 768-byte cap.
 */

#include "RadioKitFS.h"
#include <string.h>

// ── Static state (independent of widget protocol state machine) ─────────────
enum FsRxState : uint8_t {
    FS_RX_WAIT_START,
    FS_RX_SUB_CMD,
    FS_RX_LEN_LO,
    FS_RX_LEN_HI,
    FS_RX_PAYLOAD,
};

static FsRxState  s_fsRxState       = FS_RX_WAIT_START;
static uint16_t   s_fsExpectedLen   = 0;
static uint16_t   s_fsBytesRead     = 0;
static uint16_t   s_fsPayloadLen    = 0;
static uint8_t    s_fsBuf[RK_FS_RX_BUFFER_SIZE];

static RK_FsPacketCallback s_fsCallback = nullptr;

// Outgoing scratch buffer — 16 KB. Statically allocated to avoid heap pressure.
static uint8_t s_fsTxBuf[RK_FS_MAX_PAYLOAD + RK_FS_HEADER_SIZE];

// ── Public API ──────────────────────────────────────────────────────────────

void rk_fsRxReset() {
    s_fsRxState     = FS_RX_WAIT_START;
    s_fsExpectedLen = 0;
    s_fsBytesRead   = 0;
    s_fsPayloadLen  = 0;
}

bool rk_fsRxIsActive() {
    return s_fsRxState != FS_RX_WAIT_START;
}

bool rk_fsRxFeedByte(uint8_t byte,
                     uint8_t& outSubCmd,
                     const uint8_t*& outPayload,
                     uint16_t& outPayloadLen)
{
    switch (s_fsRxState) {
        case FS_RX_WAIT_START:
            if (byte == RK_FS_START_BYTE) {
                s_fsBuf[0] = byte;
                s_fsBytesRead = 1;
                s_fsRxState  = FS_RX_SUB_CMD;
            }
            return false;

        case FS_RX_SUB_CMD:
            s_fsBuf[s_fsBytesRead++] = byte;
            s_fsRxState = FS_RX_LEN_LO;
            return false;

        case FS_RX_LEN_LO:
            s_fsBuf[s_fsBytesRead++] = byte;
            s_fsExpectedLen = byte;
            s_fsRxState     = FS_RX_LEN_HI;
            return false;

        case FS_RX_LEN_HI: {
            s_fsBuf[s_fsBytesRead++] = byte;
            s_fsExpectedLen |= ((uint16_t)byte << 8);
            if (s_fsExpectedLen < RK_FS_MIN_FRAME || s_fsExpectedLen > RK_FS_RX_BUFFER_SIZE) {
                rk_fsRxReset();
                return false;
            }
            s_fsPayloadLen = s_fsExpectedLen - RK_FS_HEADER_SIZE;
            s_fsRxState = (s_fsPayloadLen == 0) ? FS_RX_WAIT_START : FS_RX_PAYLOAD;
            // Edge case: empty frame, deliver immediately
            if (s_fsPayloadLen == 0) {
                outSubCmd     = s_fsBuf[1];
                outPayload    = nullptr;
                outPayloadLen = 0;
                rk_fsRxReset();
                return true;
            }
            return false;
        }

        case FS_RX_PAYLOAD:
            s_fsBuf[s_fsBytesRead++] = byte;
            if (s_fsBytesRead >= s_fsExpectedLen) {
                outSubCmd     = s_fsBuf[1];
                outPayload    = &s_fsBuf[RK_FS_HEADER_SIZE];
                outPayloadLen = s_fsPayloadLen;
                rk_fsRxReset();
                return true;
            }
            return false;

        default:
            rk_fsRxReset();
            return false;
    }
}

uint16_t rk_fsBuildFrame(uint8_t* outBuf,
                         uint8_t subCmd,
                         const uint8_t* payload,
                         uint16_t payloadLen)
{
    if (payloadLen > RK_FS_MAX_PAYLOAD) return 0;
    uint16_t totalLen = RK_FS_HEADER_SIZE + payloadLen;
    outBuf[0] = RK_FS_START_BYTE;
    outBuf[1] = subCmd;
    outBuf[2] = (uint8_t)(totalLen & 0xFF);
    outBuf[3] = (uint8_t)((totalLen >> 8) & 0xFF);
    if (payload && payloadLen > 0) {
        memmove(&outBuf[RK_FS_HEADER_SIZE], payload, payloadLen);
    }
    return totalLen;
}

void rk_fsSetCallback(RK_FsPacketCallback cb) {
    s_fsCallback = cb;
}

uint8_t* rk_fsTxBuf() { return s_fsTxBuf; }
uint16_t rk_fsTxBufSize() { return sizeof(s_fsTxBuf); }

const char* rk_fsCmdName(uint8_t subCmd) {
    switch (subCmd) {
        case RK_FS_CMD_LIST:              return "FS_LIST";
        case RK_FS_CMD_READ:              return "FS_READ";
        case RK_FS_CMD_WRITE:             return "FS_WRITE";
        case RK_FS_CMD_DELETE:            return "FS_DELETE";
        case RK_FS_CMD_INFO:              return "FS_INFO";
        case RK_FS_CMD_MKDIR:             return "FS_MKDIR";
        case RK_FS_CMD_RENAME:            return "FS_RENAME";
        case RK_FS_CMD_UPLOAD_BEGIN:      return "FS_UPLOAD_BEGIN";
        case RK_FS_CMD_UPLOAD_CHUNK:      return "FS_UPLOAD_CHUNK";
        case RK_FS_CMD_UPLOAD_END:        return "FS_UPLOAD_END";
        case RK_FS_CMD_FORMAT:            return "FS_FORMAT";
        case RK_FS_RESP_LIST_DATA:        return "FS_LIST_DATA";
        case RK_FS_RESP_READ_DATA:        return "FS_READ_DATA";
        case RK_FS_RESP_WRITE_ACK:        return "FS_WRITE_ACK";
        case RK_FS_RESP_DELETE_ACK:       return "FS_DELETE_ACK";
        case RK_FS_RESP_INFO_DATA:        return "FS_INFO_DATA";
        case RK_FS_RESP_MKDIR_ACK:        return "FS_MKDIR_ACK";
        case RK_FS_RESP_RENAME_ACK:       return "FS_RENAME_ACK";
        case RK_FS_RESP_UPLOAD_BEGIN_ACK: return "FS_UPLOAD_BEGIN_ACK";
        case RK_FS_RESP_UPLOAD_CHUNK_ACK: return "FS_UPLOAD_CHUNK_ACK";
        case RK_FS_RESP_UPLOAD_END_ACK:   return "FS_UPLOAD_END_ACK";
        case RK_FS_RESP_FORMAT_ACK:       return "FS_FORMAT_ACK";
        default:                          return "FS_UNKNOWN";
    }
}

const char* rk_fsErrorName(uint8_t err) {
    switch (err) {
        case RK_FS_ERR_OK:            return "OK";
        case RK_FS_ERR_NOT_FOUND:     return "NOT_FOUND";
        case RK_FS_ERR_IO:            return "IO_ERROR";
        case RK_FS_ERR_NO_FS:         return "NO_FS";
        case RK_FS_ERR_ACCESS_DENIED: return "ACCESS_DENIED";
        case RK_FS_ERR_INVALID_PATH:  return "INVALID_PATH";
        case RK_FS_ERR_OUT_OF_SPACE:  return "OUT_OF_SPACE";
        case RK_FS_ERR_INVALID_STATE: return "INVALID_STATE";
        default:                      return "UNKNOWN";
    }
}
