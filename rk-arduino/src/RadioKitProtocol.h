/**
 * RadioKitProtocol.h
 * Binary protocol constants, packet building, and CRC-16/CCITT utilities.
 *
 * Protocol v3 packet format:
 *   [0x55][LENGTH_LO][LENGTH_HI][CMD][PAYLOAD...][CRC_LO][CRC_HI]
 *   LENGTH = total packet bytes
 *   CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) over CMD + PAYLOAD
 */

#ifndef RADIOKIT_PROTOCOL_H
#define RADIOKIT_PROTOCOL_H

#include <Arduino.h>
#include <stdint.h>

// ─────────────────────────────────────────────
//  Packet framing
// ─────────────────────────────────────────────
#define RK_START_BYTE 0x55
#define RK_HEADER_SIZE 4 // START + LENGTH_LO + LENGTH_HI + CMD
#define RK_CRC_SIZE 2
#define RK_MIN_PACKET 6 // header(4) + crc(2)

// ─────────────────────────────────────────────
//  Command IDs (Protocol v4 — settings moved to 0xDD)
// ─────────────────────────────────────────────
#define RK_CMD_GET_CONF 0x01    // App → Arduino: request widget config
#define RK_CMD_CONF_DATA 0x02   // Arduino → App: widget config payload (UI only)
// RK_CMD_PING/PONG were 0x03/0x04 — removed in v4.2; connection health is transport-driven.
#define RK_CMD_ACK 0x05         // Both: acknowledge SET_INPUT or VAR_UPDATE
#define RK_CMD_GET_VARS 0x06    // App → Arduino: request all variables
#define RK_CMD_VAR_DATA 0x07    // Arduino → App: variable values (full sync)
#define RK_CMD_VAR_UPDATE 0x08  // Both: partial update of few variables
#define RK_CMD_GET_META 0x09    // App → Arduino: request all metadata
#define RK_CMD_META_DATA 0x0A   // Arduino → App: metadata of all widgets
#define RK_CMD_META_UPDATE 0x0B // Both: metadata of partial widgets
#define RK_CMD_SET_INPUT 0x0C   // Arduino → App: force sync input widget
#define RK_CMD_GET_WIFI_INFO 0x1D   // App → Arduino: request WiFi status
#define RK_CMD_WIFI_INFO_DATA 0x1E // Arduino → App: WiFi status payload
// Settings sub-commands are in RadioKitSettings.h (0xDD protocol).
// REBOOT: 0x0D in settings protocol — reboot without erasing NVS.

// ── Page management commands ─────────────────────────────────────────────
#define RK_CMD_SET_PAGE     0x20  // App → Arduino: switch to page N
#define RK_CMD_PAGE_CHANGED 0x21  // Arduino → App: page switch acknowledged
#define RK_CMD_GET_PAGES    0x22  // App → Arduino: request page names
#define RK_CMD_PAGES_DATA   0x23  // Arduino → App: page names payload
#define RK_CMD_PAGE_SWITCH  0x24  // Arduino → App: device-initiated page switch

// ── PWD_AUTH response codes (used by public API RadioKitClass::authenticate) ─
#define RK_PWD_AUTH_DEVICE      0x00   ///< Authenticated as device (full access)
#define RK_PWD_AUTH_USER        0x01   ///< Authenticated as user (widgets-only)
#define RK_PWD_AUTH_DENIED      0x02   ///< Password did not match

// ─────────────────────────────────────────────
//  Protocol version (v4 — NVS-backed config)
// ─────────────────────────────────────────────
#define RK_PROTOCOL_VERSION 0x05

// ─────────────────────────────────────────────
//  VAR_UPDATE reliability parameters
// ─────────────────────────────────────────────
#define RK_VAR_UPDATE_TIMEOUT_MS 500
#define RK_VAR_UPDATE_MAX_RETRIES 5

// ─────────────────────────────────────────────
//  Buffer sizes
// ─────────────────────────────────────────────
#define RK_MAX_PACKET_SIZE 768
#define RK_RX_BUFFER_SIZE 768

// ─────────────────────────────────────────────
//  CRC-16/CCITT-FALSE
// ─────────────────────────────────────────────
uint16_t rk_crc16(const uint8_t *data, uint16_t len);
const char* rk_cmdName(uint8_t cmd);

// ─────────────────────────────────────────────
//  Packet builder helpers
// ─────────────────────────────────────────────
uint16_t rk_buildPacket(uint8_t *outBuf, uint8_t cmd, const uint8_t *payload,
                        uint16_t payloadLen);

uint16_t rk_buildAck(uint8_t *outBuf, uint8_t seq);

// ─────────────────────────────────────────────
//  Incoming packet parser state machine
// ─────────────────────────────────────────────
bool rk_rxFeedByte(uint8_t byte, uint8_t &outCmd, const uint8_t *&outPayload,
                   uint16_t &outPayloadLen);

void rk_rxReset();

/**
 * Returns true if the widget protocol parser is currently accumulating a
 * frame (i.e., has seen 0x55 but hasn't completed CRC validation yet).
 * Used by the transport's byte feeder to avoid feeding widget frame bytes
 * into the FS (0xAA) parser, which would corrupt the FS frame payload.
 */
bool rk_rxIsActive();

#endif // RADIOKIT_PROTOCOL_H
