#!/usr/bin/env bash
# ─── RadioKit Relay — Stats Integration Test ──────────────────────
# Builds the relay, starts it on ephemeral ports, curls the HTML page
# and JSON API, validates response contents, then cleans up.
#
# Usage:
#   bash tests/stats_integration_test.sh
#   SKIP_BUILD=1 bash tests/stats_integration_test.sh  # reuse existing binary
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# ─── Ports ────────────────────────────────────────────────────────
WS_PORT=19999
STATS_PORT=19998
BASE_URL="http://127.0.0.1:$STATS_PORT"
PASS=0
FAIL=0

# ─── Helper ───────────────────────────────────────────────────────
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

cleanup() {
  if [ -n "${RELAY_PID:-}" ]; then
    kill "$RELAY_PID" 2>/dev/null || true
    wait "$RELAY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# ─── Build ────────────────────────────────────────────────────────
if [ -z "${SKIP_BUILD:-}" ]; then
  echo "==> Building radiokit-relay..."
  cargo build -q 2>&1
fi
BINARY="target/debug/radiokit-relay"

if [ ! -x "$BINARY" ]; then
  echo "ERROR: Binary not found at $BINARY. Run without SKIP_BUILD or build first."
  exit 1
fi

# ─── Start relay ──────────────────────────────────────────────────
echo "==> Starting relay (WS :$WS_PORT, Stats :$STATS_PORT)..."
RADIOKIT_PORT=$WS_PORT RADIOKIT_STATS_PORT=$STATS_PORT "$BINARY" &
RELAY_PID=$!

# ─── Wait for ready ──────────────────────────────────────────────
echo "==> Waiting for stats endpoint..."
for i in $(seq 1 10); do
  if curl -sf "$BASE_URL/" > /dev/null 2>&1; then
    echo "     Ready after ${i}s"
    break
  fi
  if [ "$i" -eq 10 ]; then
    echo "ERROR: Relay did not start within 10s"
    exit 1
  fi
  sleep 1
done

echo ""
echo "───────────────────────────────────────────────────────────────"
echo "  Test: HTML page"
echo "───────────────────────────────────────────────────────────────"

HTML=$(curl -sf "$BASE_URL/" 2>&1)

# Page title
if echo "$HTML" | grep -q '<title>RadioKit Relay</title>'; then
  pass "Title is 'RadioKit Relay'"
else
  fail "Title missing or wrong"
fi

# H1 heading
if echo "$HTML" | grep -q '<h1>RadioKit Relay</h1>'; then
  pass "H1 heading present"
else
  fail "H1 heading missing"
fi

# Status line
if echo "$HTML" | grep -q 'relayed'; then
  pass "Status line present (contains 'relayed')"
else
  fail "Status line missing"
fi

# Section headings
for section in Connections Traffic Accounts Errors; do
  if echo "$HTML" | grep -q "<h2>$section</h2>"; then
    pass "Section '$section' present"
  else
    fail "Section '$section' missing"
  fi
done

# Table row labels
for label in "Bytes routed" "Messages routed" \
             "Current devices" "Current clients" "Current connections" \
             "Active accounts" "Total accounts (all time)" \
             "Failed auths" "Rate limits hit"; do
  if echo "$HTML" | grep -q "<td>$label</td>"; then
    pass "Row label '$label' present"
  else
    fail "Row label '$label' missing"
  fi
done

# Auto-refresh JS present
if echo "$HTML" | grep -q 'setInterval'; then
  pass "Auto-refresh JavaScript present"
else
  fail "Auto-refresh JavaScript missing"
fi

# All numeric values should be 0 (fresh relay)
NON_ZERO=$(echo "$HTML" | grep -oE '<td>[1-9][0-9]*</td>' || true)
if [ -z "$NON_ZERO" ]; then
  pass "All numeric values are 0 (default state)"
else
  fail "Non-zero values found: $(echo "$NON_ZERO" | tr '\n' ' ')"
fi

# Content-Type header
CONTENT_TYPE=$(curl -sI "$BASE_URL/" | grep -i 'content-type' | tr -d '\r\n')
if echo "$CONTENT_TYPE" | grep -qi 'text/html'; then
  pass "Content-Type is text/html"
else
  fail "Content-Type is not text/html: $CONTENT_TYPE"
fi

echo ""
echo "───────────────────────────────────────────────────────────────"
echo "  Test: JSON API"
echo "───────────────────────────────────────────────────────────────"

JSON=$(curl -sf "$BASE_URL/api" 2>&1)

if echo "$JSON" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  pass "Valid JSON"
else
  fail "Invalid JSON: $(echo "$JSON" | head -c 100)"
fi

# Check all expected keys exist
for key in total_bytes_routed total_messages_routed \
           current_devices current_clients current_connections \
           current_accounts total_accounts \
           failed_auths rate_limits_hit; do
  if echo "$JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); assert '$key' in d, 'Missing $key'" 2>/dev/null; then
    pass "JSON key '$key' present"
  else
    fail "JSON key '$key' missing"
  fi
done

# All integer values should be 0
NON_ZERO=$(echo "$JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
non_zero = {k: v for k, v in d.items() if isinstance(v, int) and v != 0}
if non_zero:
  print(non_zero)
" 2>/dev/null)
if [ -z "$NON_ZERO" ]; then
  pass "All JSON integer values are 0 (default state)"
else
  fail "Non-zero values found: $NON_ZERO"
fi

# Verify no uptime keys
if echo "$JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
assert 'uptime' not in d, 'uptime should not be present'
assert 'uptime_secs' not in d, 'uptime_secs should not be present'
print('ok')
" 2>/dev/null; then
  pass "No uptime fields in JSON"
else
  fail "Uptime fields found in JSON (should have been removed)"
fi

# Content-Type header
JSON_CT=$(curl -sI "$BASE_URL/api" | grep -i 'content-type' | tr -d '\r\n')
if echo "$JSON_CT" | grep -qi 'application/json'; then
  pass "Content-Type is application/json"
else
  fail "Content-Type is not application/json: $JSON_CT"
fi

echo ""
echo "───────────────────────────────────────────────────────────────"
echo "  Test: WebSocket device registration (stats update)"
echo "───────────────────────────────────────────────────────────────"

WS_CLIENT="python3 $SCRIPT_DIR/tests/ws_client.py --host 127.0.0.1 --port $WS_PORT"

# ─── Register a device ────────────────────────────────────────────
echo "     Connecting device via WebSocket..."

# Start WS client in background, capture response via a temp file
WS_RESP=$(mktemp /tmp/rk_ws_resp.XXXXXX)

$WS_CLIENT register --name test_device --account acct_one --timeout 4 > "$WS_RESP" 2>&1 &
WS_PID=$!

# Wait for the response to appear (poll up to 3s)
for i in $(seq 1 6); do
  if [ -s "$WS_RESP" ]; then
    REG_RESP=$(cat "$WS_RESP")
    if echo "$REG_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok')==True, 'not ok'" 2>/dev/null; then
      pass "Device registered successfully (ok=true)"
    else
      fail "Registration response unexpected: $(echo "$REG_RESP" | tr '\n' ' ' | head -c 120)"
    fi
    break
  fi
  if [ "$i" -eq 6 ]; then
    fail "No registration response received after 3s"
  fi
  sleep 0.5
done

# ─── Check stats: device connected ───────────────────────────────
sleep 1
JSON_AFTER=$(curl -sf "$BASE_URL/api" 2>&1)

CUR_DEV=$(echo "$JSON_AFTER" | python3 -c "import json,sys; print(json.load(sys.stdin)['current_devices'])" 2>/dev/null || echo "err")
if [ "$CUR_DEV" = "1" ]; then
  pass "current_devices = 1 (device connected)"
else
  fail "current_devices = $CUR_DEV (expected 1)"
fi

CUR_CONN=$(echo "$JSON_AFTER" | python3 -c "import json,sys; print(json.load(sys.stdin)['current_connections'])" 2>/dev/null || echo "err")
if [ "$CUR_CONN" = "1" ]; then
  pass "current_connections = 1 (one WS connection)"
else
  fail "current_connections = $CUR_CONN (expected 1)"
fi

# ─── Wait for device to disconnect (timeout expires) ─────────────
echo "     Waiting for device disconnect (timeout)..."
# Kill the WS client to force disconnect early (SIGTERM)
kill "$WS_PID" 2>/dev/null || true
wait "$WS_PID" 2>/dev/null || true
rm -f "$WS_RESP"
sleep 2  # wait for relay cleanup

# ─── Check stats: device disconnected ────────────────────────────
JSON_AFTER_DISCONNECT=$(curl -sf "$BASE_URL/api" 2>&1)

CUR_DEV=$(echo "$JSON_AFTER_DISCONNECT" | python3 -c "import json,sys; print(json.load(sys.stdin)['current_devices'])" 2>/dev/null || echo "err")
if [ "$CUR_DEV" = "0" ]; then
  pass "current_devices = 0 after disconnect"
else
  fail "current_devices = $CUR_DEV after disconnect (expected 0)"
fi

CUR_CONN=$(echo "$JSON_AFTER_DISCONNECT" | python3 -c "import json,sys; print(json.load(sys.stdin)['current_connections'])" 2>/dev/null || echo "err")
if [ "$CUR_CONN" = "0" ]; then
  pass "current_connections = 0 after disconnect"
else
  fail "current_connections = $CUR_CONN after disconnect (expected 0)"
fi



echo ""
echo "───────────────────────────────────────────────────────────────"
echo "  Results: $PASS passed, $FAIL failed"
echo "───────────────────────────────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
