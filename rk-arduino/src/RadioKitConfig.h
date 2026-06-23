/**
 * RadioKitConfig.h
 * Library-wide constants, enums, and helpers for RadioKit.
 *
 * v2.0 / Protocol v3
 */

#ifndef RADIOKIT_CONFIG_H
#define RADIOKIT_CONFIG_H

#include <Arduino.h>
#include <stdint.h>

// ─────────────────────────────────────────────
//  Library version
// ─────────────────────────────────────────────
#define RK_LIB_VERSION "2.0.0"

// ─────────────────────────────────────────────
//  Canvas orientation
// ─────────────────────────────────────────────
#define RK_LANDSCAPE 0x00
#define RK_PORTRAIT 0x01

// ─────────────────────────────────────────────
//  Architecture IDs (auto-detected)
// ─────────────────────────────────────────────
#define RK_ARCH_UNKNOWN 0
#define RK_ARCH_ESP32 1
#define RK_ARCH_NORDIC 2
#define RK_ARCH_SAMD 3
#define RK_ARCH_STM32 4
#define RK_ARCH_RP2040 5

#if defined(ESP32)
#define RK_ARCH_DETECTED RK_ARCH_ESP32
#elif defined(NRF52) || defined(NRF51)
#define RK_ARCH_DETECTED RK_ARCH_NORDIC
#elif defined(ARDUINO_ARCH_SAMD)
#define RK_ARCH_DETECTED RK_ARCH_SAMD
#elif defined(STM32) || defined(ARDUINO_ARCH_STM32)
#define RK_ARCH_DETECTED RK_ARCH_STM32
#elif defined(ARDUINO_ARCH_RP2040) || defined(ARDUINO_NANO_RP2040) || defined(ARDUINO_RASPBERRY_PI_PICO)
#define RK_ARCH_DETECTED RK_ARCH_RP2040
#else
#define RK_ARCH_DETECTED RK_ARCH_UNKNOWN
#endif

// ─────────────────────────────────────────────
//  Platform capabilities (auto-detected from architecture)
// ─────────────────────────────────────────────
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
  #define RK_HAS_BLE  1
  #define RK_HAS_WIFI 1
  #define RK_HAS_NVS  1
  #define RK_HAS_OTA  1
  #define RK_HAS_FS   1
#elif RK_ARCH_DETECTED == RK_ARCH_NORDIC
  #define RK_HAS_BLE  1    // Adafruit Bluefruit (deferred)
  #define RK_HAS_FS   1
#elif RK_ARCH_DETECTED == RK_ARCH_STM32
  #define RK_HAS_FS   1
#elif RK_ARCH_DETECTED == RK_ARCH_RP2040
  #define RK_HAS_WIFI 1    // Pico W only
  #define RK_HAS_FS   1
#else
  #define RK_HAS_FS   1    // fallback: serial + FS only
#endif

// ─────────────────────────────────────────────
//  Filesystem availability
//  RK_FS_HAS_LITTLEFS is defined in RadioKitFsHandlers.h based on
//  the RADIOKIT_FEATURE_FS build flag. Examples that need FS must
//  add -DRADIOKIT_FEATURE_FS to their build_flags in platformio.ini.
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  Transport types
// ─────────────────────────────────────────────
#define RK_TRANSPORT_BLE    0
#define RK_TRANSPORT_SERIAL 1

// ─────────────────────────────────────────────
//  Widget Styles
// ─────────────────────────────────────────────
#define RK_PRIMARY 0
#define RK_DIM 1
#define RK_SUCCESS 2
#define RK_WARNING 3
#define RK_DANGER 4

// ─────────────────────────────────────────────
//  MultipleButton / Select Variants
// ─────────────────────────────────────────────
#define RK_SEGMENTS 0
#define RK_GRID     1
#define RK_WHEEL    2

// ─────────────────────────────────────────────
//  Color hex constants (for RK_LED::setColor)
// ─────────────────────────────────────────────
#define RK_OFF 0x000000
#define RK_RED 0xFF0000
#define RK_GREEN 0x00FF00
#define RK_BLUE 0x0000FF
#define RK_YELLOW 0xFFFF00

// ─────────────────────────────────────────────
// Widget type IDs (protocol)
// ─────────────────────────────────────────────
#define RK_TYPE_PUSH_BUTTON 0x01
#define RK_TYPE_TOGGLE_BUTTON 0x02
#define RK_TYPE_SLIDER 0x03
#define RK_TYPE_JOYSTICK 0x04
#define RK_TYPE_LED 0x05
#define RK_TYPE_TEXT 0x06
#define RK_TYPE_MULTIPLE 0x07
#define RK_TYPE_SLIDE_SWITCH 0x08
#define RK_TYPE_KNOB 0x09
#define RK_TYPE_TELEMETRY 0x0A

// ─────────────────────────────────────────────
//  Self-centering modes (Slider / Knob / Joystick variant bits)
// ─────────────────────────────────────────────
#define RK_SPRING_NONE   0  ///< No spring return (stays where released)
#define RK_SPRING_CENTER 1  ///< Springs to 0 (centre) on release
#define RK_SPRING_MIN    2  ///< Springs to -100 on release (Horizontal)
#define RK_SPRING_MAX    3  ///< Springs to +100 on release (Horizontal)
#define RK_SPRING_TOP    4  ///< Springs to -100 on release (Vertical)
#define RK_SPRING_BOTTOM 5  ///< Springs to +100 on release (Vertical)

/// Pack centering mode and detent count into a single variant byte.
/// @param centering  RK_CENTER_NONE / CENTER / MIN / MAX  (bits [1:0])
/// @param detents    0 = continuous; 1–63 = snap positions  (bits [7:2])
#define RK_VARIANT(centering, detents) \
    ((uint8_t)(((detents) << 2) | ((centering) & 0x03)))

// ─────────────────────────────────────────────
//  String Bitmask bits (CONF_DATA widget descriptor)
// ─────────────────────────────────────────────
// Label is always present — no mask bit needed (bit 0 reserved).
#define RK_STR_LABEL_HIDDEN  (1 << 1) ///< Label visibility flag (hidden when set)
#define RK_STR_WIDGET_HIDDEN (1 << 2) ///< Widget visibility flag (hidden when set)
#define RK_STR_ICON          (1 << 3) ///< Icon string present
#define RK_STR_ONTEXT        (1 << 4) ///< OnText string present
#define RK_STR_OFFTEXT       (1 << 5) ///< OffText string present
#define RK_STR_CONTENT       (1 << 6) ///< Content (Text widget initial value)
#define RK_STR_EXTRA         (1 << 7) ///< Widget-specific binary configuration (v3.1+)

// ─────────────────────────────────────────────
//  Widget limits
// ─────────────────────────────────────────────
#define RADIOKIT_MAX_WIDGETS 16
#define RADIOKIT_MAX_LABEL   32  ///< Widget label, onText, offText max chars
#define RADIOKIT_MAX_ICON    24  ///< Icon string max chars
#define RADIOKIT_MAX_NAME    32  ///< Device name max chars
#define RADIOKIT_MAX_DESC   128  ///< Device description max chars
#define RADIOKIT_MAX_PWD     32  ///< Connection password max chars
#define RADIOKIT_MAX_USER_PWD 32  ///< User password max chars
#define RADIOKIT_TEXT_LEN    32  ///< Text widget content max chars
#define RADIOKIT_MAX_ITEMS    8  ///< MultipleButton/Select item pool size

// ─────────────────────────────────────────────
//  WiFi / Cloud config limits
// ─────────────────────────────────────────────
#define RADIOKIT_MAX_SSID           32  ///< STA SSID max chars
#define RADIOKIT_MAX_WIFI_PWD       64  ///< STA WiFi password max chars
#define RADIOKIT_MAX_CLOUD_URL      128 ///< Cloud relay URL max chars
#define RADIOKIT_MAX_CLOUD_ACCOUNT  64  ///< Account identifier max chars

// ─────────────────────────────────────────────
//  Device icon limits
// ─────────────────────────────────────────────
#define RADIOKIT_MAX_DEVICE_ICON   32  ///< Device icon name max chars

// ─────────────────────────────────────────────
//  Feature flags (user opt-in)
//  RK_HAS_*  = platform hardware capability (auto-detected above)
//  RK_*_ENABLED = user wants this transport/feature (define in sketch/codegen)
//
//  The sketch or generated code must #define RK_BLE_ENABLED and/or
//  RK_WIFI_ENABLED before #include <RadioKitLib.h> when those transports
//  are wanted. This decouples platform capability from user intent.
//
//  If undefined, they default to 0 (disabled). To enable, the sketch
//  defines them before including <RadioKitLib.h>:
//    #define RK_BLE_ENABLED 1
//    #define RK_WIFI_ENABLED 1
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  Print stream buffer size
// ─────────────────────────────────────────────
#ifndef RK_PRINT_BUF_SIZE
#define RK_PRINT_BUF_SIZE 1024
#endif

// ─────────────────────────────────────────────
//  Rotation helper
// ─────────────────────────────────────────────
#define RK_ROT(deg) ((int16_t)(deg))

#endif // RADIOKIT_CONFIG_H
