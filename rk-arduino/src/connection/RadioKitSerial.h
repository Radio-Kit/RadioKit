/**
 * RadioKitSerial.h
 * USB Serial transport for RadioKit.
 * Implements RadioKitTransport over any Arduino Stream (Serial, Serial1, …).
 *
 * The sketch is responsible for calling Serial.begin() before startSerial().
 * RadioKit never touches the hardware peripheral directly.
 *
 * Connection model:
 *   isConnected() returns true for TIMEOUT_MS after the last valid packet.
 *   The app should send PING every ~1000 ms to keep the session alive.
 *
 * Usage:
 *   Serial.begin(115200);
 *   RadioKit.startSerial(Serial);
 */

#ifndef RADIOKIT_SERIAL_H
#define RADIOKIT_SERIAL_H

#include <Arduino.h>
#include "RadioKitTransport.h"

class RadioKitSerialTransport : public RadioKitTransport {
public:
    RadioKitSerialTransport();

    /**
     * Attach the transport to an already-initialised Stream.
     * The sketch must call stream.begin() (or Serial.begin()) beforehand.
     *
     * @param stream  Any Arduino Stream — Serial, Serial1, SoftwareSerial, …
     * @param cb      Packet callback.
     */
    void begin(Stream& stream, RK_PacketCallback cb);

    /** Satisfies RadioKitTransport pure-virtual; unused for serial. */
    void begin(const char* /*name*/, RK_PacketCallback cb) override;

    void setFsCallback(RK_FsPacketCallback cb) override;
    void setOtaCallback(RK_OtaPacketCallback cb) override;
    void setSettingsCallback(RK_SettingsPacketCallback cb) override;
    void setPrintCallback(RK_PrintPacketCallback cb) override;

    void update()                                      override;
    void sendPacket(const uint8_t* buf, uint16_t len)  override;
    bool isConnected() const                           override;
    int8_t getRssi()                                   override;

    /// ms since last valid packet before isConnected() returns false.
    /// Increased from 3s to 30s to match the app-side session timeout and
    /// prevent premature disconnection during slow serial operations (e.g.
    /// auth handshake, FS transfers, config loading). Serial auth bypass
    /// (per-transport _packetSource) makes this timeout harmless for auth.
    static constexpr uint32_t TIMEOUT_MS = 30000;

private:
    Stream*             _stream;
    RK_PacketCallback   _cb;
    RK_FsPacketCallback _fsCb;
    RK_OtaPacketCallback _otaCb;
    RK_SettingsPacketCallback _settingsCb;
    RK_PrintPacketCallback _printCb;
    uint32_t            _lastPacketMs;
    uint32_t            _lastByteMs;
    bool                _everReceived;
};

extern RadioKitSerialTransport RadioKitSerialInstance;

#endif // RADIOKIT_SERIAL_H
