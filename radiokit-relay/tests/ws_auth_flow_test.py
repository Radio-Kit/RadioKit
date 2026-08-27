#!/usr/bin/env python3
"""
RadioKit Relay — WebSocket Auth Flow Integration Test

Exercises the full Ed25519 challenge-response auth flow:
  1. Generate Ed25519 keypair
  2. Device: register with public key as account
  3. Client: auth_request -> auth_challenge -> sign nonce -> auth_response -> auth_ok
  4. Client: list_devices (verify device visible)
  5. Client: join device
  6. Client + Device: ping/pong heartbeat
  7. Device -> Client: binary frame routing
  8. Clean disconnect, verify stats counters via JSON API

Usage:
  python3 tests/ws_auth_flow_test.py [--host 127.0.0.1] [--port 19999] [--stats-port 19998]
"""
import argparse
import asyncio
import base64
import json
import signal
import sys
import time
import urllib.request

try:
    import websockets
except ImportError:
    print("ERROR: 'websockets' library not installed")
    sys.exit(1)

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
except ImportError:
    print("ERROR: 'cryptography' library not installed")
    sys.exit(1)


PASS = 0
FAIL = 0


def ok(msg):
    global PASS
    PASS += 1
    print(f"  PASS: {msg}")


def nok(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL: {msg}")


def json_get(url):
    """Fetch a JSON response from the stats endpoint."""
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        return {"error": str(e)}


async def recv_json(ws, timeout=5):
    """Receive a WebSocket message and parse as JSON (text frame)."""
    raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
    if isinstance(raw, bytes):
        raise TypeError(f"Expected text frame, got binary ({len(raw)} bytes)")
    return json.loads(raw)


async def recv_binary(ws, timeout=5):
    """Receive a WebSocket binary frame."""
    raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
    if isinstance(raw, str):
        raise TypeError(f"Expected binary frame, got text: {raw[:50]}")
    return raw


async def test_auth_flow(host, port, stats_port):
    global PASS, FAIL
    ws_url = f"ws://{host}:{port}"
    stats_url = f"http://{host}:{stats_port}/api"

    # ─── 0. Verify relay is running ─────────────────────────────
    stats = json_get(stats_url)
    if "error" in stats:
        nok(f"Relay not reachable: {stats['error']}")
        return False
    ok(f"Relay reachable on ws://{host}:{port}")

    # ─── 1. Generate Ed25519 keypair ────────────────────────────
    private_key = Ed25519PrivateKey.generate()
    public_key = private_key.public_key()
    pubkey_hex = public_key.public_bytes(Encoding.Raw, PublicFormat.Raw).hex()
    ok(f"Generated Ed25519 keypair (pubkey: {pubkey_hex[:16]}...)")

    # ─── 2. Device: register ────────────────────────────────────
    print("\n  -- Device Registration --")
    device_ws = await websockets.connect(ws_url, ping_interval=None)

    await device_ws.send(json.dumps({
        "type": "register",
        "name": "auth_test_device",
        "account": pubkey_hex,
    }))
    reg_resp = await recv_json(device_ws)

    if reg_resp.get("type") == "registered" and reg_resp.get("ok") is True:
        ok("Device: registered (type=registered, ok=true)")
    else:
        nok(f"Device: registration failed: {json.dumps(reg_resp)[:100]}")
        await device_ws.close()
        return False

    await asyncio.sleep(0.5)
    stats = json_get(stats_url)
    if stats.get("current_devices") == 1:
        ok("Stats: current_devices = 1")
    else:
        nok(f"Stats: current_devices = {stats.get('current_devices')} (expected 1)")

    # ─── 3. Client: Ed25519 auth flow ────────────────────────────
    print("\n  -- Client Auth Flow --")
    client_ws = await websockets.connect(ws_url, ping_interval=None)

    # 3a: auth_request
    await client_ws.send(json.dumps({
        "type": "auth_request",
        "account": pubkey_hex,
    }))
    challenge = await recv_json(client_ws)

    if challenge.get("type") == "auth_challenge" and "nonce" in challenge:
        ok("Client: received auth_challenge with nonce")
    else:
        nok(f"Client: expected auth_challenge, got: {json.dumps(challenge)[:100]}")
        await device_ws.close()
        await client_ws.close()
        return False

    # 3b: decode nonce, sign with Ed25519 private key
    nonce_bytes = base64.b64decode(challenge["nonce"])
    if len(nonce_bytes) != 32:
        nok(f"Nonce is {len(nonce_bytes)} bytes (expected 32)")
        await device_ws.close()
        await client_ws.close()
        return False

    signature = private_key.sign(nonce_bytes)
    sig_b64 = base64.b64encode(signature).decode()
    ok(f"Client: signed {len(nonce_bytes)}-byte nonce")

    # 3c: auth_response
    await client_ws.send(json.dumps({
        "type": "auth_response",
        "account": pubkey_hex,
        "signature": sig_b64,
    }))
    auth_resp = await recv_json(client_ws)

    if auth_resp.get("type") == "auth_ok":
        ok("Client: auth succeeded (type=auth_ok)")
    else:
        nok(f"Client: expected auth_ok, got: {json.dumps(auth_resp)[:100]}")
        await device_ws.close()
        await client_ws.close()
        return False

    # ─── 4. Client: list_devices ────────────────────────────────
    print("\n  -- Device Discovery --")
    await client_ws.send(json.dumps({
        "type": "list_devices",
        "account": pubkey_hex,
    }))
    list_resp = await recv_json(client_ws)

    if (list_resp.get("type") == "device_list"
            and isinstance(list_resp.get("devices"), list)
            and "auth_test_device" in list_resp["devices"]):
        ok("Client: list_devices returned ['auth_test_device']")
    else:
        nok(f"Client: list_devices unexpected: {json.dumps(list_resp)[:120]}")

    # ─── 5. Client: join device ──────────────────────────────────
    print("\n  -- Join Device --")
    await client_ws.send(json.dumps({
        "type": "join",
        "device": "auth_test_device",
        "account": pubkey_hex,
    }))
    join_resp = await recv_json(client_ws)

    if join_resp.get("type") == "joined" and join_resp.get("ok") is True:
        ok("Client: joined device (type=joined, ok=true)")
    else:
        nok(f"Client: join failed: {json.dumps(join_resp)[:100]}")

    # Device should receive client_joined notification
    device_notif = await recv_json(device_ws)
    if device_notif.get("type") == "client_joined":
        ok("Device: received client_joined notification")
    else:
        nok(f"Device: expected client_joined, got: {json.dumps(device_notif)[:100]}")

    await asyncio.sleep(0.5)
    stats = json_get(stats_url)
    if stats.get("current_clients") == 1:
        ok("Stats: current_clients = 1")
    else:
        nok(f"Stats: current_clients = {stats.get('current_clients')} (expected 1)")

    # ─── 6. Ping/Pong ────────────────────────────────────────────
    print("\n  -- Heartbeat (Ping/Pong) --")
    ts = int(time.time() * 1000)

    await client_ws.send(json.dumps({"type": "ping", "ts": ts}))
    pong = await recv_json(client_ws)
    if pong.get("type") == "pong" and pong.get("ts") == ts:
        ok("Client: ping/pong round-trip (ts matched)")
    else:
        nok(f"Client: ping/pong failed: {json.dumps(pong)[:100]}")

    ts2 = int(time.time() * 1000)
    await device_ws.send(json.dumps({"type": "ping", "ts": ts2}))
    pong2 = await recv_json(device_ws)
    if pong2.get("type") == "pong" and pong2.get("ts") == ts2:
        ok("Device: ping/pong round-trip (ts matched)")
    else:
        nok(f"Device: ping/pong failed: {json.dumps(pong2)[:100]}")

    # ─── 7. Binary routing: Device -> Client ─────────────────────
    print("\n  -- Binary Data Routing --")
    test_frame = bytes([0x55, 0x01, 0x02, 0x03, 0xAA, 0xBB])

    await device_ws.send(test_frame)
    ok(f"Device: sent {len(test_frame)}-byte binary frame")

    client_received = await recv_binary(client_ws, timeout=3)
    if client_received == test_frame:
        ok("Client: received matching binary frame from device")
    else:
        nok(f"Client: binary frame mismatch (got {len(client_received)} bytes, expected {len(test_frame)})")

    # Check stats for bytes/messages routed
    await asyncio.sleep(0.5)
    stats = json_get(stats_url)
    if stats.get("total_bytes_routed", 0) >= len(test_frame):
        ok(f"Stats: total_bytes_routed ({stats['total_bytes_routed']}) >= {len(test_frame)}")
    else:
        nok(f"Stats: total_bytes_routed = {stats.get('total_bytes_routed')} (expected >= {len(test_frame)})")
    if stats.get("total_messages_routed", 0) >= 1:
        ok(f"Stats: total_messages_routed = {stats['total_messages_routed']} (>= 1)")
    else:
        nok(f"Stats: total_messages_routed = {stats.get('total_messages_routed')} (expected >= 1)")

    # ─── 8. Disconnect and verify cleanup ────────────────────────
    print("\n  -- Cleanup --")
    await device_ws.close()
    await client_ws.close()
    await asyncio.sleep(2)

    stats = json_get(stats_url)
    checks = [
        ("current_devices", 0),
        ("current_clients", 0),
        ("current_connections", 0),
    ]
    all_clean = True
    for key, expected in checks:
        val = stats.get(key)
        if val == expected:
            ok(f"Stats: {key} = {expected} (cleaned up)")
        else:
            nok(f"Stats: {key} = {val} (expected {expected})")
            all_clean = False



    return all_clean


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=19999)
    parser.add_argument("--stats-port", type=int, default=19998)
    args = parser.parse_args()

    print("RadioKit Relay -- WebSocket Auth Flow Integration Test")
    print("=" * 60)
    print(f"  WS:   {args.host}:{args.port}")
    print(f"  API:  http://{args.host}:{args.stats_port}/api")
    print("=" * 60)

    success = await test_auth_flow(args.host, args.port, args.stats_port)

    print()
    print("=" * 60)
    print(f"  Results: {PASS} passed, {FAIL} failed")
    print("=" * 60)

    return 0 if success and FAIL == 0 else 1


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(asyncio.run(main()))
