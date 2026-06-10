/**
 * RadioKitOTA.h
 * OTA (Over-The-Air) firmware update protocol for RadioKit.
 *
 * Uses a dedicated start byte (0xBB) and a parallel state machine, following
 * the same architecture as the FS protocol (0xAA). This avoids depending on
 * external OTA libraries (e.g. NimBLEOta) that cannot share the existing
 * NimBLEServer.
 *
 * Frame format (no CRC — transport is reliable; firmware CRC32 verified at end):
 *   [0xBB][SUB_CMD(1)][LEN_LO(1)][LEN_HI(1)][...PAYLOAD(N)...]
 *   LEN = total frame bytes (header(4) + payload)
 *   MAX payload per frame = RK_OTA_MAX_PAYLOAD (4096, matching chunk size)
 *
 * Sub-commands (App → MCU):
 *   0x01  OTA_BEGIN      [FIRMWARE_SIZE(4 LE)]              → OTA_ACK
 *   0x02  OTA_CHUNK      [OFFSET(4 LE)][...DATA(N)]         → OTA_ACK
 *   0x03  OTA_END        [CRC32(4 LE)]                      → OTA_ACK
 *   0x04  OTA_ABORT      (empty)                             → (no ack)
 *   0x05  OTA_SET_ERASE  [MODE(1)]                           → OTA_ACK
 *
 * Sub-commands (MCU → App):
 *   0x81  OTA_ACK        [ERROR_CODE(1)]
 *   0x82  OTA_PROGRESS   [RECEIVED(4 LE)][TOTAL(4 LE)]
 *
 * Error codes:
 *   0x00  OK
 *   0x01  NO_SPACE       (insufficient OTA partition space)
 *   0x02  CRC_MISMATCH   (firmware CRC doesn't match)
 *   0x03  FLASH_ERROR    (write/erase failure)
 *   0x04  SEQ_ERROR      (offset mismatch — chunks out of order)
 *   0x05  INVALID_STATE  (Begin not called before Chunk/End)
 *   0x06  NOT_SUPPORTED  (OTA not compiled in or not available on this arch)
 */

#ifndef RADIOKIT_OTA_H
#define RADIOKIT_OTA_H

#include <Arduino.h>
#include <stdint.h>

// ── Frame constants ─────────────────────────────────────────────────────────
#define RK_OTA_START_BYTE       0xBB
#define RK_OTA_HEADER_SIZE      4   // START(1) + SUB_CMD(1) + LEN_LO(1) + LEN_HI(1)
#define RK_OTA_MIN_FRAME        RK_OTA_HEADER_SIZE
#define RK_OTA_MAX_PAYLOAD      4096    // 4 KB per chunk
#define RK_OTA_RX_BUFFER_SIZE   (RK_OTA_HEADER_SIZE + RK_OTA_MAX_PAYLOAD)

// ── Sub-commands (App → MCU) ────────────────────────────────────────────────
#define RK_OTA_CMD_BEGIN            0x01
#define RK_OTA_CMD_CHUNK            0x02
#define RK_OTA_CMD_END              0x03
#define RK_OTA_CMD_ABORT            0x04
#define RK_OTA_CMD_SET_ERASE_FLAG   0x05

// ── Sub-commands (MCU → App) ────────────────────────────────────────────────
#define RK_OTA_RESP_ACK             0x81
#define RK_OTA_RESP_PROGRESS        0x82

// ── Error codes ─────────────────────────────────────────────────────────────
#define RK_OTA_ERR_OK               0x00
#define RK_OTA_ERR_NO_SPACE         0x01
#define RK_OTA_ERR_CRC              0x02
#define RK_OTA_ERR_FLASH            0x03
#define RK_OTA_ERR_SEQ              0x04
#define RK_OTA_ERR_INVALID_STATE    0x05
#define RK_OTA_ERR_NOT_SUPPORTED    0x06

// ── Callback signature: invoked when a complete OTA frame has been received ──
typedef void (*RK_OtaPacketCallback)(uint8_t subCmd,
                                     const uint8_t* payload,
                                     uint16_t payloadLen);

// ── Public API ──────────────────────────────────────────────────────────────

/**
 * Reset the OTA state machine. Call on transport disconnect / timeout.
 */
void rk_otaRxReset();

/**
 * Returns true if the OTA parser is currently accumulating a frame.
 */
bool rk_otaRxIsActive();

/**
 * Feed a single byte into the OTA state machine.
 * Returns true when a complete frame is available.
 */
bool rk_otaRxFeedByte(uint8_t byte,
                      uint8_t& outSubCmd,
                      const uint8_t*& outPayload,
                      uint16_t& outPayloadLen);

/**
 * Build a complete OTA frame into [outBuf].
 * Returns the total frame length, or 0 if [payloadLen] exceeds RK_OTA_MAX_PAYLOAD.
 */
uint16_t rk_otaBuildFrame(uint8_t* outBuf,
                          uint8_t subCmd,
                          const uint8_t* payload,
                          uint16_t payloadLen);

/**
 * Callback registration. Set once at startup.
 */
void rk_otaSetCallback(RK_OtaPacketCallback cb);

/**
 * Get the tx scratch buffer.
 */
uint8_t* rk_otaTxBuf();
uint16_t rk_otaTxBufSize();

/**
 * Command/error name helpers (for debug logging).
 */
const char* rk_otaCmdName(uint8_t subCmd);
const char* rk_otaErrorName(uint8_t err);

#endif // RADIOKIT_OTA_H
