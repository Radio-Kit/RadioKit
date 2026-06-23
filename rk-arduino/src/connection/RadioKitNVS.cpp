/**
 * RadioKitNVS.cpp
 * NVS implementation using ESP32's nvs_flash API.
 *
 * On non-ESP32 platforms, all methods are no-ops.
 */

#include "RadioKitNVS.h"

// ESP32 NVS headers — only available on ESP32
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
#include <nvs_flash.h>
#include <nvs.h>
#endif

// ── Static state ────────────────────────────────────────────────────────────
bool     RKNvs::s_initialized = false;
bool     RKNvs::s_open        = false;
uint32_t RKNvs::s_handle      = 0;

bool RKNvs::init() {
    if (s_initialized) return true;

#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    // Initialise NVS flash. If the partition is in an inconsistent state
    // (e.g. after esptool erase_flash, or ESP-IDF version change), nvs_flash_init
    // may return ESP_ERR_NVS_NO_FREE_PAGES or ESP_ERR_NVS_NEW_VERSION_FOUND.
    // In that case we erase and re-init.
    esp_err_t initErr = nvs_flash_init();

    if (initErr == ESP_ERR_NVS_NO_FREE_PAGES || initErr == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        esp_err_t eraseErr = nvs_flash_erase();
        if (eraseErr != ESP_OK) {
            Serial.printf("NVS: flash erase failed (%d)\n", eraseErr);
            return false;
        }
        initErr = nvs_flash_init();
    }

    if (initErr != ESP_OK) {
        Serial.printf("NVS: flash init failed (%d)\n", initErr);
        return false;
    }

    // Open the "radiokit_cfg" namespace
    nvs_handle_t handle;
    esp_err_t openErr = nvs_open(RK_NVS_NAMESPACE, NVS_READWRITE, &handle);
    if (openErr != ESP_OK) {
        Serial.printf("NVS: open namespace failed (%d)\n", openErr);
        return false;
    }
    s_handle = (uint32_t)handle;
    s_open   = true;
    s_initialized = true;

    return true;
#else
    // Non-ESP32: no-op
    s_initialized = true;  // Mark as initialized even without NVS
    return false;
#endif
}

bool RKNvs::readString(const char* key, char* out, size_t maxLen) {
    if (!s_open || !key || !out || maxLen == 0) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    size_t requiredLen = maxLen;
    esp_err_t err = nvs_get_str(handle, key, out, &requiredLen);
    if (err == ESP_ERR_NVS_NOT_FOUND) return false;
    if (err != ESP_OK) return false;
    return true;
#else
    (void)key; (void)out; (void)maxLen;
    return false;
#endif
}

bool RKNvs::writeString(const char* key, const char* val) {
    if (!s_open || !key || !val) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    esp_err_t err = nvs_set_str(handle, key, val);
    return (err == ESP_OK);
#else
    (void)key; (void)val;
    return false;
#endif
}

bool RKNvs::commit() {
    if (!s_open) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    esp_err_t err = nvs_commit(handle);
    return (err == ESP_OK);
#else
    return false;
#endif
}

bool RKNvs::eraseKey(const char* key) {
    if (!s_open || !key) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    esp_err_t err = nvs_erase_key(handle, key);
    return (err == ESP_OK);
#else
    (void)key;
    return false;
#endif
}

bool RKNvs::eraseAll() {
    if (!s_open) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    esp_err_t err = nvs_erase_all(handle);
    if (err == ESP_OK) {
        err = nvs_commit(handle);
    }
    return (err == ESP_OK);
#else
    return false;
#endif
}

bool RKNvs::readU8(const char* key, uint8_t* out) {
    if (!s_open || !key || !out) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    esp_err_t err = nvs_get_u8(handle, key, out);
    if (err == ESP_ERR_NVS_NOT_FOUND) return false;
    if (err != ESP_OK) return false;
    return true;
#else
    (void)key; (void)out;
    return false;
#endif
}

bool RKNvs::writeU8(const char* key, uint8_t val) {
    if (!s_open || !key) return false;
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    nvs_handle_t handle = (nvs_handle_t)s_handle;
    esp_err_t err = nvs_set_u8(handle, key, val);
    return (err == ESP_OK);
#else
    (void)key; (void)val;
    return false;
#endif
}

void RKNvs::close() {
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    if (s_open) {
        nvs_handle_t handle = (nvs_handle_t)s_handle;
        nvs_close(handle);
    }
#endif
    s_open = false;
    s_initialized = false;
    s_handle = 0;
}
