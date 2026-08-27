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
// Only active when Serial uses TinyUSB/USB-OTG (ARDUINO_USB_MODE=0).
#if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE == 0 && RK_ARCH_DETECTED == RK_ARCH_ESP32
#include "tusb.h"
#endif

RadioKitSerialTransport RadioKitSerialInstance;

RadioKitSerialTransport::RadioKitSerialTransport()
    : _stream(nullptr), _cb(nullptr), _fsCb(nullptr), _otaCb(nullptr), _settingsCb(nullptr)
    , _lastPacketMs(0), _lastByteMs(0), _everReceived(false), _bleActive(false)
    , _txHead(0), _txTail(0), _txCount(0), _txDropCount(0)
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

#if RK_ARCH_DETECTED == RK_ARCH_ESP32
#if ARDUINO_USB_CDC_ON_BOOT || ARDUINO_USB_MODE
    // Native USB-Serial-JTAG CDC (HWCDC): zero timeout so writes never block main loop
    Serial.setTxTimeoutMs(0);
#endif
#endif
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
    // Skip when BLE is primary — the keepalive is only needed for USB-only.
    if (!_bleActive) {
        static unsigned long _lastKeepaliveMs = 0;
        if (millis() - _lastKeepaliveMs > 250) {
            _lastKeepaliveMs = millis();
            if (_stream->availableForWrite()) {
                _stream->write(static_cast<uint8_t>(0x00));
            }
        }
    }
#endif
    // --- End keepalive ---

    // ── Drain TX ring buffer ──
    while (_txCount > 0) {
        TxPendingFrame& frame = _txRing[_txTail];
        _stream->write(frame.data, frame.len);
        _stream->flush();
        _txTail = (_txTail + 1) % kTxRingSize;
        _txCount--;
    }

    // Diagnostic: log drops every 10 seconds
    if (_txDropCount > 0) {
        static uint32_t s_lastSerialDiagMs = 0;
        uint32_t now = millis();
        if (now - s_lastSerialDiagMs >= 10000) {
            RadioKit.printf("SERIAL: diag — drops=%u\n", _txDropCount);
            _txDropCount = 0;
            s_lastSerialDiagMs = now;
        }
    }

    uint8_t        cmd;
    const uint8_t* payload;
    uint16_t       payloadLen;

    while (_stream->available() > 0) {
        uint8_t byte = (uint8_t)_stream->read();
        _lastByteMs = millis();

        // 1. If an explicit multi-byte protocol is currently active, route exclusively to it
        if (rk_otaRxIsActive()) {
            if (rk_otaRxFeedByte(byte, cmd, payload, payloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_otaCb) _otaCb(cmd, payload, payloadLen);
            }
            continue;
        }

        if (rk_fsRxIsActive()) {
            if (rk_fsRxFeedByte(byte, cmd, payload, payloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_fsCb) _fsCb(cmd, payload, payloadLen);
            }
            continue;
        }

        if (rk_settingsRxIsActive()) {
            if (rk_settingsRxFeedByte(byte, cmd, payload, payloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_settingsCb) _settingsCb(cmd, payload, payloadLen);
            }
            continue;
        }

        if (rk_printRxIsActive()) {
            const uint8_t* printPayload;
            uint16_t printPayloadLen;
            if (rk_printRxFeedByte(byte, printPayload, printPayloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_printCb) _printCb(printPayload, printPayloadLen);
            }
            continue;
        }

        // 2. Not currently inside a frame — route based on start byte
        if (byte == RK_OTA_START_BYTE) {
            if (rk_otaRxFeedByte(byte, cmd, payload, payloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_otaCb) _otaCb(cmd, payload, payloadLen);
            }
            continue;
        }

        if (byte == RK_FS_START_BYTE) {
            if (rk_fsRxFeedByte(byte, cmd, payload, payloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_fsCb) _fsCb(cmd, payload, payloadLen);
            }
            continue;
        }

        if (byte == RK_SETTINGS_START_BYTE) {
            if (rk_settingsRxFeedByte(byte, cmd, payload, payloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_settingsCb) _settingsCb(cmd, payload, payloadLen);
            }
            continue;
        }

        if (byte == RK_PRINT_START_BYTE) {
            const uint8_t* printPayload;
            uint16_t printPayloadLen;
            if (rk_printRxFeedByte(byte, printPayload, printPayloadLen)) {
                _everReceived = true;
                _lastPacketMs = millis();
                if (_printCb) _printCb(printPayload, printPayloadLen);
            }
            continue;
        }

        // 3. Fallback: widget protocol (0x55)
        if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
            _everReceived = true;
            _lastPacketMs = millis();
            if (_cb) _cb(cmd, payload, payloadLen);
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
    if (!_stream || !buf || len == 0) return;
#if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE == 0 && RK_ARCH_DETECTED == RK_ARCH_ESP32
    // TinyUSB CDC mode: only write if host has finished enumeration.
    if (!tud_cdc_connected()) {
        return;
    }
#endif
    size_t totalWritten = 0;
    uint32_t startMs = millis();
    while (totalWritten < len && (millis() - startMs) < 100) {
        size_t n = _stream->write(buf + totalWritten, len - totalWritten);
        if (n > 0) {
            totalWritten += n;
        } else {
            delayMicroseconds(100);
        }
    }
    _stream->flush();
}

bool RadioKitSerialTransport::isConnected() const {
    if (!_everReceived) return false;
    return (millis() - _lastPacketMs) < TIMEOUT_MS;
}

int8_t RadioKitSerialTransport::getRssi() {
    return 0; // RSSI is not applicable for USB Serial
}
