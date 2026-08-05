/**
 * TransportManager.h
 * Manages active RadioKitTransport instances and packet broadcasting.
 */

#ifndef RADIOKIT_TRANSPORT_MANAGER_H
#define RADIOKIT_TRANSPORT_MANAGER_H

#include <Arduino.h>
#include <stdint.h>
#include "../connection/RadioKitTransport.h"

#define MAX_RADIOKIT_TRANSPORTS 4

class TransportManager {
public:
    static TransportManager& instance();

    void registerTransport(RadioKitTransport* transport);
    void updateAll();
    void broadcastPacket(const uint8_t* buf, uint16_t len);
    bool isAnyConnected() const;
    int8_t getBestRssi() const;

private:
    TransportManager() : _count(0) {}
    RadioKitTransport* _transports[MAX_RADIOKIT_TRANSPORTS];
    uint8_t _count;
};

#endif // RADIOKIT_TRANSPORT_MANAGER_H
