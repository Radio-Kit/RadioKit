/**
 * PrintCommandHandler.h
 * Handler for 0xEE remote console print stream protocol frames.
 */

#ifndef RADIOKIT_PRINT_COMMAND_HANDLER_H
#define RADIOKIT_PRINT_COMMAND_HANDLER_H

#include "../core/ICommandHandler.h"

class PrintCommandHandler : public ICommandHandler {
public:
    static PrintCommandHandler& instance();

    virtual uint8_t getHeaderByte() const override { return 0xEE; }
    virtual void handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) override;
};

#endif // RADIOKIT_PRINT_COMMAND_HANDLER_H
