/**
 * ControlCommandHandler.cpp
 * Implementation of 0x55 widget control command dispatching.
 */

#include "ControlCommandHandler.h"
#include "../RadioKitClass.h"

extern RadioKitClass RadioKit;

ControlCommandHandler& ControlCommandHandler::instance() {
    static ControlCommandHandler inst;
    return inst;
}

void ControlCommandHandler::handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) {
    RadioKit._onPacket(cmd, payload, payloadLen);
}
