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
├── rate_limiter.rs   # Per-IP connection limits for devices and clients
└── relay_stats.rs    # Live stats page (HTML + JSON API)
```

### main.rs — Connection handler & Stats HTTP server

Each WebSocket connection is handled by an async task that:
1. Accepts the WebSocket handshake
2. Spawns a forward task (dispatches `RelayMessage` variants to correct WebSocket opcode)
3. Reads JSON control messages and binary frames in a loop
4. Manages auth state: nonce generation, challenge-response verification
5. Tracks statistics via atomic counters (devices, clients, bytes, auths, rate limits)
6. Cleans up sessions on disconnect, decrementing stats counters

A separate **stats HTTP server** runs on `RADIOKIT_STATS_PORT` (default 8080):
- `GET /` → Live-updating HTML page (auto-refreshes every second via JS)
- `GET /api` → JSON snapshot of all counters for programmatic access

The stats page has zero external dependencies — the HTTP server is built on raw `tokio::net::TcpListener` and parses the HTTP request manually.

### relay.rs — Core routing

- **`handle_register(name, account, tx)`**: Registers a device under `(name, account)`. Replaces existing sessions with the same key.
- **`handle_join(device_name, account, tx)`**: Joins a client to a registered device. Returns error if device not found.
- **`handle_list_devices(account)`**: Returns all device names registered for an account (auth-gated).
- **`route_data(data, key, is_device)`**: Forwards binary frames: device→clients or client→device.
- **`verify_auth(account, nonce, signature_b64)`**: Ed25519 signature verification against hex-encoded public key.
- **`is_new_account(account)`**: Checks whether any device is registered under this account (used for account counting).
- **`all_device_names()`**: Returns all registered device names across all accounts (used by the stats page).

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

### relay_stats.rs — Live statistics

Exposes a lightweight HTTP server with real-time relay metrics via atomic counters:

| Counter | Type | Description |
|---------|------|-------------|
| `total_bytes_routed` | `AtomicU64` | Total bytes forwarded across all connections |
| `total_messages_routed` | `AtomicU64` | Total binary messages routed |
| `current_devices` | `AtomicUsize` | Currently connected devices |
| `current_clients` | `AtomicUsize` | Currently connected clients |
| `current_connections` | `AtomicUsize` | Total active WebSocket connections |
| `current_accounts` | `AtomicUsize` | Accounts with at least one registered device |
| `total_accounts` | `AtomicU64` | Unique accounts seen (all time) |
| `failed_auths` | `AtomicU64` | Failed Ed25519 auth attempts |
| `rate_limits_hit` | `AtomicU64` | Connections rejected due to per-IP limits |

The HTML page renders them in a minimal, auto-refreshing layout.

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
| `RADIOKIT_STATS_PORT` | `8080` | Stats HTTP server port (HTML page + JSON API) |
| `RADIOKIT_MAX_DEVICES_PER_IP` | `10` | Max device connections per IP |
| `RADIOKIT_MAX_CLIENTS_PER_IP` | `50` | Max client connections per IP |

## Running

### Local development

```bash
cd radiokit-relay

# Use the convenience script:
./run.sh

# Or run directly:
RADIOKIT_PORT=9000 RADIOKIT_STATS_PORT=8080 cargo run --release
```

The relay listens on `0.0.0.0:<RADIOKIT_PORT>` (default 443).

Open the stats dashboard at **http://localhost:8080/** — a live-updating page showing traffic, connections, accounts, and errors.

### Docker

```bash
cd radiokit-relay
docker build -t radiokit-relay .
docker run -d --restart unless-stopped \
  -p 443:443 \
  -p 8080:8080 \
  -e RADIOKIT_STATS_PORT=8080 \
  --name radiokit-relay radiokit-relay
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

### Unit tests

```bash
cd radiokit-relay
cargo test
```

17 tests covering:
- Device registration and deduplication
- Client join, reject on missing device, reject on wrong account
- Binary data routing (device→client, client→device, multi-client broadcast)
- Device removal with client notification
- Full lifecycle integration

### Integration tests

**Stats page test** — builds and starts the relay, verifies the HTML page and JSON API render correctly, then tests WebSocket device registration with live stats updates.

```bash
bash tests/stats_integration_test.sh
```

**Auth flow test** — generates an Ed25519 keypair and exercises the full protocol:
1. Device registers with public key as account
2. Client authenticates via challenge-response (sign nonce with private key)
3. Client discovers and joins the device
4. Ping/pong heartbeat from both peers
5. Binary frame routing from device to client
6. Clean disconnect, stats counters decrement

```bash
bash tests/auth_flow_test.sh
```

Helpful test scripts:

| Script | Purpose |
|--------|---------|
| `tests/stats_integration_test.sh` | 37 assertions — HTML page, JSON API, WS register, stats cleanup |
| `tests/auth_flow_test.sh` | 20 assertions — full Ed25519 auth flow, binary routing, ping/pong |
| `tests/ws_client.py` | Python helper for single WebSocket operations (register, auth_join, raw) |
| `tests/ws_auth_flow_test.py` | Python test engine for the auth flow test |

Full integration test with the Flutter app is documented in [llm-docs/AGENT-TEST.md](../llm-docs/AGENT-TEST.md).

## Client library

The Flutter app connects via `WebSocketService` (`radiokit-app/lib/services/websocket_service.dart`), which handles the auth state machine automatically. See [AGENTS.md section 20](../AGENTS.md) for implementation details.
