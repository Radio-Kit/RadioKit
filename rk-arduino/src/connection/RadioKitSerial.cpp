/**
 * RadioKitSerial.cpp
 * USB Serial transport implementation.
 */

#include "RadioKitSerial.h"
#include "../RadioKitProtocol.h"
#include "RadioKitFS.h"
#include "RadioKitOTA.h"
#include "RadioKitSettings.h"
#include "RadioKitPrint.h"

// TinyUSB CDC connection guard for sendPacket.
// Only active when Serial uses the native USB Serial/JTAG controller (ARDUINO_USB_MODE=1).
// When MODE=0 (TinyUSB/USB-OTG), TinyUSB handles enumeration automatically
// and the tud_cdc_connected() guard is not compiled in.
//
// NOTE: The ESP32-S3 has two USB controllers sharing a single internal PHY:
//   ARDUINO_USB_MODE=1 → Native USB Serial/JTAG controller (fixed-function HW block)
//   ARDUINO_USB_MODE=0 → USB-OTG controller (TinyUSB, software-controllable stack)
//
// The keepalive null byte in update() is only needed for MODE=1 (native controller)
// to prevent the hardware IN endpoint from stalling. TinyUSB handles this properly.
#if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE == 1 && RK_ARCH_DETECTED == RK_ARCH_ESP32
#include "tusb.h"
#endif

RadioKitSerialTransport RadioKitSerialInstance;

RadioKitSerialTransport::RadioKitSerialTransport()
    : _stream(nullptr), _cb(nullptr), _fsCb(nullptr), _otaCb(nullptr), _settingsCb(nullptr)
    , _lastPacketMs(0), _lastByteMs(0), _everReceived(false)
{}

void RadioKitSerialTransport::begin(Stream& stream, RK_PacketCallback cb) {
    _stream       = &stream;
    _cb           = cb;
    _fsCb         = nullptr;
    _otaCb        = nullptr;
    _settingsCb   = nullptr;
    _lastPacketMs = 0;
    _lastByteMs   = 0;
    _everReceived = false;
    rk_rxReset();
    rk_fsRxReset();
    rk_settingsRxReset();
}

void RadioKitSerialTransport::begin(const char* /*name*/, RK_PacketCallback cb) {
    _cb = cb;  // stream must be set via begin(Stream&, cb) overload
}

void RadioKitSerialTransport::setFsCallback(RK_FsPacketCallback cb) {
    _fsCb = cb;
}

void RadioKitSerialTransport::setOtaCallback(RK_OtaPacketCallback cb) {
    _otaCb = cb;
}

void RadioKitSerialTransport::setSettingsCallback(RK_SettingsPacketCallback cb) {
    _settingsCb = cb;
}

void RadioKitSerialTransport::setPrintCallback(RK_PrintPacketCallback cb) {
    _printCb = cb;
}

void RadioKitSerialTransport::update() {
    if (!_stream) return;

#if RK_ARCH_DETECTED == RK_ARCH_ESP32
    // --- USB IN endpoint keepalive ---
    // The ESP32-S3's native USB Serial/JTAG controller may stall the IN
    // endpoint when no data is pending to send. Android's USB Host API
    // cannot reliably recover from this stall. By periodically writing a
    // null byte, we keep the endpoint active and prevent STALL.
    static unsigned long _lastKeepaliveMs = 0;
    if (millis() - _lastKeepaliveMs > 250) {
        _lastKeepaliveMs = millis();
        if (_stream->availableForWrite()) {
            _stream->write(static_cast<uint8_t>(0x00));
        }
    }
#endif
    // --- End keepalive ---

    uint8_t        cmd;
    const uint8_t* payload;
    uint16_t       payloadLen;

    while (_stream->available() > 0) {
        uint8_t byte = (uint8_t)_stream->read();
        _lastByteMs = millis();

        // Route to widget state machine (0x55)
        if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            if (_cb) _cb(cmd, payload, payloadLen);
            continue;
        }

        // Route to FS state machine (0xAA)
        if (rk_fsRxFeedByte(byte, cmd, payload, payloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            if (_fsCb) _fsCb(cmd, payload, payloadLen);
            continue;
        }

        // Route to OTA state machine (0xBB)
        if (rk_otaRxFeedByte(byte, cmd, payload, payloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            if (_otaCb) _otaCb(cmd, payload, payloadLen);
            continue;
        }

        // Route to Settings state machine (0xDD)
        if (rk_settingsRxFeedByte(byte, cmd, payload, payloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            if (_settingsCb) _settingsCb(cmd, payload, payloadLen);
            continue;
        }

        // Route to Print stream state machine (0xEE — unidirectional)
        const uint8_t* printPayload;
        uint16_t printPayloadLen;
        if (rk_printRxFeedByte(byte, printPayload, printPayloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            if (_printCb) _printCb(printPayload, printPayloadLen);
        }
    }

    // Junk recovery: reset framing if mid-packet but silent for >1000 ms
    if (_lastByteMs > 0 && (millis() - _lastByteMs) > 1000) {
        rk_rxReset();
        rk_fsRxReset();
        rk_otaRxReset();
        rk_settingsRxReset();
        rk_printRxReset();
        _lastByteMs = 0;
    }
}

void RadioKitSerialTransport::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_stream) return;
#if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE == 1 && RK_ARCH_DETECTED == RK_ARCH_ESP32
    // TinyUSB CDC mode: only write if host has finished enumeration.
    // Writing before the host is ready causes the IN endpoint to STALL,
    // which Android may never recover from even with clearHalt.
    if (!tud_cdc_connected()) {
        return;
    }
#endif
    _stream->write(buf, len);
}

bool RadioKitSerialTransport::isConnected() const {
    if (!_everReceived) return false;
    return (millis() - _lastPacketMs) < TIMEOUT_MS;
}

int8_t RadioKitSerialTransport::getRssi() {
    return 0; // RSSI is not applicable for USB Serial
}
