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
//  Command IDs (Protocol v3)
// ─────────────────────────────────────────────
#define RK_CMD_GET_CONF 0x01    // App → Arduino: request config
#define RK_CMD_CONF_DATA 0x02   // Arduino → App: config payload
#define RK_CMD_PING 0x03        // App → Arduino: keep-alive ping
#define RK_CMD_PONG 0x04        // Arduino → App: pong
#define RK_CMD_ACK 0x05         // Both: acknowledge SET_INPUT or VAR_UPDATE
#define RK_CMD_GET_VARS 0x06    // App → Arduino: request all variables
#define RK_CMD_VAR_DATA 0x07    // Arduino → App: variable values (full sync)
#define RK_CMD_VAR_UPDATE 0x08  // Both: partial update of few variables
#define RK_CMD_GET_META 0x09    // App → Arduino: request all metadata
#define RK_CMD_META_DATA 0x0A   // Arduino → App: metadata of all widgets
#define RK_CMD_META_UPDATE 0x0B // Both: metadata of partial widgets
#define RK_CMD_SET_INPUT 0x0C   // Arduino → App: force sync input widget
#define RK_CMD_GET_TELEMETRY 0x0D // App → Arduino: request RSSI/Latency
#define RK_CMD_TELEMETRY_DATA 0x0E // Arduino → App: telemetry values
#define RK_CMD_BLE_INFO     0x14   // App → Arduino: request BLE connection params
#define RK_CMD_BLE_INFO_DATA 0x0F  // Arduino → App: BLE connection param values
#define RK_CMD_GET_FEATURES     0x15  // App → Arduino: request feature bitmask
#define RK_CMD_FEATURES_DATA    0x16  // Arduino → App: feature bitmask [bitmask(1)]
#define RK_CMD_GET_CHIP_INFO    0x17  // App → Arduino: request chip info
#define RK_CMD_CHIP_INFO_DATA   0x18  // Arduino → App: chip info payload
#define RK_CMD_SET_CONF         0x19  // App → Arduino: write name/desc/password to NVS
#define RK_CMD_PWD_AUTH         0x1A  // App → Arduino: authenticate with password
#define RK_CMD_FACTORY_RESET    0x1B  // App → Arduino: erase NVS config and reboot

// ── Feature bitmask bits (FEATURES_DATA payload) ────────────────────────────
#define RK_FEATURE_OTA          (1 << 0)  ///< OTA firmware update supported
#define RK_FEATURE_FILESYSTEM   (1 << 1)  ///< LittleFS filesystem supported
#define RK_FEATURE_HAS_PASSWORD (1 << 2)  ///< Device has a non-empty password set

// ── PWD_AUTH response codes ─────────────────────────────────────────────────
#define RK_PWD_AUTH_OK          0x00  ///< Authentication successful
#define RK_PWD_AUTH_MISMATCH    0x01  ///< Password does not match
#define RK_PWD_AUTH_ALREADY     0x02  ///< Already authenticated

// ── SET_CONF field mask bits ────────────────────────────────────────────────
#define RK_SET_CONF_NAME        (1 << 0)  ///< Name field present
#define RK_SET_CONF_DESC        (1 << 1)  ///< Description field present
#define RK_SET_CONF_PWD         (1 << 2)  ///< Password field present
#define RK_SET_CONF_ERROR       (1 << 7)  ///< ACK: error during NVS write

// ─────────────────────────────────────────────
//  Protocol version (v4 — NVS-backed config)
// ─────────────────────────────────────────────
#define RK_PROTOCOL_VERSION 0x04

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

uint16_t rk_buildPong(uint8_t *outBuf);
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
