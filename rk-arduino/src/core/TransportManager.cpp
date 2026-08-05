/**
 * TransportManager.cpp
 * Implementation of multi-transport registration and packet broadcasting.
 */

#include "TransportManager.h"

TransportManager& TransportManager::instance() {
    static TransportManager inst;
    return inst;
}

void TransportManager::registerTransport(RadioKitTransport* transport) {
    if (!transport) return;
    for (uint8_t i = 0; i < _count; i++) {
        if (_transports[i] == transport) return;
    }
    if (_count < MAX_RADIOKIT_TRANSPORTS) {
        _transports[_count++] = transport;
    }
}

void TransportManager::updateAll() {
    for (uint8_t i = 0; i < _count; i++) {
        if (_transports[i]) {
            _transports[i]->update();
        }
    }
}

void TransportManager::broadcastPacket(const uint8_t* buf, uint16_t len) {
    if (!buf || len == 0) return;
    for (uint8_t i = 0; i < _count; i++) {
        if (_transports[i] && _transports[i]->isConnected()) {
            _transports[i]->sendPacket(buf, len);
        }
    }
}

bool TransportManager::isAnyConnected() const {
    for (uint8_t i = 0; i < _count; i++) {
        if (_transports[i] && _transports[i]->isConnected()) {
            return true;
        }
    }
    return false;
}

int8_t TransportManager::getBestRssi() const {
    int8_t best = -127;
    for (uint8_t i = 0; i < _count; i++) {
        if (_transports[i] && _transports[i]->isConnected()) {
            int8_t r = _transports[i]->getRssi();
            if (r > best) best = r;
        }
    }
    return best == -127 ? 0 : best;
}
