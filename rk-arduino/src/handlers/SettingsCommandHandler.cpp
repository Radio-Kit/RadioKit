/**
 * SettingsCommandHandler.cpp
 * Implementation of 0xDD settings protocol dispatching.
 */

#include "SettingsCommandHandler.h"
#include "../RadioKitClass.h"

extern RadioKitClass RadioKit;

SettingsCommandHandler& SettingsCommandHandler::instance() {
    static SettingsCommandHandler inst;
    return inst;
}

void SettingsCommandHandler::handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) {
    RadioKit._onSettingsPacket(cmd, payload, payloadLen);
}
