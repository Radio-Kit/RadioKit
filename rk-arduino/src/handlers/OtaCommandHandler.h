/**
 * OtaCommandHandler.h
 * Handler for 0xBB OTA firmware update protocol frames.
 */

#ifndef RADIOKIT_OTA_COMMAND_HANDLER_H
#define RADIOKIT_OTA_COMMAND_HANDLER_H

#include "../core/ICommandHandler.h"

class OtaCommandHandler : public ICommandHandler {
public:
    static OtaCommandHandler& instance();

    virtual uint8_t getHeaderByte() const override { return 0xBB; }
    virtual void handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) override;
};

#endif // RADIOKIT_OTA_COMMAND_HANDLER_H
