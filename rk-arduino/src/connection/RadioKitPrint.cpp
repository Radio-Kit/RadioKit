/**
 * RadioKitPrint.cpp
 * Print/Debug stream frame parser/builder for RadioKit.
 *
 * Uses dedicated start byte 0xEE. Unidirectional — device to app only.
 * Follows same architecture as Settings (0xDD), FS (0xAA), and OTA (0xBB).
 */

#include "RadioKitPrint.h"
#include <string.h>

// ── Static state ─────────────────────────────────────────────────────────────
enum PrintRxState : uint8_t {
    PRINT_RX_WAIT_START,
    PRINT_RX_LEN_LO,
    PRINT_RX_LEN_HI,
    PRINT_RX_PAYLOAD,
};

static PrintRxState  s_rxState       = PRINT_RX_WAIT_START;
static uint16_t      s_expectedLen   = 0;
static uint16_t      s_bytesRead     = 0;
static uint16_t      s_payloadLen    = 0;
static uint8_t       s_buf[RK_PRINT_RX_BUFFER_SIZE];

// Outgoing scratch buffer
static uint8_t s_txBuf[RK_PRINT_HEADER_SIZE + RK_PRINT_MAX_PAYLOAD];

// ── Public API ──────────────────────────────────────────────────────────────

void rk_printRxReset() {
    s_rxState     = PRINT_RX_WAIT_START;
    s_expectedLen = 0;
    s_bytesRead   = 0;
    s_payloadLen  = 0;
}

bool rk_printRxIsActive() {
    return s_rxState != PRINT_RX_WAIT_START;
}

bool rk_printRxFeedByte(uint8_t byte,
                        const uint8_t*& outPayload,
                        uint16_t& outPayloadLen)
{
    switch (s_rxState) {
        case PRINT_RX_WAIT_START:
            if (byte == RK_PRINT_START_BYTE) {
                s_buf[0] = byte;
                s_bytesRead = 1;
                s_rxState  = PRINT_RX_LEN_LO;
            }
            return false;

        case PRINT_RX_LEN_LO:
            s_buf[s_bytesRead++] = byte;
            s_expectedLen = byte;
            s_rxState     = PRINT_RX_LEN_HI;
            return false;

        case PRINT_RX_LEN_HI: {
            s_buf[s_bytesRead++] = byte;
            s_expectedLen |= ((uint16_t)byte << 8);
            if (s_expectedLen < RK_PRINT_MIN_FRAME ||
                s_expectedLen > RK_PRINT_RX_BUFFER_SIZE) {
                rk_printRxReset();
                return false;
            }
            s_payloadLen = s_expectedLen - RK_PRINT_HEADER_SIZE;
            s_rxState = (s_payloadLen == 0) ? PRINT_RX_WAIT_START : PRINT_RX_PAYLOAD;
            if (s_payloadLen == 0) {
                outPayload    = nullptr;
                outPayloadLen = 0;
                rk_printRxReset();
                return true;
            }
            return false;
        }

        case PRINT_RX_PAYLOAD:
            s_buf[s_bytesRead++] = byte;
            if (s_bytesRead >= s_expectedLen) {
                outPayload    = &s_buf[RK_PRINT_HEADER_SIZE];
                outPayloadLen = s_payloadLen;
                rk_printRxReset();
                return true;
            }
            return false;

        default:
            rk_printRxReset();
            return false;
    }
}

uint16_t rk_printBuildFrame(uint8_t* outBuf,
                            const uint8_t* payload,
                            uint16_t payloadLen)
{
    if (payloadLen > RK_PRINT_MAX_PAYLOAD) return 0;
    uint16_t totalLen = RK_PRINT_HEADER_SIZE + payloadLen;
    outBuf[0] = RK_PRINT_START_BYTE;
    outBuf[1] = (uint8_t)(totalLen & 0xFF);
    outBuf[2] = (uint8_t)((totalLen >> 8) & 0xFF);
    if (payload && payloadLen > 0) {
        memmove(&outBuf[RK_PRINT_HEADER_SIZE], payload, payloadLen);
    }
    return totalLen;
}

uint8_t* rk_printTxBuf() { return s_txBuf; }
uint16_t rk_printTxBufSize() { return sizeof(s_txBuf); }

const char* rk_printCmdName() {
    return "PRINT_DATA";
}
