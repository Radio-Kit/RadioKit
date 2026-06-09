/**
 * RadioKitSerial.cpp
 * USB Serial transport implementation.
 */

#include "RadioKitSerial.h"
#include "../RadioKitProtocol.h"
#include "RadioKitFS.h"
#include "RadioKitOTA.h"
#include "RadioKitSettings.h"

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

void RadioKitSerialTransport::update() {
    if (!_stream) return;

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
        }
    }

    // Junk recovery: reset framing if mid-packet but silent for >1000 ms
    if (_lastByteMs > 0 && (millis() - _lastByteMs) > 1000) {
        rk_rxReset();
        rk_fsRxReset();
        rk_otaRxReset();
        rk_settingsRxReset();
        _lastByteMs = 0;
    }
}

void RadioKitSerialTransport::sendPacket(const uint8_t* buf, uint16_t len) {
    if (!_stream) return;
    _stream->write(buf, len);
}

bool RadioKitSerialTransport::isConnected() const {
    if (!_everReceived) return false;
    return (millis() - _lastPacketMs) < TIMEOUT_MS;
}

int8_t RadioKitSerialTransport::getRssi() {
    return 0; // RSSI is not applicable for USB Serial
}
