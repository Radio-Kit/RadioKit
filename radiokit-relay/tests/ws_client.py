#!/usr/bin/env python3
"""
RadioKit Relay — WebSocket Test Client

Connects to the relay over WebSocket, sends a JSON control message,
prints the response to stdout, and keeps the connection alive for
--timeout seconds before disconnecting cleanly.

Usage examples:
  # Register a device, keep alive 5s
  python3 ws_client.py --port 19999 register --name test_device --timeout 5

  # Keep alive 2s (default timeout is 3s)
  python3 ws_client.py --port 19999 register --name dev
"""
import argparse
import asyncio
import json
import sys

try:
    import websockets
except ImportError:
    print(json.dumps({"error": "websockets library not installed"}))
    sys.exit(1)


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=9000)
    parser.add_argument("--timeout", type=int, default=3,
                        help="Keep alive for N seconds, then disconnect")
    parser.add_argument("action", choices=["register", "auth_join", "raw"])
    parser.add_argument("--name", default="test_device")
    parser.add_argument("--account", default="test_account")
    parser.add_argument("--send", type=str, default=None,
                        help="Raw JSON message to send (for 'raw' action)")
    args = parser.parse_args()

    uri = f"ws://{args.host}:{args.port}"

    try:
        async with websockets.connect(uri, ping_interval=None) as ws:
            if args.action == "register":
                msg = json.dumps({
                    "type": "register",
                    "name": args.name,
                    "account": args.account,
                })
                await ws.send(msg)
                resp = await asyncio.wait_for(ws.recv(), timeout=5)
                print(json.dumps(json.loads(resp)))
                sys.stdout.flush()

            elif args.action == "auth_join":
                account = args.account
                # Step 1: auth_request
                await ws.send(json.dumps({
                    "type": "auth_request", "account": account,
                }))
                challenge = json.loads(
                    await asyncio.wait_for(ws.recv(), timeout=5))
                print(json.dumps(challenge))
                sys.stdout.flush()

                # Step 2: dummy auth_response (will be rejected)
                await ws.send(json.dumps({
                    "type": "auth_response",
                    "account": account,
                    "signature": "AAAA" * 16,
                }))
                auth_resp = json.loads(
                    await asyncio.wait_for(ws.recv(), timeout=5))
                print(json.dumps(auth_resp))
                sys.stdout.flush()

            elif args.action == "raw" and args.send:
                await ws.send(args.send)
                try:
                    resp = await asyncio.wait_for(ws.recv(), timeout=3)
                    print(json.dumps(json.loads(resp)))
                except asyncio.TimeoutError:
                    print(json.dumps({"type": "no_response"}))
                sys.stdout.flush()

            # Keep alive for the specified timeout, then disconnect cleanly
            await asyncio.sleep(args.timeout)

    except (asyncio.TimeoutError, websockets.ConnectionClosed) as e:
        print(json.dumps({"error": str(e), "type": "connection_closed"}))
        sys.stdout.flush()
    except OSError as e:
        print(json.dumps({"error": f"Connection refused: {e}"}))
        sys.stdout.flush()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
