/**
 * FsCommandHandler.cpp
 * Implementation of 0xAA LittleFS file transfer protocol dispatching.
 */

#include "FsCommandHandler.h"
#include "../RadioKitClass.h"

extern RadioKitClass RadioKit;

FsCommandHandler& FsCommandHandler::instance() {
    static FsCommandHandler inst;
    return inst;
}

void FsCommandHandler::handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) {
    RadioKit._onFsPacket(cmd, payload, payloadLen);
}
