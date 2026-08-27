/**
 * CommandDispatcher.cpp
 * Implementation of frame header command routing.
 */

#include "CommandDispatcher.h"

CommandDispatcher& CommandDispatcher::instance() {
    static CommandDispatcher inst;
    return inst;
}

void CommandDispatcher::registerHandler(ICommandHandler* handler) {
    if (!handler) return;
    for (uint8_t i = 0; i < _count; i++) {
        if (_handlers[i] == handler || _handlers[i]->getHeaderByte() == handler->getHeaderByte()) {
            _handlers[i] = handler;
            return;
        }
    }
    if (_count < MAX_COMMAND_HANDLERS) {
        _handlers[_count++] = handler;
    }
}

void CommandDispatcher::dispatch(uint8_t headerByte, uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport) {
    for (uint8_t i = 0; i < _count; i++) {
        if (_handlers[i] && _handlers[i]->getHeaderByte() == headerByte) {
            _handlers[i]->handlePacket(cmd, payload, payloadLen, sourceTransport);
            return;
        }
    }
}
