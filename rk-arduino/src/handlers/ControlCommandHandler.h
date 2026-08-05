/**
 * ControlCommandHandler.h
 * Handler for 0x55 widget control protocol frames.
 */

#ifndef RADIOKIT_CONTROL_COMMAND_HANDLER_H
#define RADIOKIT_CONTROL_COMMAND_HANDLER_H

#include "../core/ICommandHandler.h"

class ControlCommandHandler : public ICommandHandler {
public:
    static ControlCommandHandler& instance();

    virtual uint8_t getHeaderByte() const override { return 0x55; }
    virtual void handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) override;
};

#endif // RADIOKIT_CONTROL_COMMAND_HANDLER_H
