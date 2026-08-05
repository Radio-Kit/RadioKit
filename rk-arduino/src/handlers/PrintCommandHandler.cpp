/**
 * PrintCommandHandler.cpp
 * Implementation of 0xEE remote console print stream protocol dispatching.
 */

#include "PrintCommandHandler.h"
#include "../RadioKitClass.h"

extern RadioKitClass RadioKit;

PrintCommandHandler& PrintCommandHandler::instance() {
    static PrintCommandHandler inst;
    return inst;
}

void PrintCommandHandler::handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) {
    RadioKit._onPrintPacket(payload, payloadLen);
}
