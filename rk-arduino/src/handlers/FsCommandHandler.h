/**
 * FsCommandHandler.h
 * Handler for 0xAA LittleFS bulk file transfer protocol frames.
 */

#ifndef RADIOKIT_FS_COMMAND_HANDLER_H
#define RADIOKIT_FS_COMMAND_HANDLER_H

#include "../core/ICommandHandler.h"

class FsCommandHandler : public ICommandHandler {
public:
    static FsCommandHandler& instance();

    virtual uint8_t getHeaderByte() const override { return 0xAA; }
    virtual void handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) override;
};

#endif // RADIOKIT_FS_COMMAND_HANDLER_H
