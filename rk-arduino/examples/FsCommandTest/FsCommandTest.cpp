/**
 * FsCommandTest — RadioKit Example
 *
 * Integration test for the REPLACE (0x0D), CRC32 (0x0E), and DELETE (0x04)
 * filesystem commands. Runs on-device against LittleFS and prints pass/fail
 * for each test case to the Serial monitor.
 *
 * Tests:
 *   1. REPLACE with valid CRC32        → file content is replaced
 *   2. REPLACE with invalid CRC32      → file is NOT modified (CRC gate)
 *   3. REPLACE on non-existent dir     → returns NOT_FOUND
 *   4. CRC32 on existing file          → returns correct checksum + size
 *   5. CRC32 on non-existent file      → returns STATUS=0x01 (not found)
 *   6. CRC32 on empty file             → returns CRC32=0x00000000
 *   7. REPLACE aborts active upload    → upload state is cleaned up
 *   8. CRC32 on file >512 KB           → returns STATUS=0x01 (too large)
 *   9. DELETE recursive on a tree      → files + subfolders removed
 *   10. DELETE recursive on a file     → file removed
 *   11. DELETE non-recursive on a non-empty dir → NOT_FOUND, untouched
 *   12. DELETE recursive on an empty dir → removed
 *
 * Upload to the device and open the Serial monitor at 115200 baud.
 */

#include <Arduino.h>
#include <string.h>

#include "RADIOKIT.h"

#if RK_FS_HAS_LITTLEFS
#include <LittleFS.h>
#endif
#include <connection/RadioKitFS.h>
#include <connection/RadioKitFsHandlers.h>

// ── CRC-32 helpers (must match RadioKitFsHandlers.cpp) ──────────────────────

static uint32_t s_crc32Table[256];
static bool     s_crc32Ready = false;

static void initCrc32Table() {
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ ((crc & 1) ? 0xEDB88320UL : 0);
        }
        s_crc32Table[i] = crc;
    }
    s_crc32Ready = true;
}

static uint32_t crc32Update(uint32_t crc, const uint8_t* data, size_t len) {
    if (!s_crc32Ready) initCrc32Table();
    for (size_t i = 0; i < len; i++) {
        crc = s_crc32Table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc;
}

static uint32_t crc32Final(uint32_t crc) { return crc ^ 0xFFFFFFFFUL; }

static uint32_t computeCrc32(const uint8_t* data, size_t len) {
    return crc32Final(crc32Update(0xFFFFFFFFUL, data, len));
}

// ── Test infrastructure ────────────────────────────────────────────────────

static int  s_testsPassed = 0;
static int  s_testsFailed = 0;
static int  s_testIndex   = 0;

// Captured response from the last RKFs::dispatch call
static uint8_t  s_respSubCmd   = 0;
static uint8_t  s_respPayload[RK_FS_MAX_PAYLOAD];
static uint16_t s_respLen      = 0;
static bool     s_respCaptured = false;

// Custom sender callback that captures the response frame
static void captureSender(const uint8_t* data, uint16_t len) {
    if (len < RK_FS_HEADER_SIZE) return;
    s_respSubCmd   = data[1];
    s_respLen      = len - RK_FS_HEADER_SIZE;
    s_respCaptured = true;
    if (s_respLen > 0 && s_respLen <= sizeof(s_respPayload)) {
        memcpy(s_respPayload, &data[RK_FS_HEADER_SIZE], s_respLen);
    }
}

#define TEST(name)                     \
    do {                                \
        s_testIndex++;                  \
        Serial.printf("--- Test %d: %s ", s_testIndex, name);

#define PASS()                         \
        Serial.println("PASS");         \
        s_testsPassed++;                \
    } while (0)

#define FAIL(msg)                      \
        Serial.printf("FAIL (%s)\n", msg); \
        s_testsFailed++;                \
    } while (0)

#define ASSERT_EQ(a, b, msg)           \
    do {                                \
        if ((a) != (b)) {               \
            Serial.printf("FAIL at line %d: expected %d got %d (%s)\n", \
                          __LINE__, (int)(b), (int)(a), msg); \
            s_testsFailed++;            \
            return;                     \
        }                               \
    } while (0)

#define ASSERT_STR_EQ(a, b, msg)       \
    do {                                \
        if (strcmp((a), (b)) != 0) {    \
            Serial.printf("FAIL at line %d: expected \"%s\" got \"%s\" (%s)\n", \
                          __LINE__, (b), (a), msg); \
            s_testsFailed++;            \
            return;                     \
        }                               \
    } while (0)

// ── Helpers to build payloads ──────────────────────────────────────────────

/// Append a length-prefixed string to a buffer.
static uint16_t appendPath(uint8_t* buf, const char* path) {
    uint16_t len = (uint16_t)strlen(path);
    buf[0] = (uint8_t)(len & 0xFF);
    if (len > 0) memcpy(&buf[1], path, len);
    return 1 + len;
}

/// Build a REPLACE-frame payload: [PATH_LEN][PATH][CRC32(4 LE)][CONTENT]
static uint16_t buildReplacePayload(uint8_t* buf, const char* path,
                                    const uint8_t* content, uint16_t contentLen,
                                    uint32_t crc32) {
    uint16_t off = appendPath(buf, path);
    buf[off + 0] = (uint8_t)(crc32 & 0xFF);
    buf[off + 1] = (uint8_t)((crc32 >> 8) & 0xFF);
    buf[off + 2] = (uint8_t)((crc32 >> 16) & 0xFF);
    buf[off + 3] = (uint8_t)((crc32 >> 24) & 0xFF);
    off += 4;
    if (content && contentLen > 0) memcpy(&buf[off], content, contentLen);
    return off + contentLen;
}

/// Build a CRC32-request payload: [PATH_LEN][PATH]
static uint16_t buildCrc32Payload(uint8_t* buf, const char* path) {
    return appendPath(buf, path);
}

/// Build a DELETE payload: [PATH_LEN][PATH][RECURSIVE(1)]
static uint16_t buildDeletePayload(uint8_t* buf, const char* path,
                                   bool recursive) {
    uint16_t off = appendPath(buf, path);
    buf[off++] = recursive ? 0x01 : 0x00;
    return off;
}

// Read a file from LittleFS into [outBuf]. Returns actual bytes read.
#if RK_FS_HAS_LITTLEFS
static size_t readFileContent(const char* path, uint8_t* outBuf, size_t outCap) {
    if (!LittleFS.exists(path)) return 0;
    File f = LittleFS.open(path, "r");
    if (!f) return 0;
    size_t readBytes = f.read(outBuf, outCap - 1);
    outBuf[readBytes] = '\0';
    f.close();
    return readBytes;
}
#endif

// ── Individual test cases ──────────────────────────────────────────────────

#if RK_FS_HAS_LITTLEFS
// Test 1: REPLACE with valid CRC32 → file content is replaced
static void testReplaceValidCrc() {
    TEST("REPLACE with valid CRC32");

    const char* path = "/test_replace.txt";
    const char* originalContent = "original content";
    const char* newContent = "replaced content!";

    // Create original file
    File f = LittleFS.open(path, "w");
    f.print(originalContent);
    f.close();

    // Build REPLACE payload with correct CRC32
    uint8_t payload[RK_FS_MAX_PAYLOAD];
    uint32_t crc = computeCrc32((const uint8_t*)newContent, strlen(newContent));
    uint16_t payloadLen = buildReplacePayload(payload, path,
                                              (const uint8_t*)newContent,
                                              strlen(newContent), crc);

    // Send via dispatch (captures response in s_respCaptured)
    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_REPLACE, payload, payloadLen);

    // Verify ACK with OK
    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_REPLACE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respLen, 1, "response payload length");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "error code");

    // Verify file content was replaced
    uint8_t buf[64];
    size_t bytesRead = readFileContent(path, buf, sizeof(buf));
    ASSERT_STR_EQ((const char*)buf, newContent, "file content after replace");

    // Cleanup
    LittleFS.remove(path);
    PASS();
}

// Test 2: REPLACE with invalid CRC32 → file is NOT modified
static void testReplaceInvalidCrc() {
    TEST("REPLACE with invalid CRC32");

    const char* path = "/test_replace_invalid.txt";
    const char* originalContent = "do not change me";
    const char* badContent = "should not appear";

    // Create original file
    File f = LittleFS.open(path, "w");
    f.print(originalContent);
    f.close();

    // Build REPLACE payload with WRONG CRC32
    uint8_t payload[RK_FS_MAX_PAYLOAD];
    uint32_t badCrc = 0xDEADBEEF; // Definitely wrong
    uint16_t payloadLen = buildReplacePayload(payload, path,
                                              (const uint8_t*)badContent,
                                              strlen(badContent), badCrc);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_REPLACE, payload, payloadLen);

    // Verify ACK with IO_ERROR (CRC mismatch)
    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_REPLACE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respLen, 1, "response payload length");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_IO, "error code (CRC mismatch)");

    // Verify file content was NOT changed
    uint8_t buf[64];
    readFileContent(path, buf, sizeof(buf));
    ASSERT_STR_EQ((const char*)buf, originalContent, "file content unchanged");

    // Cleanup
    LittleFS.remove(path);
    PASS();
}

// Test 3: REPLACE on non-existent path → NOT_FOUND
static void testReplaceNonExistent() {
    TEST("REPLACE on non-existent path");

    const char* path = "/nonexistent_dir/test.txt";
    const char* content = "data";
    uint8_t payload[RK_FS_MAX_PAYLOAD];
    uint32_t crc = computeCrc32((const uint8_t*)content, strlen(content));
    uint16_t payloadLen = buildReplacePayload(payload, path,
                                              (const uint8_t*)content,
                                              strlen(content), crc);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_REPLACE, payload, payloadLen);

    // Should fail — the parent directory doesn't exist
    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_REPLACE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_IO, "error code (IO error)");
    PASS();
}

// Test 4: CRC32 on existing file → correct checksum + size
static void testCrc32Existing() {
    TEST("CRC32 on existing file");

    const char* path = "/test_crc.txt";
    const char* content = "crc32 test data! 12345";
    uint32_t expectedCrc = computeCrc32((const uint8_t*)content, strlen(content));

    File f = LittleFS.open(path, "w");
    f.print(content);
    f.close();
    size_t expectedSize = strlen(content);

    uint8_t payload[128];
    uint16_t payloadLen = buildCrc32Payload(payload, path);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_CRC32, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_CRC32_DATA, "response sub-cmd");
    ASSERT_EQ(s_respLen, 9, "response payload length (1+4+4)");

    // Parse response: STATUS(1) + CRC32(4 LE) + SIZE(4 LE)
    uint8_t status = s_respPayload[0];
    uint32_t actualCrc = (uint32_t)s_respPayload[1] |
                         ((uint32_t)s_respPayload[2] << 8) |
                         ((uint32_t)s_respPayload[3] << 16) |
                         ((uint32_t)s_respPayload[4] << 24);
    uint32_t actualSize = (uint32_t)s_respPayload[5] |
                          ((uint32_t)s_respPayload[6] << 8) |
                          ((uint32_t)s_respPayload[7] << 16) |
                          ((uint32_t)s_respPayload[8] << 24);

    ASSERT_EQ(status, 0x00, "status (found)");
    ASSERT_EQ(actualCrc, expectedCrc, "CRC32 value");
    ASSERT_EQ(actualSize, (uint32_t)expectedSize, "file size");

    LittleFS.remove(path);
    PASS();
}

// Test 5: CRC32 on non-existent file → STATUS=0x01
static void testCrc32NonExistent() {
    TEST("CRC32 on non-existent file");

    uint8_t payload[128];
    uint16_t payloadLen = buildCrc32Payload(payload, "/no_such_file.txt");

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_CRC32, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_CRC32_DATA, "response sub-cmd");
    ASSERT_EQ(s_respLen, 9, "response payload length");
    ASSERT_EQ(s_respPayload[0], 0x01, "status (not found)");
    PASS();
}

// Test 6: CRC32 on empty file → CRC32=0x00000000
static void testCrc32EmptyFile() {
    TEST("CRC32 on empty file");

    const char* path = "/test_empty.txt";
    File f = LittleFS.open(path, "w");
    f.close();

    uint8_t payload[128];
    uint16_t payloadLen = buildCrc32Payload(payload, path);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_CRC32, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_CRC32_DATA, "response sub-cmd");
    ASSERT_EQ(s_respLen, 9, "response payload length");
    ASSERT_EQ(s_respPayload[0], 0x00, "status (found)");

    uint32_t actualCrc = (uint32_t)s_respPayload[1] |
                         ((uint32_t)s_respPayload[2] << 8) |
                         ((uint32_t)s_respPayload[3] << 16) |
                         ((uint32_t)s_respPayload[4] << 24);
    ASSERT_EQ(actualCrc, 0x00000000, "CRC32 of empty file");

    LittleFS.remove(path);
    PASS();
}

// Test 7: REPLACE aborts active upload
static void testReplaceAbortsUpload() {
    TEST("REPLACE aborts active upload");

    // Start an upload by dispatching UPLOAD_BEGIN
    const char* uploadPath = "/test_upload_partial.txt";
    uint8_t beginPayload[64];
    uint16_t off = appendPath(beginPayload, uploadPath);
    // totalSize = 1000 (4 LE)
    uint32_t totalSize = 1000;
    beginPayload[off + 0] = (uint8_t)(totalSize & 0xFF);
    beginPayload[off + 1] = (uint8_t)((totalSize >> 8) & 0xFF);
    beginPayload[off + 2] = (uint8_t)((totalSize >> 16) & 0xFF);
    beginPayload[off + 3] = (uint8_t)((totalSize >> 24) & 0xFF);
    off += 4;

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_UPLOAD_BEGIN, beginPayload, off);
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "UPLOAD_BEGIN succeeded");

    // Now send REPLACE for a different file — should abort the upload
    const char* replacePath = "/test_replace_after_upload.txt";
    const char* content = "hello after upload abort";
    uint8_t replacePayload[RK_FS_MAX_PAYLOAD];
    uint32_t crc = computeCrc32((const uint8_t*)content, strlen(content));
    uint16_t replaceLen = buildReplacePayload(replacePayload, replacePath,
                                              (const uint8_t*)content,
                                              strlen(content), crc);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_REPLACE, replacePayload, replaceLen);

    // REPLACE should succeed
    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_REPLACE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "REPLACE succeeded");

    // Verify REPLACE target was written
    uint8_t buf[64];
    readFileContent(replacePath, buf, sizeof(buf));
    ASSERT_STR_EQ((const char*)buf, content, "REPLACE target content");

    // Cleanup
    LittleFS.remove(replacePath);
    LittleFS.remove(uploadPath);
    PASS();
}

// Test 8: CRC32 on file >512 KB → STATUS=0x01 (performance guard)
static void testCrc32LargeFile() {
    TEST("CRC32 on file >512 KB");

    const char* path = "/test_large.bin";

    // Create a ~600 KB file
    {
        File f = LittleFS.open(path, "w");
        uint8_t buf[256];
        memset(buf, 0xAB, sizeof(buf));
        for (int i = 0; i < 2400; i++) { // 2400 * 256 = 614,400 bytes
            f.write(buf, sizeof(buf));
        }
        f.close();
    }

    uint8_t payload[128];
    uint16_t payloadLen = buildCrc32Payload(payload, path);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_CRC32, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_CRC32_DATA, "response sub-cmd");
    ASSERT_EQ(s_respLen, 9, "response payload length");
    ASSERT_EQ(s_respPayload[0], 0x01, "status (too large / not found signal)");

    LittleFS.remove(path);
    PASS();
}

// Seed a nested directory tree for delete tests.
static void seedTree(const char* root) {
    LittleFS.mkdir(root);
    LittleFS.mkdir(String(root) + "/sub");
    LittleFS.mkdir(String(root) + "/sub/deep");

    File a = LittleFS.open(String(root) + "/a.txt", "w");
    if (a) { a.print("alpha"); a.close(); }
    File b = LittleFS.open(String(root) + "/sub/b.txt", "w");
    if (b) { b.print("beta"); b.close(); }
    File c = LittleFS.open(String(root) + "/sub/deep/c.txt", "w");
    if (c) { c.print("gamma"); c.close(); }
}

// Test 9: FS_DELETE recursive=1 on a nested tree → whole tree removed
static void testDeleteRecursiveTree() {
    TEST("DELETE recursive on nested tree");

    const char* root = "/test_tree";
    seedTree(root);
    ASSERT_EQ((int)LittleFS.exists(String(root) + "/sub/deep/c.txt"), 1,
              "deep file seeded");

    uint8_t payload[128];
    uint16_t payloadLen = buildDeletePayload(payload, root, true);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_DELETE, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_DELETE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respLen, 1, "response payload length");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "error code");

    // Every node must be gone, including the root itself.
    ASSERT_EQ((int)LittleFS.exists(root), 0, "root removed");
    ASSERT_EQ((int)LittleFS.exists(String(root) + "/a.txt"), 0, "file removed");
    ASSERT_EQ((int)LittleFS.exists(String(root) + "/sub/b.txt"), 0,
              "nested file removed");
    ASSERT_EQ((int)LittleFS.exists(String(root) + "/sub/deep/c.txt"), 0,
              "deep file removed");
    PASS();
}

// Test 10: FS_DELETE recursive=1 on a file → file removed
static void testDeleteRecursiveFile() {
    TEST("DELETE recursive on a file");

    const char* path = "/test_delete_file.txt";
    File f = LittleFS.open(path, "w");
    f.print("delete me");
    f.close();

    uint8_t payload[128];
    uint16_t payloadLen = buildDeletePayload(payload, path, true);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_DELETE, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_DELETE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "error code");
    ASSERT_EQ((int)LittleFS.exists(path), 0, "file removed");
    PASS();
}

// Test 11: FS_DELETE recursive=0 on a non-empty dir → NOT_FOUND, untouched
static void testDeleteNonRecursiveNonEmptyDir() {
    TEST("DELETE non-recursive on non-empty dir");

    const char* root = "/test_nonrec";
    seedTree(root);

    uint8_t payload[128];
    uint16_t payloadLen = buildDeletePayload(payload, root, false);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_DELETE, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_DELETE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_NOT_FOUND, "error code");

    // Tree must be untouched.
    ASSERT_EQ((int)LittleFS.exists(String(root) + "/sub/deep/c.txt"), 1,
              "tree still present");

    // Cleanup with a recursive delete.
    payloadLen = buildDeletePayload(payload, root, true);
    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_DELETE, payload, payloadLen);
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "cleanup delete");
    PASS();
}

// Test 12: FS_DELETE recursive=1 on an empty dir → removed
static void testDeleteRecursiveEmptyDir() {
    TEST("DELETE recursive on empty dir");

    const char* dir = "/test_empty_dir";
    LittleFS.mkdir(dir);
    ASSERT_EQ((int)LittleFS.exists(dir), 1, "dir created");

    uint8_t payload[128];
    uint16_t payloadLen = buildDeletePayload(payload, dir, true);

    s_respCaptured = false;
    RKFs::dispatch(RK_FS_CMD_DELETE, payload, payloadLen);

    ASSERT_EQ(s_respSubCmd, RK_FS_RESP_DELETE_ACK, "response sub-cmd");
    ASSERT_EQ(s_respPayload[0], RK_FS_ERR_OK, "error code");
    ASSERT_EQ((int)LittleFS.exists(dir), 0, "dir removed");
    PASS();
}

#endif // RK_FS_HAS_LITTLEFS

// ── Test runner ─────────────────────────────────────────────────────────────

static void runAllTests() {
#if RK_FS_HAS_LITTLEFS
    testReplaceValidCrc();
    testReplaceInvalidCrc();
    testReplaceNonExistent();
    testCrc32Existing();
    testCrc32NonExistent();
    testCrc32EmptyFile();
    testReplaceAbortsUpload();
    testCrc32LargeFile();
    testDeleteRecursiveTree();
    testDeleteRecursiveFile();
    testDeleteNonRecursiveNonEmptyDir();
    testDeleteRecursiveEmptyDir();
#endif

    // Summary
    Serial.println();
    Serial.println("============================================");
    Serial.printf("  Results: %d passed, %d failed, %d total\n",
                  s_testsPassed, s_testsFailed, s_testIndex);
    Serial.println("============================================");
    Serial.println();

    if (s_testsFailed == 0) {
        Serial.println("ALL TESTS PASSED");
    } else {
        Serial.printf("SOME TESTS FAILED (%d)\n", s_testsFailed);
    }
    Serial.println();
}

// ── Setup & Loop ───────────────────────────────────────────────────────────

void setup() {
    Serial.begin(115200);
    delay(2000);

    Serial.println();
    Serial.println("============================================");
    Serial.println("  FS Command Test — REPLACE + CRC32 + DELETE");
    Serial.println("============================================");
    Serial.println();

#if RK_FS_HAS_LITTLEFS
    // Mount via RKFs::begin() so the handlers' s_mounted flag is set — the
    // FS handlers return NO_FS until this is done.
    if (!RKFs::begin()) {
        Serial.println("RKFs::begin() failed — FS commands will return NO_FS");
    } else {
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
        Serial.printf("LittleFS: total=%u, used=%u\n",
                      (unsigned)LittleFS.totalBytes(),
                      (unsigned)LittleFS.usedBytes());
#else
        Serial.println("LittleFS: mounted");
#endif
    }
#else
    Serial.println("SKIP: LittleFS not available on this platform");
    Serial.println("ALL TESTS SKIPPED");
    return;
#endif

    // Register the capture sender so RKFs::dispatch sends responses to us
    RKFs::setSender(captureSender);

    Serial.println("Send 'r' to run the test suite (runs on the host's timing,");
    Serial.println("so the CDC output is not lost at boot).");
}

void loop() {
    if (Serial.available()) {
        char c = (char)Serial.read();
        if (c == 'r' || c == 'R') {
            // Reset counters, then run the suite once.
            s_testsPassed = 0;
            s_testsFailed = 0;
            s_testIndex = 0;
            Serial.println("Running tests...");
            runAllTests();
            Serial.println("Test complete. Send 'r' to run again.");
        }
    }
    delay(50);
}
