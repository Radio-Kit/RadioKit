/**
 * RadioKitProtocol.cpp
 * CRC-16/CCITT, packet builder, receive-side state-machine parser. (Protocol v3)
 */

#include "RadioKitProtocol.h"
#include <string.h>

// ─────────────────────────────────────────────
//  CRC-16/CCITT-FALSE  (poly 0x1021, init 0xFFFF)
// ─────────────────────────────────────────────
uint16_t rk_crc16(const uint8_t* data, uint16_t len) {
    uint16_t crc = 0xFFFF;
    for (uint16_t i = 0; i < len; i++) {
        crc ^= ((uint16_t)data[i]) << 8;
        for (uint8_t bit = 0; bit < 8; bit++) {
            crc = (crc & 0x8000) ? (crc << 1) ^ 0x1021 : (crc << 1);
        }
    }
    return crc;
}

// ─────────────────────────────────────────────
//  Packet builder
// ─────────────────────────────────────────────
uint16_t rk_buildPacket(uint8_t* outBuf,
                        uint8_t  cmd,
                        const uint8_t* payload,
                        uint16_t payloadLen)
{
    uint16_t totalLen = RK_HEADER_SIZE + payloadLen + RK_CRC_SIZE;
    outBuf[0] = RK_START_BYTE;
    outBuf[1] = (uint8_t)(totalLen & 0xFF);
    outBuf[2] = (uint8_t)((totalLen >> 8) & 0xFF);
    outBuf[3] = cmd;
    if (payload && payloadLen > 0) memcpy(&outBuf[4], payload, payloadLen);
    uint16_t crc = rk_crc16(&outBuf[3], 1 + payloadLen);
    uint16_t crcOffset = RK_HEADER_SIZE + payloadLen;
    outBuf[crcOffset]     = (uint8_t)(crc & 0xFF);
    outBuf[crcOffset + 1] = (uint8_t)((crc >> 8) & 0xFF);
    return totalLen;
}

uint16_t rk_buildAck(uint8_t* outBuf, uint8_t seq) {
    return rk_buildPacket(outBuf, RK_CMD_ACK, &seq, 1);
}

// ─────────────────────────────────────────────
//  Receive-side state machine
// ─────────────────────────────────────────────
enum RxState : uint8_t {
    RX_WAIT_START,
    RX_LENGTH_LO,
    RX_LENGTH_HI,
    RX_CMD,
    RX_PAYLOAD,
    RX_CRC_LO,
    RX_CRC_HI
};

static RxState   s_rxState       = RX_WAIT_START;
static uint16_t  s_rxExpectedLen = 0;
static uint16_t  s_rxBytesRead   = 0;
static uint8_t   s_rxBuf[RK_RX_BUFFER_SIZE];
static uint16_t  s_rxPayloadLen  = 0;

void rk_rxReset() {
    s_rxState       = RX_WAIT_START;
    s_rxExpectedLen = 0;
    s_rxBytesRead   = 0;
    s_rxPayloadLen  = 0;
}

bool rk_rxIsActive() {
    return s_rxState != RX_WAIT_START;
}

bool rk_rxFeedByte(uint8_t byte,
                   uint8_t& outCmd,
                   const uint8_t*& outPayload,
                   uint16_t& outPayloadLen)
{
    switch (s_rxState) {
        case RX_WAIT_START:
            if (byte == RK_START_BYTE) {
                s_rxBuf[0] = byte; s_rxBytesRead = 1;
                s_rxState  = RX_LENGTH_LO;
            }
            break;

        case RX_LENGTH_LO:
            s_rxBuf[s_rxBytesRead++] = byte;
            s_rxExpectedLen = byte;
            s_rxState = RX_LENGTH_HI;
            break;

        case RX_LENGTH_HI:
            s_rxBuf[s_rxBytesRead++] = byte;
            s_rxExpectedLen |= ((uint16_t)byte << 8);
            if (s_rxExpectedLen < RK_MIN_PACKET || s_rxExpectedLen > RK_RX_BUFFER_SIZE)
                rk_rxReset();
            else
                s_rxState = RX_CMD;
            break;

        case RX_CMD:
            s_rxBuf[s_rxBytesRead++] = byte;
            s_rxPayloadLen = s_rxExpectedLen - RK_HEADER_SIZE - RK_CRC_SIZE;
            s_rxState = (s_rxPayloadLen == 0) ? RX_CRC_LO : RX_PAYLOAD;
            break;

        case RX_PAYLOAD:
            s_rxBuf[s_rxBytesRead++] = byte;
            if (s_rxBytesRead >= RK_HEADER_SIZE + s_rxPayloadLen)
                s_rxState = RX_CRC_LO;
            break;

        case RX_CRC_LO:
            s_rxBuf[s_rxBytesRead++] = byte;
            s_rxState = RX_CRC_HI;
            break;

        case RX_CRC_HI: {
            s_rxBuf[s_rxBytesRead++] = byte;
            uint16_t receivedCrc = (uint16_t)s_rxBuf[s_rxBytesRead - 2] |
                                   ((uint16_t)s_rxBuf[s_rxBytesRead - 1] << 8);
            uint16_t computedCrc = rk_crc16(&s_rxBuf[3], 1 + s_rxPayloadLen);
            if (receivedCrc != computedCrc) { rk_rxReset(); return false; }
            outCmd        = s_rxBuf[3];
            outPayload    = &s_rxBuf[4];
            outPayloadLen = s_rxPayloadLen;
            s_rxState     = RX_WAIT_START;
            s_rxBytesRead = 0;
            s_rxExpectedLen = 0;
            return true;
        }

        default:
            rk_rxReset();
            break;
    }
    return false;
}

const char* rk_cmdName(uint8_t cmd) {
    switch (cmd) {
        case RK_CMD_GET_CONF:      return "GET_CONF";
        case RK_CMD_CONF_DATA:     return "CONF_DATA";
        // PING/PONG removed; connection health is transport-driven.
        case RK_CMD_ACK:           return "ACK";
        case RK_CMD_GET_VARS:      return "GET_VARS";
        case RK_CMD_VAR_DATA:      return "VAR_DATA";
        case RK_CMD_VAR_UPDATE:    return "VAR_UPDATE";
        case RK_CMD_GET_META:      return "GET_META";
        case RK_CMD_META_DATA:     return "META_DATA";
        case RK_CMD_META_UPDATE:   return "META_UPDATE";
        case RK_CMD_SET_INPUT:     return "SET_INPUT";
        default:                   return "UNKNOWN";
    }
}
