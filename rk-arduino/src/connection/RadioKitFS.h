/**
 * RadioKitFS.h
 * Bulk filesystem protocol (separate from the widget protocol).
 *
 * Frame format (no CRC — transport is reliable for short bursts):
 *   [0xAA][SUB_CMD(1)][LEN_LO(1)][LEN_HI(1)][...PAYLOAD(N)...]
 *   LEN = total frame bytes (header(4) + payload)
 *   MAX payload per frame = RK_FS_MAX_PAYLOAD (16 KB)
 *
 * Sub-commands (APP → MCU):
 *   0x01  FS_LIST       [PATH]                              → FS_LIST_DATA
 *   0x02  FS_READ       [PATH, OFFSET(4 LE), MAX_SIZE(2 LE)] → FS_READ_DATA
 *   0x03  FS_WRITE      [PATH, OFFSET(4 LE), ...DATA]        → FS_WRITE_ACK
 *   0x04  FS_DELETE     [PATH, RECURSIVE(1)]                 → FS_DELETE_ACK
 *   0x05  FS_INFO       (empty)                              → FS_INFO_DATA
 *   0x06  FS_MKDIR      [PATH]                               → FS_MKDIR_ACK
 *   0x07  FS_RENAME     [OLD_PATH, NEW_PATH]                 → FS_RENAME_ACK
 *   0x08  FS_UPLOAD_BEGIN [PATH, TOTAL_SIZE(4 LE)]           → FS_UPLOAD_BEGIN_ACK
 *   0x09  FS_UPLOAD_CHUNK  [OFFSET(4 LE), ...DATA]           → FS_UPLOAD_CHUNK_ACK
 *   0x0A  FS_UPLOAD_END [CRC32(4 LE)]                        → FS_UPLOAD_END_ACK
 *   0x0B  FS_PING       (empty)                              → FS_PING_ACK [STATUS(1)]
 *   0x0C  FS_FORMAT     (empty)                              → FS_FORMAT_ACK
 *
 * Sub-commands (MCU → APP):
 *   0x81  FS_LIST_DATA   [ENTRY_COUNT(2 LE), per entry: [TYPE(1)][SIZE(4 LE)][NAME_LEN(1)][NAME]]
 *   0x82  FS_READ_DATA   [TOTAL_SIZE(4 LE)][OFFSET(4 LE)][...DATA]
 *   0x83  FS_WRITE_ACK   [ERROR_CODE(1)]
 *   0x84  FS_DELETE_ACK  [ERROR_CODE(1)]
 *   0x85  FS_INFO_DATA   [TOTAL(4 LE)][USED(4 LE)][BLOCK_SIZE(2 LE)][FS_TYPE(1)]
 *   0x86  FS_MKDIR_ACK   [ERROR_CODE(1)]
 *   0x87  FS_RENAME_ACK  [ERROR_CODE(1)]
 *   0x88  FS_UPLOAD_BEGIN_ACK [ERROR_CODE(1)]
 *   0x89  FS_UPLOAD_CHUNK_ACK [ERROR_CODE(1)]
 *   0x8A  FS_UPLOAD_END_ACK   [ERROR_CODE(1)]
 *   0x8B  FS_PING_ACK    [STATUS(1)]   0x00 = mounted, 0x03 = NO_FS
 *   0x8C  FS_FORMAT_ACK  [ERROR_CODE(1)]
 *
 * Error codes:
 *   0x00  OK
 *   0x01  NOT_FOUND
 *   0x02  IO_ERROR
 *   0x03  NO_FS          (LittleFS not mounted / not enabled)
 *   0x04  ACCESS_DENIED
 *   0x05  INVALID_PATH
 *   0x06  OUT_OF_SPACE
 *   0x07  INVALID_STATE
 */

#ifndef RADIOKIT_FS_H
#define RADIOKIT_FS_H

#include <Arduino.h>
#include <stdint.h>
#include "../RadioKitConfig.h"

// ── Frame constants ─────────────────────────────────────────────────────────
#define RK_FS_START_BYTE       0xAA
#define RK_FS_HEADER_SIZE      4   // START(1) + SUB_CMD(1) + LEN_LO(1) + LEN_HI(1)
#define RK_FS_MIN_FRAME        RK_FS_HEADER_SIZE
#define RK_FS_MAX_PAYLOAD      16384   // 16 KB per payload — fits in 16 KB rx buffer
#define RK_FS_RX_BUFFER_SIZE   16384   // Generous rx buffer for bulk transfers

// ── Sub-commands (App → MCU) ────────────────────────────────────────────────
#define RK_FS_CMD_LIST             0x01
#define RK_FS_CMD_READ             0x02
#define RK_FS_CMD_WRITE            0x03
#define RK_FS_CMD_DELETE           0x04
#define RK_FS_CMD_INFO             0x05
#define RK_FS_CMD_MKDIR            0x06
#define RK_FS_CMD_RENAME           0x07
#define RK_FS_CMD_UPLOAD_BEGIN     0x08
#define RK_FS_CMD_UPLOAD_CHUNK     0x09
#define RK_FS_CMD_UPLOAD_END       0x0A
#define RK_FS_CMD_FORMAT           0x0C
#define RK_FS_CMD_REPLACE          0x0D
#define RK_FS_CMD_CRC32            0x0E

// ── Sub-commands (MCU → App) ────────────────────────────────────────────────
#define RK_FS_RESP_LIST_DATA       0x81
#define RK_FS_RESP_READ_DATA       0x82
#define RK_FS_RESP_WRITE_ACK       0x83
#define RK_FS_RESP_DELETE_ACK      0x84
#define RK_FS_RESP_INFO_DATA       0x85
#define RK_FS_RESP_MKDIR_ACK       0x86
#define RK_FS_RESP_RENAME_ACK      0x87
#define RK_FS_RESP_UPLOAD_BEGIN_ACK 0x88
#define RK_FS_RESP_UPLOAD_CHUNK_ACK 0x89
#define RK_FS_RESP_UPLOAD_END_ACK   0x8A
#define RK_FS_RESP_FORMAT_ACK      0x8C
#define RK_FS_RESP_REPLACE_ACK     0x8D
#define RK_FS_RESP_CRC32_DATA      0x8E

// ── Error codes ─────────────────────────────────────────────────────────────
#define RK_FS_ERR_OK               0x00
#define RK_FS_ERR_NOT_FOUND        0x01
#define RK_FS_ERR_IO               0x02
#define RK_FS_ERR_NO_FS            0x03
#define RK_FS_ERR_ACCESS_DENIED    0x04
#define RK_FS_ERR_INVALID_PATH     0x05
#define RK_FS_ERR_OUT_OF_SPACE     0x06
#define RK_FS_ERR_INVALID_STATE    0x07

// ── File type flags (in LIST_DATA entries) ─────────────────────────────────
#define RK_FS_TYPE_FILE 0x00
#define RK_FS_TYPE_DIR  0x01

// ── Callback signature: invoked when a complete FS frame has been received ──
typedef void (*RK_FsPacketCallback)(uint8_t subCmd,
                                    const uint8_t* payload,
                                    uint16_t payloadLen);

// ── Public API ──────────────────────────────────────────────────────────────

/**
 * Reset the FS state machine. Call on transport disconnect / timeout.
 */
void rk_fsRxReset();

/**
 * Returns true if the FS parser is currently accumulating a frame
 * (i.e., has received a start byte but not yet completed the frame).
 */
bool rk_fsRxIsActive();

/**
 * Feed a single byte into the FS state machine.
 * Returns true when a complete frame is available. Caller must consume
 * outSubCmd / outPayload / outPayloadLen on the same call before the next
 * call to rk_fsRxFeedByte().
 */
bool rk_fsRxFeedByte(uint8_t byte,
                     uint8_t& outSubCmd,
                     const uint8_t*& outPayload,
                     uint16_t& outPayloadLen);

/**
 * Build a complete FS frame into [outBuf].
 * Returns the total frame length, or 0 if [payloadLen] exceeds RK_FS_MAX_PAYLOAD.
 */
uint16_t rk_fsBuildFrame(uint8_t* outBuf,
                         uint8_t subCmd,
                         const uint8_t* payload,
                         uint16_t payloadLen);

/**
 * Callback registration. Set once at startup.
 */
void rk_fsSetCallback(RK_FsPacketCallback cb);

/**
 * Get the rx scratch buffer (for handlers that need to stage outgoing data).
 */
uint8_t* rk_fsTxBuf();
uint16_t rk_fsTxBufSize();

const char* rk_fsCmdName(uint8_t subCmd);
const char* rk_fsErrorName(uint8_t err);

#endif // RADIOKIT_FS_H
