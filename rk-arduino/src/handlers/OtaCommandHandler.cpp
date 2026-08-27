/**
 * OtaCommandHandler.cpp
 * Implementation of 0xBB OTA firmware update protocol dispatching.
 */

#include "OtaCommandHandler.h"
#include "../RadioKitClass.h"

extern RadioKitClass RadioKit;

OtaCommandHandler& OtaCommandHandler::instance() {
    static OtaCommandHandler inst;
    return inst;
}

void OtaCommandHandler::handlePacket(uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) {
    RadioKit._onOtaPacket(cmd, payload, payloadLen);
}
