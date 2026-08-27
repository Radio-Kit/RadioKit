/**
 * RadioKitNVS.h
 * NVS (Non-Volatile Storage) utility for persisting device configuration.
 *
 * Stores name, description, and password in the "radiokit_cfg" NVS namespace
 * so they survive OTA firmware updates. On non-ESP32 platforms all methods
 * are no-ops (returns false / empty defaults).
 *
 * First-boot behaviour: when NVS is empty (no "rk_name" key), the firmware
 * writes compile-time defaults from RK_Config. After that, NVS is the source
 * of truth and compile-time defaults are never re-applied.
 */

#ifndef RADIOKIT_NVS_H
#define RADIOKIT_NVS_H

#include <Arduino.h>
#include <stdint.h>
#include <string.h>
#include "RadioKitConfig.h"

// ── Namespace & key names ───────────────────────────────────────────────────
#define RK_NVS_NAMESPACE    "radiokit_cfg"
#define RK_NVS_KEY_NAME     "rk_name"
#define RK_NVS_KEY_DESC     "rk_desc"
#define RK_NVS_KEY_PWD      "rk_pwd"
#define RK_NVS_KEY_USER_PWD  "rk_user_pwd"
#define RK_NVS_KEY_PENDING_ERASE  "rk_pend_erase"

// ── WiFi / Cloud NVS keys ────────────────────────────────────────────────────
#define RK_NVS_KEY_STA_SSID       "rk_sta_ssid"
#define RK_NVS_KEY_STA_PWD        "rk_sta_pwd"
#define RK_NVS_KEY_CLOUD_URL      "rk_cloud_url"
#define RK_NVS_KEY_CLOUD_ACCOUNT  "rk_cloud_account"

// ── Device identity ─────────────────────────────────────────────────────────
#define RK_NVS_KEY_DEVICE_UID     "rk_device_uid"
#define RK_NVS_KEY_DEVICE_ICON    "rk_device_icon"

// ── Pending erase mode values (stored in rk_pend_erase) ──────────────────────
#define RK_PENDING_ERASE_NONE     0  ///< No erase — cleared after operation completes
#define RK_PENDING_ERASE_BOTH     1  ///< Erase NVS config + format LittleFS
#define RK_PENDING_ERASE_NVS      2  ///< Erase NVS config only
#define RK_PENDING_ERASE_FS       3  ///< Format LittleFS only

// ── Max string sizes (copied from RadioKitConfig.h to avoid circular include) ─
#define RK_NVS_MAX_NAME     32
#define RK_NVS_MAX_DESC     128
#define RK_NVS_MAX_PWD      32

class RKNvs {
public:
    /**
     * Initialise the NVS subsystem and open the "radiokit_cfg" namespace.
     * If the NVS partition has been wiped (e.g. after esptool erase_flash),
     * this automatically erases and re-initialises it.
     * Safe to call multiple times — subsequent calls are no-ops if already open.
     * Returns true on success, false on non-ESP32 or init failure.
     */
    static bool init();

    /// True once init() has succeeded.
    static bool isInitialized() { return s_initialized; }

    /**
     * Read a string from NVS.
     * @param key   NVS key (e.g. RK_NVS_KEY_NAME)
     * @param out   Destination buffer (must be at least [maxLen] bytes)
     * @param maxLen Max bytes to write (including null terminator)
     * @return true if the key existed and was read successfully
     */
    static bool readString(const char* key, char* out, size_t maxLen);

    /**
     * Write a string to NVS.
     * @param key   NVS key (e.g. RK_NVS_KEY_NAME)
     * @param val   Null-terminated string value
     * @return true on success
     */
    static bool writeString(const char* key, const char* val);

    /**
     * Commit pending writes to flash.
     * @return true on success
     */
    static bool commit();

    /**
     * Erase a single key from the namespace.
     * @return true on success
     */
    static bool eraseKey(const char* key);

    /**
     * Erase all keys in the "radiokit_cfg" namespace.
     * @return true on success
     */
    static bool eraseAll();

    /**
     * Read a uint8 value from NVS.
     * @param key   NVS key
     * @param out   Destination
     * @return true if the key existed and was read successfully
     */
    static bool readU8(const char* key, uint8_t* out);

    /**
     * Write a uint8 value to NVS.
     * @param key   NVS key
     * @param val   Value to write
     * @return true on success
     */
    static bool writeU8(const char* key, uint8_t val);

    /// Close the NVS namespace handle. init() must be called again after this.
    static void close();

private:
    static bool          s_initialized;
    static bool          s_open;
    static uint32_t      s_handle;  // nvs_handle_t stored as uint32_t to avoid
                                     // exposing ESP-IDF types in the header
};

#endif // RADIOKIT_NVS_H
