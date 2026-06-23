/**
 * RadioKitFsHandlers.h
 * FS protocol command handlers — bridges the FS frame parser to LittleFS
 * (or any other user-supplied backend by overriding the weak functions).
 *
 * Handlers are weak-linked so user sketches may override individual
 * commands (e.g. to use SPIFFS, FFat, or a custom filesystem).
 *
 * Conditional compilation: FS support is enabled when LittleFS is available
 * (auto-detected via __has_include on common boards). If not available,
 * handlers return RK_FS_ERR_NO_FS for all commands.
 */

#ifndef RADIOKIT_FS_HANDLERS_H
#define RADIOKIT_FS_HANDLERS_H

#include <Arduino.h>
#include <stdint.h>
#include "RadioKitConfig.h"

// RK_FS_HAS_LITTLEFS: enabled when the user defines RK_ENABLE_FS
// in their build flags (e.g. -DRK_ENABLE_FS in platformio.ini).
// This decouples platform capability from user intent — the user must
// opt in to FS support even on platforms that have LittleFS.
#ifdef RK_ENABLE_FS
  #include <LittleFS.h>
  #define RK_FS_HAS_LITTLEFS 1
#else
  #define RK_FS_HAS_LITTLEFS 0
#endif

namespace RKFs {

/// Initialise the default filesystem. Returns true on success.
bool begin();

/// Returns true if the filesystem is mounted and ready.
bool isReady();

/// Format and remount the filesystem. Returns true on success.
bool format();

/// Get the current working directory (used as the base for relative paths).
const char* cwd();

/// Change the working directory. Returns true on success.
bool chdir(const char* path);

/// Frame handlers — called from the RadioKit dispatch loop.
void handleList     (const uint8_t* payload, uint16_t len);
void handleRead     (const uint8_t* payload, uint16_t len);
void handleWrite    (const uint8_t* payload, uint16_t len);
void handleDelete   (const uint8_t* payload, uint16_t len);
void handleInfo     ();
void handleMkdir    (const uint8_t* payload, uint16_t len);
void handleRename   (const uint8_t* payload, uint16_t len);
void handleUploadBegin (const uint8_t* payload, uint16_t len);
void handleUploadChunk (const uint8_t* payload, uint16_t len);
void handleUploadEnd   (const uint8_t* payload, uint16_t len);
void handleFormat   ();

/// Top-level dispatcher — matches [subCmd] to the appropriate handler.
void dispatch(uint8_t subCmd, const uint8_t* payload, uint16_t payloadLen);

/// Send a complete FS frame to the transport. Used by handlers.
typedef void (*SenderFn)(const uint8_t* data, uint16_t len);
void setSender(SenderFn fn);

} // namespace RKFs

#endif // RADIOKIT_FS_HANDLERS_H
