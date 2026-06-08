/**
 * RadioKitTransport.h
 * Abstract transport interface for RadioKit.
 *
 * Both BLE and Serial backends implement this interface.
 * RadioKitClass holds a pointer to the active transport and calls
 * only these four methods — no transport-specific code in the core.
 */

#ifndef RADIOKIT_TRANSPORT_H
#define RADIOKIT_TRANSPORT_H

#include <Arduino.h>
#include <stdint.h>

/// Callback signature: called by the transport when a complete
/// widget-protocol (0x55) frame has been received and CRC-validated.
typedef void (*RK_PacketCallback)(uint8_t cmd,
                                  const uint8_t* payload,
                                  uint16_t payloadLen);

/// Callback signature: called by the transport when a complete
/// bulk-FS-protocol (0xAA) frame has been received. No CRC validation
/// (transport reliability is sufficient for short bursts).
typedef void (*RK_FsPacketCallback)(uint8_t subCmd,
                                    const uint8_t* payload,
                                    uint16_t payloadLen);

/// Callback signature: called by the transport when a complete
/// OTA-protocol (0xBB) frame has been received.
typedef void (*RK_OtaPacketCallback)(uint8_t subCmd,
                                     const uint8_t* payload,
                                     uint16_t payloadLen);

class RadioKitTransport {
public:
    virtual ~RadioKitTransport() {}

    /**
     * Initialise the transport.
     * @param name  Device/service name (used by BLE; ignored by Serial).
     * @param cb    Packet callback invoked on every valid received
     *              widget-protocol frame.
     */
    virtual void begin(const char* name, RK_PacketCallback cb) = 0;

    /** Register the bulk-FS callback. Optional — only needed for FS support. */
    virtual void setFsCallback(RK_FsPacketCallback cb) { (void)cb; }

    /** Register the OTA callback. Optional — only needed for OTA support. */
    virtual void setOtaCallback(RK_OtaPacketCallback cb) { (void)cb; }

    /** Poll for incoming data / handle async events. Call every loop(). */
    virtual void update() = 0;

    /** Transmit a fully-formed RadioKit packet. */
    virtual void sendPacket(const uint8_t* buf, uint16_t len) = 0;

    /** Returns true if a remote peer is currently connected/active. */
    virtual bool isConnected() const = 0;

    /** Returns the current signal strength in dBm, or 0 if unknown/unsupported. */
    virtual int8_t getRssi() = 0;
};

#endif // RADIOKIT_TRANSPORT_H
