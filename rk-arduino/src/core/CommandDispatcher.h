/**
 * CommandDispatcher.h
 * Router for incoming binary protocol frames based on header byte.
 */

#ifndef RADIOKIT_COMMAND_DISPATCHER_H
#define RADIOKIT_COMMAND_DISPATCHER_H

#include <Arduino.h>
#include <stdint.h>
#include "ICommandHandler.h"

#define MAX_COMMAND_HANDLERS 8

class CommandDispatcher {
public:
    static CommandDispatcher& instance();

    void registerHandler(ICommandHandler* handler);
    void dispatch(uint8_t headerByte, uint8_t cmd, const uint8_t* payload, uint16_t payloadLen, uint8_t sourceTransport = 0);

private:
    CommandDispatcher() : _count(0) {}
    ICommandHandler* _handlers[MAX_COMMAND_HANDLERS];
    uint8_t _count;
};

#endif // RADIOKIT_COMMAND_DISPATCHER_H
