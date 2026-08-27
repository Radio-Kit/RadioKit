/**
 * ICommandHandler.h
 * Abstract interface for RadioKit protocol command handlers (v2.0).
 */

#ifndef RADIOKIT_ICOMMAND_HANDLER_H
#define RADIOKIT_ICOMMAND_HANDLER_H

#include <Arduino.h>
#include <stdint.h>

class ICommandHandler {
public:
    virtual ~ICommandHandler() {}

    /// Frame header command byte handled by this processor (e.g. 0x55, 0xAA, 0xBB, 0xDD, 0xEE)
    virtual uint8_t getHeaderByte() const = 0;

    /// Dispatches a received valid packet frame to this handler
    virtual void handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) = 0;
};

#endif // RADIOKIT_ICOMMAND_HANDLER_H
