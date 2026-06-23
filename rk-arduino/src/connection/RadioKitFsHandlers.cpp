/**
 * RadioKitFsHandlers.cpp
 * Default LittleFS-backed implementation of the FS protocol handlers.
 *
 * Compiled only when LittleFS is available; otherwise the dispatch()
 * function returns RK_FS_ERR_NO_FS for every command.
 */

#include "RadioKitFsHandlers.h"
#include "RadioKitFS.h"
#include <string.h>
#include <stdlib.h>

namespace RKFs {

static SenderFn s_sender = nullptr;
static bool     s_mounted = false;
static char     s_cwd[128] = "/";

// ── CRC32 ───────────────────────────────────────────────────────────────────

// Standard CRC-32 (IEEE 802.3) with polynomial 0xEDB88320.
static uint32_t s_crc32Table[256];
static bool     s_crc32Ready = false;

static void _initCrc32() {
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ ((crc & 1) ? 0xEDB88320UL : 0);
        }
        s_crc32Table[i] = crc;
    }
    s_crc32Ready = true;
}

/// Update a running CRC32 with [len] bytes. Call with 0xFFFFFFFF to start.
static uint32_t _crc32Update(uint32_t crc, const uint8_t* data, size_t len) {
    if (!s_crc32Ready) _initCrc32();
    for (size_t i = 0; i < len; i++) {
        crc = s_crc32Table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc;
}

/// Finalize CRC32 (XOR with 0xFFFFFFFF).
static uint32_t _crc32Final(uint32_t crc) { return crc ^ 0xFFFFFFFFUL; }

// ── Upload state (persisted across UPLOAD_BEGIN / CHUNK / END) ──────────────

static struct {
    bool     active;
    char     path[128];
    uint32_t totalSize;
    uint32_t bytesReceived;
    uint32_t runningCrc;  // Running CRC32 (before final XOR)
} s_upload;

// ── Internal helpers ────────────────────────────────────────────────────────

static void sendFrame(uint8_t subCmd, const uint8_t* payload, uint16_t payloadLen) {
    if (!s_sender || payloadLen > RK_FS_MAX_PAYLOAD) return;
    uint16_t frameLen = rk_fsBuildFrame(rk_fsTxBuf(), subCmd, payload, payloadLen);
    if (frameLen > 0) s_sender(rk_fsTxBuf(), frameLen);
}

static void sendError(uint8_t respSubCmd, uint8_t err) {
    uint8_t payload[1] = { err };
    sendFrame(respSubCmd, payload, 1);
}

// Read a length-prefixed UTF-8 string from a payload at [offset].
// Returns the parsed length in [outStrLen], advances [offset].
// If [outStr] is non-null, the string is copied (NUL-terminated, truncated).
static void readString(const uint8_t* payload, uint16_t len, uint16_t& offset,
                       char* outStr, size_t outStrCap, uint16_t& outStrLen) {
    if (offset >= len) {
        if (outStr && outStrCap > 0) outStr[0] = '\0';
        outStrLen = 0;
        return;
    }
    uint16_t strLen = payload[offset++];
    if (offset + strLen > len) strLen = len - offset;
    if (outStr && outStrCap > 0) {
        size_t copyLen = (strLen < outStrCap - 1) ? strLen : outStrCap - 1;
        if (copyLen > 0) memcpy(outStr, &payload[offset], copyLen);
        outStr[copyLen] = '\0';
    }
    outStrLen = strLen;
    offset += strLen;
}

static void writeU16LE(uint8_t* buf, uint16_t v) {
    buf[0] = (uint8_t)(v & 0xFF);
    buf[1] = (uint8_t)((v >> 8) & 0xFF);
}
static void writeU32LE(uint8_t* buf, uint32_t v) {
    buf[0] = (uint8_t)(v & 0xFF);
    buf[1] = (uint8_t)((v >> 8) & 0xFF);
    buf[2] = (uint8_t)((v >> 16) & 0xFF);
    buf[3] = (uint8_t)((v >> 24) & 0xFF);
}
static uint16_t readU16LE(const uint8_t* buf) {
    return (uint16_t)buf[0] | ((uint16_t)buf[1] << 8);
}
static uint32_t readU32LE(const uint8_t* buf) {
    return (uint32_t)buf[0] |
           ((uint32_t)buf[1] << 8) |
           ((uint32_t)buf[2] << 16) |
           ((uint32_t)buf[3] << 24);
}

// Resolve a user-supplied path against the current working directory.
// On Windows-style "C:\foo" the drive letter is preserved; otherwise the
// path is appended to s_cwd. Always produces an absolute-style path.
static void resolvePath(const char* in, char* out, size_t outCap) {
    if (!in || !out || outCap == 0) return;
    if (in[0] == '/' || (in[0] && in[1] == ':')) {
        // Absolute path
        strncpy(out, in, outCap - 1);
        out[outCap - 1] = '\0';
        return;
    }
    size_t cwdLen = strlen(s_cwd);
    bool needSlash = (cwdLen > 1 && s_cwd[cwdLen - 1] != '/');
    snprintf(out, outCap, "%s%s%s", s_cwd, needSlash ? "/" : "", in);
    out[outCap - 1] = '\0';
}

// ── Debug: read-integrity logging ───────────────────────────────────────────
// Set to 1 to log the first 32 bytes and CRC32 of every chunk read from
// LittleFS. The app can then compare these against the expected content to
// determine whether corruption happens inside LittleFS or during BLE tx.
#define RK_FS_DEBUG_READ 0

// ── Public API ──────────────────────────────────────────────────────────────

void setSender(SenderFn fn) { s_sender = fn; }

bool begin() {
#if RK_FS_HAS_LITTLEFS
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    s_mounted = LittleFS.begin(true);  // ESP32: format-on-fail
#else
    s_mounted = LittleFS.begin();      // RP2040: no bool arg
#endif
    return s_mounted;
#else
    s_mounted = false;
    return false;
#endif
}

bool isReady() { return s_mounted; }

bool format() {
#if RK_FS_HAS_LITTLEFS
    s_mounted = false;
    LittleFS.end();
    s_mounted = LittleFS.format() && LittleFS.begin();
    return s_mounted;
#else
    return false;
#endif
}

const char* cwd() { return s_cwd; }

bool chdir(const char* path) {
    if (!path) return false;
    size_t len = strlen(path);
    if (len == 0 || len >= sizeof(s_cwd)) return false;
    memcpy(s_cwd, path, len + 1);
    return true;
}

// ── Handlers ────────────────────────────────────────────────────────────────

void handleList(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_LIST_DATA, RK_FS_ERR_NO_FS); return; }

    char path[128];
    uint16_t offset = 0;
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    File root = LittleFS.open(resolved, "r");
    if (!root || !root.isDirectory()) {
        if (root) root.close();
        sendError(RK_FS_RESP_LIST_DATA, RK_FS_ERR_NOT_FOUND);
        return;
    }

    // Two-phase build: first pass count entries, then write into txBuf.
    // To keep it simple, we send all entries in one frame up to RK_FS_MAX_PAYLOAD.
    uint8_t* tx = rk_fsTxBuf() + RK_FS_HEADER_SIZE;
    uint16_t out = 0;
    uint16_t entryCount = 0;
    writeU16LE(&tx[out], 0); // placeholder for count
    out += 2;

    File entry = root.openNextFile();
    while (entry) {
        const char* name = entry.name();
        uint8_t nameLen = (uint8_t)strlen(name);
        if (nameLen > 127) nameLen = 127;

        // Per entry: TYPE(1) + SIZE(4) + NAME_LEN(1) + NAME
        size_t entryBytes = 1 + 4 + 1 + nameLen;
        if (out + entryBytes > RK_FS_MAX_PAYLOAD) break;

        tx[out++] = entry.isDirectory() ? RK_FS_TYPE_DIR : RK_FS_TYPE_FILE;
        writeU32LE(&tx[out], (uint32_t)entry.size());
        out += 4;
        tx[out++] = nameLen;
        memcpy(&tx[out], name, nameLen);
        out += nameLen;
        entryCount++;

        entry.close();
        entry = root.openNextFile();
    }
    root.close();

    // Patch the count
    writeU16LE(&tx[0], entryCount);

    sendFrame(RK_FS_RESP_LIST_DATA, tx, out);
#else
    sendError(RK_FS_RESP_LIST_DATA, RK_FS_ERR_NO_FS);
#endif
}

void handleRead(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_READ_DATA, RK_FS_ERR_NO_FS); return; }
    if (len < 1 + 1 + 4 + 2) { sendError(RK_FS_RESP_READ_DATA, RK_FS_ERR_INVALID_PATH); return; }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    if (offset + 4 + 2 > len) { sendError(RK_FS_RESP_READ_DATA, RK_FS_ERR_INVALID_PATH); return; }
    uint32_t fileOffset = readU32LE(&payload[offset]); offset += 4;
    uint16_t maxSize    = readU16LE(&payload[offset]); offset += 2;

    if (maxSize > RK_FS_MAX_PAYLOAD - 8) maxSize = RK_FS_MAX_PAYLOAD - 8;

    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    File f = LittleFS.open(resolved, "r");
    if (!f) { sendError(RK_FS_RESP_READ_DATA, RK_FS_ERR_NOT_FOUND); return; }

    uint32_t totalSize = (uint32_t)f.size();
    if (!f.seek(fileOffset)) {
        f.close();
        sendError(RK_FS_RESP_READ_DATA, RK_FS_ERR_INVALID_PATH);
        return;
    }

    uint8_t* tx = rk_fsTxBuf() + RK_FS_HEADER_SIZE;
    writeU32LE(&tx[0], totalSize);
    writeU32LE(&tx[4], fileOffset);
    uint16_t toRead = maxSize;
    if (fileOffset + toRead > totalSize) toRead = (uint16_t)(totalSize - fileOffset);

    uint16_t actualRead = (uint16_t)f.read(&tx[8], toRead);
    f.close();

#if RK_FS_DEBUG_READ
    // Log chunk integrity data so the app can compare against expected content.
    // Format: [offset] [size] [crc32] [hex_first_32_bytes]
    uint32_t chunkCrc = _crc32Final(_crc32Update(0xFFFFFFFFUL, &tx[8], actualRead));    char hexBuf[65];
    uint16_t hexLen = (actualRead < 32) ? actualRead : 32;
    for (uint16_t i = 0; i < hexLen; i++) {
        sprintf(hexBuf + i * 2, "%02X", tx[8 + i]);
    }
    hexBuf[hexLen * 2] = '\0';
    Serial.printf("FS_READ: offset=%u size=%u crc=0x%08X data=%s\n",
                  (unsigned)fileOffset, (unsigned)actualRead, (unsigned)chunkCrc, hexBuf);
#endif

    sendFrame(RK_FS_RESP_READ_DATA, tx, 8 + actualRead);
#else
    sendError(RK_FS_RESP_READ_DATA, RK_FS_ERR_NO_FS);
#endif
}

void handleWrite(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_NO_FS); return; }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    if (offset + 4 > len) { sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_INVALID_PATH); return; }
    uint32_t fileOffset = readU32LE(&payload[offset]); offset += 4;

    const char* mode = (fileOffset == 0) ? "w" : "r+";
    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    File f;
    if (fileOffset == 0) {
        f = LittleFS.open(resolved, "w");
    } else {
        f = LittleFS.open(resolved, "r+");
        if (f && !f.seek(fileOffset)) {
            f.close();
            sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_INVALID_PATH);
            return;
        }
    }
    if (!f) { 
        sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_IO); 
        return; 
    }

    uint16_t toWrite = len - offset;
    uint16_t written = (uint16_t)f.write(&payload[offset], toWrite);
    f.close();
    if (written != toWrite) { 
        sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_IO); 
        return; 
    }
    sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_OK);
#else
    sendError(RK_FS_RESP_WRITE_ACK, RK_FS_ERR_NO_FS);
#endif
}

void handleDelete(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_DELETE_ACK, RK_FS_ERR_NO_FS); return; }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);
    if (offset < len) offset++; // skip RECURSIVE flag (1 byte)

    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    // Try as file first; if that fails, try directory.
    bool ok = LittleFS.remove(resolved);
    if (!ok) ok = LittleFS.rmdir(resolved);

    sendError(RK_FS_RESP_DELETE_ACK, ok ? RK_FS_ERR_OK : RK_FS_ERR_NOT_FOUND);
#else
    sendError(RK_FS_RESP_DELETE_ACK, RK_FS_ERR_NO_FS);
#endif
}

void handleInfo() {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_INFO_DATA, RK_FS_ERR_NO_FS); return; }

#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    uint32_t total = (uint32_t)LittleFS.totalBytes();
    uint32_t used  = (uint32_t)LittleFS.usedBytes();
#else
    // RP2040/STM32 LittleFS: no totalBytes/usedBytes API
    uint32_t total = 0;
    uint32_t used  = 0;
#endif
    uint16_t blockSize = 4096; // Typical LittleFS block size; no direct getter

    uint8_t payload[4 + 4 + 2 + 1];
    writeU32LE(&payload[0], total);
    writeU32LE(&payload[4], used);
    writeU16LE(&payload[8], blockSize);
    payload[10] = 0x01; // FS_TYPE: 0x01 = LittleFS
    sendFrame(RK_FS_RESP_INFO_DATA, payload, sizeof(payload));
#else
    sendError(RK_FS_RESP_INFO_DATA, RK_FS_ERR_NO_FS);
#endif
}

void handleMkdir(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_MKDIR_ACK, RK_FS_ERR_NO_FS); return; }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    bool ok = LittleFS.mkdir(resolved);
    sendError(RK_FS_RESP_MKDIR_ACK, ok ? RK_FS_ERR_OK : RK_FS_ERR_IO);
#else
    sendError(RK_FS_RESP_MKDIR_ACK, RK_FS_ERR_NO_FS);
#endif
}

void handleRename(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_RENAME_ACK, RK_FS_ERR_NO_FS); return; }

    uint16_t offset = 0;
    char oldPath[128], newPath[128];
    uint16_t oldLen = 0, newLen = 0;
    readString(payload, len, offset, oldPath, sizeof(oldPath), oldLen);
    readString(payload, len, offset, newPath, sizeof(newPath), newLen);

    char resolvedOld[160], resolvedNew[160];
    resolvePath(oldPath, resolvedOld, sizeof(resolvedOld));
    resolvePath(newPath, resolvedNew, sizeof(resolvedNew));

    bool ok = LittleFS.rename(resolvedOld, resolvedNew);
    sendError(RK_FS_RESP_RENAME_ACK, ok ? RK_FS_ERR_OK : RK_FS_ERR_NOT_FOUND);
#else
    sendError(RK_FS_RESP_RENAME_ACK, RK_FS_ERR_NO_FS);
#endif
}

void handleUploadBegin(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_UPLOAD_BEGIN_ACK, RK_FS_ERR_NO_FS); return; }

    // Close any stale upload (shouldn't happen, but be safe)
    if (s_upload.active) {
        s_upload.active = false;
    }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    if (offset + 4 > len) { sendError(RK_FS_RESP_UPLOAD_BEGIN_ACK, RK_FS_ERR_INVALID_PATH); return; }
    uint32_t totalSize = readU32LE(&payload[offset]); offset += 4;

    if (totalSize > RK_FS_MAX_PAYLOAD * 256) { // sanity: max ~4 MB
        sendError(RK_FS_RESP_UPLOAD_BEGIN_ACK, RK_FS_ERR_INVALID_PATH);
        return;
    }

    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    File f = LittleFS.open(resolved, "w");
    if (!f) { sendError(RK_FS_RESP_UPLOAD_BEGIN_ACK, RK_FS_ERR_IO); return; }
    f.close();

    // Store upload state
    strncpy(s_upload.path, resolved, sizeof(s_upload.path) - 1);
    s_upload.path[sizeof(s_upload.path) - 1] = '\0';
    s_upload.totalSize = totalSize;
    s_upload.bytesReceived = 0;
    s_upload.runningCrc = 0xFFFFFFFFUL;
    s_upload.active = true;

    sendError(RK_FS_RESP_UPLOAD_BEGIN_ACK, RK_FS_ERR_OK);
#else
    sendError(RK_FS_RESP_UPLOAD_BEGIN_ACK, RK_FS_ERR_NO_FS);
#endif
}

void handleUploadChunk(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted || !s_upload.active) {
        sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_INVALID_STATE);
        return;
    }

    if (len < 4) { sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_INVALID_PATH); return; }

    uint32_t chunkOffset = readU32LE(&payload[0]);
    uint16_t dataLen = len - 4;

    if (chunkOffset != s_upload.bytesReceived) {
        sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_INVALID_STATE);
        return;
    }

    // Open and append
    File f = LittleFS.open(s_upload.path, "a");
    if (!f) {
        s_upload.active = false;
        sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_IO);
        return;
    }

    uint16_t written = (uint16_t)f.write(&payload[4], dataLen);
    f.close();

    if (written != dataLen) {
        s_upload.active = false;
        LittleFS.remove(s_upload.path);
        sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_IO);
        return;
    }

    // Update running CRC32
    s_upload.runningCrc = _crc32Update(s_upload.runningCrc, &payload[4], dataLen);
    s_upload.bytesReceived += dataLen;

    sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_OK);
#else
    sendError(RK_FS_RESP_UPLOAD_CHUNK_ACK, RK_FS_ERR_NO_FS);
#endif
}

void handleUploadEnd(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted || !s_upload.active) {
        sendError(RK_FS_RESP_UPLOAD_END_ACK, RK_FS_ERR_INVALID_STATE);
        return;
    }

    uint32_t expectedCrc = (len >= 4) ? readU32LE(&payload[0]) : 0;

    // Finalize the running CRC
    uint32_t actualCrc = _crc32Final(s_upload.runningCrc);

    bool ok = (expectedCrc == actualCrc && s_upload.bytesReceived == s_upload.totalSize);

    if (!ok) {
        // CRC mismatch or size mismatch — delete corrupt file
        LittleFS.remove(s_upload.path);
    }

    s_upload.active = false;

    sendError(RK_FS_RESP_UPLOAD_END_ACK, ok ? RK_FS_ERR_OK : RK_FS_ERR_IO);
#else
    sendError(RK_FS_RESP_UPLOAD_END_ACK, RK_FS_ERR_NO_FS);
#endif
}

/// FS_FORMAT: re-formats the default filesystem. Destructive.
void handleFormat() {
    if (s_upload.active) s_upload.active = false;
    bool ok = format();
    sendError(RK_FS_RESP_FORMAT_ACK, ok ? RK_FS_ERR_OK : RK_FS_ERR_IO);
}

// ── REPLACE handler ─────────────────────────────────────────────────────────

/// FS_REPLACE: single-frame file replace with CRC32 verification.
/// Payload: [PATH_LEN(1)][PATH(N)][CRC32(4 LE)][CONTENT(M)].
void handleReplace(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) { sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_NO_FS); return; }
    if (len < 6) { sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_INVALID_PATH); return; }

    // Abort any active upload first
    if (s_upload.active) {
        // Clean up the partial upload file
        if (s_upload.path[0] != '\0') {
            LittleFS.remove(s_upload.path);
        }
        s_upload.active = false;
    }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    if (offset + 4 > len) { sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_INVALID_PATH); return; }
    uint32_t expectedCrc = readU32LE(&payload[offset]);
    offset += 4;

    uint16_t contentLen = len - offset;
    const uint8_t* content = &payload[offset];

    // Compute CRC32 of content
    uint32_t actualCrc = _crc32Final(_crc32Update(0xFFFFFFFFUL, content, contentLen));

    // Verify CRC32 before writing
    if (expectedCrc != actualCrc) {
        sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_IO);
        return;
    }

    // Write the file (truncate)
    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    File f = LittleFS.open(resolved, "w");
    if (!f) { sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_IO); return; }

    uint16_t written = (uint16_t)f.write(content, contentLen);
    f.close();

    if (written != contentLen) {
        LittleFS.remove(resolved);
        sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_IO);
        return;
    }

    sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_OK);
#else
    sendError(RK_FS_RESP_REPLACE_ACK, RK_FS_ERR_NO_FS);
#endif
}

// ── CRC32 handler ───────────────────────────────────────────────────────────

/// FS_CRC32: compute CRC32 checksum of a file.
/// Payload: [PATH_LEN(1)][PATH(N)].
/// Response: [STATUS(1)][CRC32(4 LE)][FILE_SIZE(4 LE)]
///   STATUS=0x00: file found, CRC32+size valid
///   STATUS=0x01: file not found or too large (>512 KB)
void handleCrc32(const uint8_t* payload, uint16_t len) {
#if RK_FS_HAS_LITTLEFS
    if (!s_mounted) {
        uint8_t resp[9] = { 0x01, 0, 0, 0, 0, 0, 0, 0, 0 }; // not found
        sendFrame(RK_FS_RESP_CRC32_DATA, resp, 9);
        return;
    }

    uint16_t offset = 0;
    char path[128];
    uint16_t pathLen = 0;
    readString(payload, len, offset, path, sizeof(path), pathLen);

    char resolved[160];
    resolvePath(path, resolved, sizeof(resolved));

    File f = LittleFS.open(resolved, "r");
    if (!f) {
        uint8_t resp[9] = { 0x01, 0, 0, 0, 0, 0, 0, 0, 0 }; // not found
        sendFrame(RK_FS_RESP_CRC32_DATA, resp, 9);
        return;
    }

    uint32_t fileSize = (uint32_t)f.size();

    // Performance guard: skip CRC for files > 512 KB
    if (fileSize > 512 * 1024) {
        f.close();
        uint8_t resp[9] = { 0x01, 0, 0, 0, 0, 0, 0, 0, 0 }; // not found signal
        sendFrame(RK_FS_RESP_CRC32_DATA, resp, 9);
        return;
    }

    // Compute CRC32 over the entire file
    uint32_t runningCrc = 0xFFFFFFFFUL;
    uint8_t buf[256];
    int bytesRead;
    while ((bytesRead = f.read(buf, sizeof(buf))) > 0) {
        runningCrc = _crc32Update(runningCrc, buf, (size_t)bytesRead);
    }
    f.close();

    uint32_t fileCrc = _crc32Final(runningCrc);

    // Build response: STATUS(1) + CRC32(4) + SIZE(4) = 9 bytes
    uint8_t resp[9];
    resp[0] = 0x00; // STATUS: found
    writeU32LE(&resp[1], fileCrc);
    writeU32LE(&resp[5], fileSize);
    sendFrame(RK_FS_RESP_CRC32_DATA, resp, 9);
#else
    uint8_t resp[9] = { 0x01, 0, 0, 0, 0, 0, 0, 0, 0 };
    sendFrame(RK_FS_RESP_CRC32_DATA, resp, 9);
#endif
}

void dispatch(uint8_t subCmd, const uint8_t* payload, uint16_t payloadLen) {
    switch (subCmd) {
        case RK_FS_CMD_LIST:          handleList(payload, payloadLen);          break;
        case RK_FS_CMD_READ:          handleRead(payload, payloadLen);          break;
        case RK_FS_CMD_WRITE:         handleWrite(payload, payloadLen);         break;
        case RK_FS_CMD_DELETE:        handleDelete(payload, payloadLen);        break;
        case RK_FS_CMD_INFO:          handleInfo();                              break;
        case RK_FS_CMD_MKDIR:         handleMkdir(payload, payloadLen);         break;
        case RK_FS_CMD_RENAME:        handleRename(payload, payloadLen);        break;
        case RK_FS_CMD_UPLOAD_BEGIN:  handleUploadBegin(payload, payloadLen);   break;
        case RK_FS_CMD_UPLOAD_CHUNK:  handleUploadChunk(payload, payloadLen);   break;
        case RK_FS_CMD_UPLOAD_END:    handleUploadEnd(payload, payloadLen);     break;
        case RK_FS_CMD_FORMAT:        handleFormat();                            break;
        case RK_FS_CMD_REPLACE:       handleReplace(payload, payloadLen);       break;
        case RK_FS_CMD_CRC32:         handleCrc32(payload, payloadLen);         break;
        default:
            // Unknown sub-command — reply with NO_FS to keep the app unblocked.
            sendError((uint8_t)(subCmd | 0x80), RK_FS_ERR_NO_FS);
            break;
    }
}

} // namespace RKFs
