/**
 * SettingsCommandHandler.h
 * Handler for 0xDD settings & NVS authentication protocol frames.
 */

#ifndef RADIOKIT_SETTINGS_COMMAND_HANDLER_H
#define RADIOKIT_SETTINGS_COMMAND_HANDLER_H

#include "../core/ICommandHandler.h"

class SettingsCommandHandler : public ICommandHandler {
public:
    static SettingsCommandHandler& instance();

    virtual uint8_t getHeaderByte() const override { return 0xDD; }
    virtual void handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) override;
};

#endif // RADIOKIT_SETTINGS_COMMAND_HANDLER_H
