/**
 * RadioKitPrint.h
 * Print/Debug stream protocol for RadioKit — dedicated stream for
 * RadioKit.print() output, relayed over all active transports.
 *
 * Uses start byte 0xEE and a parallel state machine, following the same
 * architecture as the Settings protocol (0xDD).
 *
 * Frame format (unidirectional — device to app only):
 *   [0xEE][LEN_LO(1)][LEN_HI(1)][...UTF-8 TEXT(N)...]
 *   LEN = total frame bytes (header(3) + text)
 *   MAX text payload = RK_PRINT_MAX_PAYLOAD (252)
 *
 * Transport dispatch:
 *   - The print stream is sent via _sendToAllTransports(), so it flows over
 *     all active transports (BLE, WiFi, Cloud, Serial) simultaneously.
 *   - BLE uses dedicated characteristic 0xFFE5 for notify (TX only).
 *   - WiFi/Cloud use type-byte 0xEE framing (same pattern as 0x55/0xAA/0xBB/0xDD).
 *   - Serial transport feeds bytes through rk_printRxFeedByte() for dispatch.
 *
 * The app never sends 0xEE frames to the device — this is unidirectional.
 */

#ifndef RADIOKIT_PRINT_H
#define RADIOKIT_PRINT_H

#include <Arduino.h>
#include <stdint.h>

// ── Frame constants ─────────────────────────────────────────────────────────
#define RK_PRINT_START_BYTE      0xEE
#define RK_PRINT_HEADER_SIZE     3   // START(1) + LEN_LO(1) + LEN_HI(1)
#define RK_PRINT_MIN_FRAME       RK_PRINT_HEADER_SIZE
#define RK_PRINT_MAX_PAYLOAD     252  // Fits in 256-byte buffer with 4-byte header
#define RK_PRINT_RX_BUFFER_SIZE  (RK_PRINT_HEADER_SIZE + RK_PRINT_MAX_PAYLOAD)

// ── Public API ──────────────────────────────────────────────────────────────

/**
 * Reset the Print state machine. Call on transport disconnect / timeout.
 */
void rk_printRxReset();

/**
 * Returns true if the Print parser is currently accumulating a frame.
 */
bool rk_printRxIsActive();

/**
 * Feed a single byte into the Print state machine.
 * Returns true when a complete frame is available.
 * outPayload points into an internal buffer — caller must consume
 * before the next call to rk_printRxFeedByte().
 */
bool rk_printRxFeedByte(uint8_t byte,
                        const uint8_t*& outPayload,
                        uint16_t& outPayloadLen);

/**
 * Build a complete Print frame into [outBuf].
 * Returns the total frame length, or 0 if [payloadLen] exceeds RK_PRINT_MAX_PAYLOAD.
 */
uint16_t rk_printBuildFrame(uint8_t* outBuf,
                            const uint8_t* payload,
                            uint16_t payloadLen);

/**
 * Get the tx scratch buffer and its size.
 */
uint8_t* rk_printTxBuf();
uint16_t rk_printTxBufSize();

/**
 * Command name helper (for debug logging).
 */
const char* rk_printCmdName();

#endif // RADIOKIT_PRINT_H
