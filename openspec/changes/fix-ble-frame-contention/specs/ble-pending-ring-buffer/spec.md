# ble-pending-ring-buffer Specification

## ADDED Requirements

### Requirement: Multi-slot pending frame queue
`RadioKitBLE::sendPacket()` SHALL use an 8-slot ring buffer for pending frames instead of a single-slot buffer. When `sendPacket()` is re-entered during an in-progress send (e.g., an incoming BLE write triggers an ACK), the outgoing frame SHALL be enqueued to the next free ring slot instead of overwriting the previous pending frame. If the ring buffer is full, the frame SHALL be dropped and the drop counter incremented.

#### Scenario: Single re-entrant call during send
- **WHEN** `sendPacket()` is called re-entrantly once during an in-progress send
- **THEN** the re-entrant frame is queued in the ring buffer and delivered after the current send completes

#### Scenario: Multiple re-entrant calls during send
- **WHEN** `sendPacket()` is called re-entrantly 3 times during an in-progress send
- **THEN** all 3 frames are queued in separate ring slots and delivered in FIFO order after the current send completes

#### Scenario: Ring buffer full
- **WHEN** `sendPacket()` is called re-entrantly and all 8 ring slots are occupied
- **THEN** the frame is dropped, the drop counter is incremented, and the function returns without error

### Requirement: FIFO delivery of pending frames
After `sendPacket()` completes its current send, it SHALL drain all pending frames from the ring buffer in FIFO order via a loop (not recursion) to avoid stack overflow. Each pending frame SHALL be sent as a complete `sendPacket()` call.

#### Scenario: Pending frames delivered in order
- **WHEN** the ring buffer contains frames A, B, C (in insertion order)
- **THEN** frame A is sent first, then B, then C, with each completing before the next begins

#### Scenario: No stack overflow on drain
- **WHEN** 8 pending frames are drained from the ring buffer
- **THEN** the drain loop iterates without recursive `sendPacket()` calls, keeping stack usage bounded
