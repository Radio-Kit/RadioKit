# RadioKit Relay

WebSocket relay server for RadioKit's cloud transport. Routes binary frames between ESP32 devices and Flutter app clients over the internet, secured with Ed25519 challenge-response authentication.

## Overview

The relay acts as a signalling and data-forwarding bridge. Devices and clients connect via WebSocket, authenticate using Ed25519 signatures, and exchange RadioKit protocol frames through the relay.

```
┌──────────┐    WebSocket     ┌──────────────┐    WebSocket     ┌────────────┐
│  ESP32   │ ◄─────────────► │  RadioKit     │ ◄─────────────► │  Flutter    │
│  Device  │   text/binary   │  Relay        │   text/binary   │  App Client │
└──────────┘                 │  (port 443)   │                 └────────────┘
                             └──────────────┘
```

- **Devices** (ESP32): Register with the relay, receive commands from clients, send telemetry back.
- **Clients** (Flutter app): Authenticate with Ed25519, discover devices by account, join a device to send/receive frames.
- **Account scoping**: Devices and clients are paired by account (Ed25519 public key hex). Only clients authenticated for the same account can see and join a device.

## Architecture

```
src/
├── main.rs           # WebSocket server, connection handling, auth state machine
├── relay.rs          # Core routing: register, join, list_devices, route_data
├── session.rs        # Data types: DeviceSession, ClientSession, RelayMessage
└── rate_limiter.rs   # Per-IP connection limits for devices and clients
```

### main.rs — Connection handler

Each WebSocket connection is handled by an async task that:
1. Accepts the WebSocket handshake
2. Spawns a forward task (dispatches `RelayMessage` variants to correct WebSocket opcode)
3. Reads JSON control messages and binary frames in a loop
4. Manages auth state: nonce generation, challenge-response verification
5. Cleans up sessions on disconnect

### relay.rs — Core routing

- **`handle_register(name, account, tx)`**: Registers a device under `(name, account)`. Replaces existing sessions with the same key.
- **`handle_join(device_name, account, tx)`**: Joins a client to a registered device. Returns error if device not found.
- **`handle_list_devices(account)`**: Returns all device names registered for an account (auth-gated).
- **`route_data(data, key, is_device)`**: Forwards binary frames: device→clients or client→device.
- **`verify_auth(account, nonce, signature_b64)`**: Ed25519 signature verification against hex-encoded public key.

### session.rs — Data types

```rust
pub enum RelayMessage {
    Binary(Vec<u8>),    // RadioKit protocol frames (type-byte prefixed)
    Text(String),       // JSON control messages
}

pub struct DeviceSession { name, account, tx }
pub struct ClientSession { account, tx }
```

### rate_limiter.rs — Connection limits

Per-IP tracking of device and client connections:

| Env var | Default | Description |
|---------|---------|-------------|
| `RADIOKIT_MAX_DEVICES_PER_IP` | 10 | Max device connections per IP |
| `RADIOKIT_MAX_CLIENTS_PER_IP` | 50 | Max client connections per IP |

## Message Protocol

### Device registration

Device sends on connect:
```json
{"type": "register", "name": "WiFi_Cloud_Switch", "account": "<64-char-hex-public-key>"}
```

Relay responds:
```json
{"type": "registered", "ok": true, "sid": "a1b2c3d4"}
```

### Client auth flow

```
Client                     Relay
 │                          │
 ├── auth_request ──────────→  { type, account }
 │                          │
 │←─── auth_challenge ──────  { type, nonce: "<base64-32-bytes>" }
 │                          │
 ├── auth_response ─────────→  { type, account, signature: "<base64-64-bytes>" }
 │                          │
 │←─── auth_ok ─────────────  { type }
```


1. Client sends `auth_request` with the account (public key hex)
2. Relay generates a 32-byte random nonce, responds with `auth_challenge`
3. Client signs the nonce with the Ed25519 private key, sends `auth_response`
4. Relay verifies against the stored public key → `auth_ok` or `auth_failed`

### Device discovery

Authenticated client sends:
```json
{"type": "list_devices", "account": "<public-key-hex>"}
```

Response:
```json
{"type": "device_list", "devices": ["WiFi_Cloud_Switch"]}
```

### Join device

Client sends:
```json
{"type": "join", "device": "WiFi_Cloud_Switch", "account": "<public-key-hex>"}
```

Relay responds:
```json
{"type": "joined", "ok": true, "device": "WiFi_Cloud_Switch", "deviceName": "WiFi_Cloud_Switch"}
```

Device receives:
```json
{"type": "client_joined", "account": "...", "sid": "..."}
```

### Binary data routing

After joining, all binary frames are routed:
- **Device → Clients**: Broadcast to all linked client sessions
- **Client → Device**: Forward to the linked device session

### Heartbeat

```json
{"type": "ping", "ts": 1234567890}
{"type": "pong", "ts": 1234567890}
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIOKIT_PORT` | `443` | WebSocket listen port |
| `RADIOKIT_MAX_DEVICES_PER_IP` | `10` | Max device connections per IP |
| `RADIOKIT_MAX_CLIENTS_PER_IP` | `50` | Max client connections per IP |

## Running

### Local development

```bash
cd radiokit-relay
RADIOKIT_PORT=9000 cargo run --release
```

The relay listens on `0.0.0.0:9000`.

### Docker

```bash
cd radiokit-relay
docker build -t radiokit-relay .
docker run -d --restart unless-stopped -p 443:443 --name radiokit-relay radiokit-relay
```

The Dockerfile uses a two-stage build:
1. **Build stage**: `rust:1.85-alpine` — compiles the relay with musl for static linking
2. **Runtime stage**: `alpine:3.21` — minimal image with just the binary and CA certs

## Deployment

### Requirements

- Public IP or domain with open WebSocket port (default 443)
- TLS termination recommended for production (reverse proxy with nginx/caddy)

### Reverse proxy (nginx)

```nginx
server {
    listen 443 ssl;
    server_name relay.example.com;

    ssl_certificate /etc/letsencrypt/live/relay.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/relay.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

## Testing

Run the unit tests:

```bash
cd radiokit-relay
cargo test
```

Tests cover:
- Device registration and deduplication
- Client join, reject on missing device, reject on wrong account
- Binary data routing (device→client, client→device, multi-client broadcast)
- Device removal with client notification
- Full lifecycle integration

Full integration test with the Flutter app is documented in [llm-docs/AGENT-TEST.md](../llm-docs/AGENT-TEST.md).

## Client library

The Flutter app connects via `WebSocketService` (`radiokit-app/lib/services/websocket_service.dart`), which handles the auth state machine automatically. See [AGENTS.md section 20](../AGENTS.md) for implementation details.
