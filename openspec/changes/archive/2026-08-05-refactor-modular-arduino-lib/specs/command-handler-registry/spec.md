## ADDED Requirements

### Requirement: Modular Command Handler Registration
The library SHALL dispatch incoming binary protocol frames to registered `ICommandHandler` implementations based on frame header bytes.

#### Scenario: Processing an incoming control packet
- **WHEN** a `0x55` frame header packet is received by the packet dispatcher
- **THEN** it routes the packet directly to `ControlCommandHandler::handlePacket()`.

#### Scenario: Processing an incoming filesystem packet
- **WHEN** a `0xAA` bulk filesystem packet is received
- **THEN** it routes the payload to `FsCommandHandler::handlePacket()` without triggering control widget handlers.
