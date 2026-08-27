---
name: radiokit-relay
description: Guide for developing, deploying, and testing the RadioKit Rust relay server. This skill should be used when modifying the relay's WebSocket routing, Ed25519 authentication, stats server, rate limiter, Docker deployment, or integration tests in radiokit-relay/.
---

# RadioKit Relay Server

## Overview

The RadioKit relay is a Rust WebSocket server that routes binary frames between ESP32 devices and Flutter app clients over the internet. It uses Ed25519 challenge-response authentication and account-based scoping to pair devices with their owners.

## Architecture

```
ESP32 Device ──WebSocket──→ Relay (Rust) ──WebSocket──→ Flutter App
                              │
                              ├── main.rs        Connection handler + auth state machine
                              ├── relay.rs       Core routing: register, join, route_data
                              ├── session.rs     Data types: DeviceSession, ClientSession
                              ├── rate_limiter.rs Per-IP connection limits
                              └── relay_stats.rs  Live stats HTML + JSON API
```

## Build & Run

### Prerequisites

- Rust 1.85.0+ (rustc/cargo)

### Local Development

```bash
cd radiokit-relay

# Debug build + run
cargo run

# Release build
cargo run --release

# Using the convenience script (builds + runs, kills old instance)
./run.sh
./run.sh --release
./run.sh --port 4443 --stats 8080
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RADIOKIT_PORT` | `443` | WebSocket listen port |
| `RADIOKIT_STATS_PORT` | `8080` | Stats HTTP server port |
| `RADIOKIT_MAX_DEVICES_PER_IP` | `10` | Max device connections per IP |
| `RADIOKIT_MAX_CLIENTS_PER_IP` | `50` | Max client connections per IP |

## Docker Deployment

### Build Image

```bash
cd radiokit-relay
docker build -t radiokit-relay .
```

The Dockerfile uses a two-stage build:
1. **Build stage**: `rust:1.85-alpine` — compiles with musl for static linking
2. **Runtime stage**: `alpine:3.21` — minimal image with just the binary + CA certs

### Run Container

```bash
docker run -d --restart unless-stopped \
  -p 443:443 \
  -p 8080:8080 \
  -e RADIOKIT_STATS_PORT=8080 \
  --name radiokit-relay radiokit-relay
```

### Production Deployment

Use a reverse proxy (nginx/caddy) for TLS termination:

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

## Ed25519 Authentication

### Dependencies

```toml
ed25519-dalek = "2"
rand = "0.8"
base64 = "0.22"
hex = "0.4"
```

### Auth Flow

```
Client                          Relay
  │                               │
  ├── auth_request ──────────────→  { type: "auth_request", account: "<pubkey-hex>" }
  │                               │
  │←──── auth_challenge ──────────  { type: "auth_challenge", nonce_b64: "<base64-32-bytes>" }
  │                               │
  ├── auth_response ─────────────→  { type: "auth_response", signature_b64: "<base64-64-bytes>" }
  │   (sign(nonce, Ed25519))     │
  │                               │
  │←──── auth_ok ─────────────────  { type: "auth_ok" }
  │         or                    │
  │←──── auth_failed ─────────────  { type: "auth_failed" }
```

### Implementation in relay.rs

```rust
pub fn verify_auth(account: &str, nonce: &[u8], signature_b64: &str) -> bool {
    // 1. Decode hex account → 32-byte public key
    let pk_bytes = hex::decode(account).unwrap();
    let pk = ed25519_dalek::PublicKey::from_bytes(&pk_bytes).unwrap();

    // 2. Decode base64 signature → 64-byte signature
    let sig_bytes = base64::Engine::decode(
        &base64::engine::general_purpose::STANDARD, signature_b64
    ).unwrap();
    let sig = ed25519_dalek::Signature::from_bytes(&sig_bytes);

    // 3. Verify
    pk.verify_strict(nonce, &sig).is_ok()
}
```

### Account Identity

- The account is the **hex-encoded Ed25519 public key** (64 chars)
- The private key lives on the Flutter client (`CloudIdentityService` in `cloud_identity.dart`)
- Set `RadioKit.config.cloud_account` on the ESP32 to the same public key hex
- Devices register with the relay using this account as their identity

## Message Protocol

### Device Registration

```json
→ {"type": "register", "name": "WiFi_Cloud_Switch", "account": "<pubkey-hex>"}
← {"type": "registered", "ok": true, "sid": "a1b2c3d4"}
```

### Device Discovery

```json
→ {"type": "list_devices", "account": "<pubkey-hex>"}
← {"type": "device_list", "devices": ["WiFi_Cloud_Switch"]}
```

### Join Device

```json
→ {"type": "join", "device": "WiFi_Cloud_Switch", "account": "<pubkey-hex>"}
← {"type": "joined", "ok": true, "device": "WiFi_Cloud_Switch"}
```

Device receives:
```json
← {"type": "client_joined", "account": "...", "sid": "..."}
```

### Binary Data Routing

After joining, all binary frames are routed:
- **Device → Clients**: Broadcast to all linked client sessions
- **Client → Device**: Forward to the linked device session

### Heartbeat

```json
→ {"type": "ping", "ts": 1234567890}
← {"type": "pong", "ts": 1234567890}
```

## Testing

### Unit Tests

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

### Integration Tests

**Stats page test** — builds and starts the relay, verifies HTML page and JSON API:

```bash
bash tests/stats_integration_test.sh
```

**Auth flow test** — generates Ed25519 keypair, exercises full protocol:

```bash
bash tests/auth_flow_test.sh
```

**Python test helpers:**

| Script | Purpose |
|--------|---------|
| `tests/ws_client.py` | Single WebSocket operations (register, auth_join, raw) |
| `tests/ws_auth_flow_test.py` | Python test engine for auth flow |

### Full Stack Test (with Flutter App)

```bash
# Start relay
cd radiokit-relay && cargo run

# In another terminal, test via Flutter Remote Access API
curl -X POST http://127.0.0.1:7007/api/cloud/connect \
  -H 'Content-Type: application/json' \
  -d '{"host":"10.0.0.17","port":9000,"account":"<pubkey>","privateKey":"<privkey>"}'

curl -X POST http://127.0.0.1:7007/api/cloud/join \
  -H 'Content-Type: application/json' \
  -d '{"device":"WiFi_Cloud_Switch"}'
```

## Key Implementation Details

1. **Account scoping**: Devices and clients are paired by Ed25519 public key hex — only clients with the same account can discover and join a device
2. **Session deduplication**: Registering with the same `(name, account)` key replaces the old session
3. **Rate limiting**: Per-IP tracking rejects excess connections before auth
4. **Stats counters**: Atomic operations — no locks needed for the stats HTTP server
5. **No TLS termination**: The relay listens on plain WebSocket — use a reverse proxy for TLS in production
6. **Binary framing**: The relay passes binary frames through without inspection — it only examines JSON control messages

## ESP32 Firmware Setup

In the `RADIOKIT.h` config:

```cpp
RadioKit.config.cloud_url     = "wss://relay.example.com:443";
RadioKit.config.cloud_account = "<64-char-hex-public-key>";
RadioKit.startCloud();  // After startWiFi()
```

The device registers with the relay on boot using the public key as its identity.
