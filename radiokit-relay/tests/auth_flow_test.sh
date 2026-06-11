#!/usr/bin/env bash
# ─── RadioKit Relay — Auth Flow Integration Test ────────────────
# Builds the relay, starts it on ephemeral ports, runs the Python
# Ed25519 auth flow test (register, auth, join, ping/pong, binary
# routing), then cleans up.
#
# Usage:
#   bash tests/auth_flow_test.sh
#   SKIP_BUILD=1 bash tests/auth_flow_test.sh
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

WS_PORT=18999
STATS_PORT=18998

cleanup() {
  if [ -n "${RELAY_PID:-}" ]; then
    kill "$RELAY_PID" 2>/dev/null || true
    wait "$RELAY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Build
if [ -z "${SKIP_BUILD:-}" ]; then
  echo "==> Building radiokit-relay..."
  cargo build -q 2>&1
fi
BINARY="target/debug/radiokit-relay"
if [ ! -x "$BINARY" ]; then
  echo "ERROR: Binary not found at $BINARY"
  exit 1
fi

# Start relay
echo "==> Starting relay (WS :$WS_PORT, Stats :$STATS_PORT)..."
RADIOKIT_PORT=$WS_PORT RADIOKIT_STATS_PORT=$STATS_PORT "$BINARY" &
RELAY_PID=$!

# Wait for ready
for i in $(seq 1 10); do
  if curl -sf "http://127.0.0.1:$STATS_PORT/" > /dev/null 2>&1; then
    echo "     Ready after ${i}s"
    break
  fi
  if [ "$i" -eq 10 ]; then
    echo "ERROR: Relay did not start within 10s"
    exit 1
  fi
  sleep 1
done

# Run the Python auth flow test
echo ""
python3 "$SCRIPT_DIR/tests/ws_auth_flow_test.py" \
  --host 127.0.0.1 --port "$WS_PORT" --stats-port "$STATS_PORT"
EXIT_CODE=$?

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "==> Auth flow test PASSED"
else
  echo "==> Auth flow test FAILED (exit code $EXIT_CODE)"
fi

exit "$EXIT_CODE"
