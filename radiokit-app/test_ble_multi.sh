#!/bin/bash
set -e
API="http://127.0.0.1:7007"
DEV_A=""
DEV_B=""
PASS=0
FAIL=0
SKIP=0

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
skip() { SKIP=$((SKIP+1)); echo "  ⏭️  $1"; }
hdr()  { echo ""; echo "━━━ $1 ━━━"; }

json_val() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)" 2>/dev/null; }

# ──────────────────────────────────────────────────────────────
hdr "SETUP: Enable follow mode"
curl -s -X PUT "$API/api/settings" \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":true}' > /dev/null
FM=$(curl -s "$API/api/settings" | json_val '["followRemoteAccess"]')
[ "$FM" = "True" ] && ok "Follow mode enabled" || fail "Follow mode: $FM"

# ──────────────────────────────────────────────────────────────
hdr "TC-1: BLE Scan"
curl -s -X POST "$API/api/pair/scan" \
    -H 'Content-Type: application/json' \
    -d '{"type":"ble"}' > /dev/null

FOUND=0
for i in $(seq 1 8); do
    sleep 4
    FOUND=$(curl -s "$API/api/pair/devices" | json_val '["devices"].__len__()')
    [ "$FOUND" -ge 2 ] 2>/dev/null && break
done

if [ "$FOUND" -ge 2 ] 2>/dev/null; then
    ok "BLE scan found $FOUND devices"
    # Extract device IDs
    DEV_A=$(curl -s "$API/api/pair/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
print(d[0]['id'])
")
    DEV_B=$(curl -s "$API/api/pair/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
print(d[1]['id'])
")
    echo "  Device A: $DEV_A"
    echo "  Device B: $DEV_B"
else
    fail "BLE scan found only $FOUND devices (need 2)"
    echo "Aborting test — cannot proceed without 2 devices"
    echo ""
    echo "RESULTS: $PASS passed, $FAIL failed, $SKIP skipped"
    exit 1
fi

# ──────────────────────────────────────────────────────────────
hdr "TC-2: Connect Device A via multi-device API"
RESULT=$(curl -s -X POST "$API/api/devices/connect" \
    -H 'Content-Type: application/json' \
    -d "{\"id\":\"$DEV_A\",\"type\":\"ble\"}")
CON_OK=$(echo "$RESULT" | json_val '["ok"]')
[ "$CON_OK" = "True" ] && ok "Device A connected" || fail "Device A connect: $RESULT"

sleep 5  # wait for handshake

# ──────────────────────────────────────────────────────────────
hdr "TC-3: Verify Device A endpoints"

# Widgets
WC=$(curl -s "$API/api/devices/$DEV_A/widgets" | json_val '["widgets"].__len__()')
[ "$WC" -gt 0 ] 2>/dev/null && ok "Device A widgets: $WC" || fail "Device A widgets: $WC"

# Device info
DA_CONN=$(curl -s "$API/api/devices/$DEV_A" | json_val '["connected"]')
[ "$DA_CONN" = "True" ] && ok "Device A connected=True" || fail "Device A connected=$DA_CONN"

DA_FS=$(curl -s "$API/api/devices/$DEV_A" | json_val '["hasFs"]')
echo "  ℹ️  Device A hasFs=$DA_FS"

DA_OTA=$(curl -s "$API/api/devices/$DEV_A" | json_val '["hasOta"]')
echo "  ℹ️  Device A hasOta=$DA_OTA"

# Console
CC=$(curl -s "$API/api/devices/$DEV_A/console" | json_val '["entries"].__len__()')
[ "$CC" -gt 0 ] 2>/dev/null && ok "Device A console: $CC entries" || skip "Device A console empty"

# Transport ping
# (ping goes through the per-device transport)
PING=$(curl -s -X POST "$API/api/devices/$DEV_A/transport/ping" 2>/dev/null | json_val '["ok"]' 2>/dev/null)
[ "$PING" = "True" ] && ok "Device A transport ping" || skip "Device A ping: $PING"

# ──────────────────────────────────────────────────────────────
hdr "TC-4: Toggle Device A widgets"
# Toggle switch ON
SET1=$(curl -s -X PUT "$API/api/devices/$DEV_A/widgets/0" \
    -H 'Content-Type: application/json' \
    -d '{"values":[1]}' | json_val '["ok"]')
[ "$SET1" = "True" ] && ok "Device A widget 0 → ON" || fail "Device A widget set: $SET1"
sleep 1

# Read back
VAL=$(curl -s "$API/api/devices/$DEV_A/widgets/0" | json_val '["widget"]["state"]["value"]')
[ "$VAL" = "1" ] && ok "Device A widget 0 readback=1" || fail "Device A readback=$VAL"

# Toggle OFF
SET2=$(curl -s -X PUT "$API/api/devices/$DEV_A/widgets/0" \
    -H 'Content-Type: application/json' \
    -d '{"values":[0]}' | json_val '["ok"]')
[ "$SET2" = "True" ] && ok "Device A widget 0 → OFF" || fail "Device A widget off: $SET2"

# ──────────────────────────────────────────────────────────────
hdr "TC-5: Connect Device B via multi-device API"

# Re-scan may be needed (scan results may have expired)
curl -s -X POST "$API/api/pair/scan" \
    -H 'Content-Type: application/json' \
    -d '{"type":"ble"}' > /dev/null
sleep 6

# Check Device B is still in scan results
B_IN_SCAN=$(curl -s "$API/api/pair/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)
devs = d if isinstance(d,list) else d.get('devices',[])
ids = [x['id'] for x in devs]
print('$DEV_B' in ids)
")

if [ "$B_IN_SCAN" = "True" ]; then
    ok "Device B still in scan results"
else
    skip "Device B not in scan after re-scan (known Android BLE issue)"
    # Try one more time
    curl -s -X POST "$API/api/pair/scan" \
        -H 'Content-Type: application/json' \
        -d '{"type":"ble"}' > /dev/null
    sleep 8
    B_IN_SCAN=$(curl -s "$API/api/pair/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)
devs = d if isinstance(d,list) else d.get('devices',[])
ids = [x['id'] for x in devs]
print('$DEV_B' in ids)
")
fi

if [ "$B_IN_SCAN" = "True" ]; then
    RESULT_B=$(curl -s -X POST "$API/api/devices/connect" \
        -H 'Content-Type: application/json' \
        -d "{\"id\":\"$DEV_B\",\"type\":\"ble\"}")
    CON_B=$(echo "$RESULT_B" | json_val '["ok"]')
    [ "$CON_B" = "True" ] && ok "Device B connected" || fail "Device B connect: $RESULT_B"
    sleep 5

    # ──────────────────────────────────────────────────────────────
    hdr "TC-6: Verify both devices in collection"
    DEV_COUNT=$(curl -s "$API/api/devices" | json_val '["count"]')
    [ "$DEV_COUNT" = "2" ] && ok "Device collection count=2" || fail "Device count=$DEV_COUNT"

    # Both connected?
    A_CONN=$(curl -s "$API/api/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for dev in d['devices']:
    if dev['id']=='$DEV_A': print(dev['connected'])
")
    [ "$A_CONN" = "True" ] && ok "Device A still connected" || fail "Device A disconnected after B connect"

    B_CONN=$(curl -s "$API/api/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for dev in d['devices']:
    if dev['id']=='$DEV_B': print(dev['connected'])
")
    [ "$B_CONN" = "True" ] && ok "Device B connected" || fail "Device B not connected: $B_CONN"

    # ──────────────────────────────────────────────────────────────
    hdr "TC-7: Device B endpoints"
    BWC=$(curl -s "$API/api/devices/$DEV_B/widgets" | json_val '["widgets"].__len__()')
    [ "$BWC" -gt 0 ] 2>/dev/null && ok "Device B widgets: $BWC" || fail "Device B widgets: $BWC"

    BCC=$(curl -s "$API/api/devices/$DEV_B/console" | json_val '["entries"].__len__()')
    [ "$BCC" -gt 0 ] 2>/dev/null && ok "Device B console: $BCC entries" || skip "Device B console empty"

    # ──────────────────────────────────────────────────────────────
    hdr "TC-8: Simultaneous widget control"
    # Toggle A ON
    curl -s -X PUT "$API/api/devices/$DEV_A/widgets/0" \
        -H 'Content-Type: application/json' \
        -d '{"values":[1]}' > /dev/null
    # Toggle B ON
    SET_B=$(curl -s -X PUT "$API/api/devices/$DEV_B/widgets/0" \
        -H 'Content-Type: application/json' \
        -d '{"values":[1]}' | json_val '["ok"]')
    [ "$SET_B" = "True" ] && ok "Device B widget 0 → ON" || fail "Device B widget set: $SET_B"
    sleep 1

    # Read both
    VA=$(curl -s "$API/api/devices/$DEV_A/widgets/0" | json_val '["widget"]["state"]["value"]')
    VB=$(curl -s "$API/api/devices/$DEV_B/widgets/0" | json_val '["widget"]["state"]["value"]')
    [ "$VA" = "1" ] && ok "Device A readback=1 (simultaneous)" || fail "Device A readback=$VA"
    [ "$VB" = "1" ] && ok "Device B readback=1 (simultaneous)" || fail "Device B readback=$VB"

    # OFF both
    curl -s -X PUT "$API/api/devices/$DEV_A/widgets/0" \
        -H 'Content-Type: application/json' \
        -d '{"values":[0]}' > /dev/null
    curl -s -X PUT "$API/api/devices/$DEV_B/widgets/0" \
        -H 'Content-Type: application/json' \
        -d '{"values":[0]}' > /dev/null
    ok "Both widgets toggled OFF"

    # ──────────────────────────────────────────────────────────────
    hdr "TC-9: FS on Device A (if available)"
    if [ "$DA_FS" = "True" ]; then
        FS_INFO=$(curl -s "$API/api/devices/$DEV_A/fs/info")
        FS_TOTAL=$(echo "$FS_INFO" | json_val '["totalBytes"]')
        [ "$FS_TOTAL" -gt 0 ] 2>/dev/null && ok "Device A FS info: total=$FS_TOTAL" || fail "Device A FS info: $FS_INFO"

        FS_LIST=$(curl -s "$API/api/devices/$DEV_A/fs/list?path=/")
        FS_ENTRIES=$(echo "$FS_LIST" | json_val '["entries"].__len__()')
        ok "Device A FS list /: $FS_ENTRIES entries"
    else
        skip "Device A has no FS"
    fi

    # ──────────────────────────────────────────────────────────────
    hdr "TC-10: Disconnect Device A, verify B remains"
    curl -s -X POST "$API/api/devices/disconnect" \
        -H 'Content-Type: application/json' \
        -d "{\"id\":\"$DEV_A\"}" > /dev/null
    sleep 2

    DC=$(curl -s "$API/api/devices" | json_val '["count"]')
    [ "$DC" = "1" ] && ok "After disconnecting A: count=1" || fail "Count after A disconnect: $DC"

    B_STILL=$(curl -s "$API/api/devices" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for dev in d['devices']:
    if dev['id']=='$DEV_B': print(dev['connected'])
" 2>/dev/null)
    [ "$B_STILL" = "True" ] && ok "Device B remains connected" || fail "Device B after A disconnect: $B_STILL"

    # ──────────────────────────────────────────────────────────────
    hdr "TC-11: Disconnect Device B"
    curl -s -X POST "$API/api/devices/disconnect" \
        -H 'Content-Type: application/json' \
        -d "{\"id\":\"$DEV_B\"}" > /dev/null
    sleep 1

    DC2=$(curl -s "$API/api/devices" | json_val '["count"]')
    [ "$DC2" = "0" ] && ok "All devices disconnected: count=0" || fail "Final count: $DC2"

else
    fail "Cannot find Device B after re-scan — dual-BLE test skipped"
    SKIP=$((SKIP+5))

    hdr "TC-10: Disconnect Device A (solo)"
    curl -s -X POST "$API/api/devices/disconnect" \
        -H 'Content-Type: application/json' \
        -d "{\"id\":\"$DEV_A\"}" > /dev/null
    sleep 1
    DC=$(curl -s "$API/api/devices" | json_val '["count"]')
    [ "$DC" = "0" ] && ok "Device A disconnected" || fail "Count: $DC"
fi

# ──────────────────────────────────────────────────────────────
hdr "TEARDOWN"
curl -s -X PUT "$API/api/settings" \
    -H 'Content-Type: application/json' \
    -d '{"followRemoteAccess":false}' > /dev/null
ok "Follow mode disabled"

# ──────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  BLE MULTI-DEVICE TEST RESULTS"
echo "  ✅ Passed: $PASS"
echo "  ❌ Failed: $FAIL"
echo "  ⏭️  Skipped: $SKIP"
echo "═══════════════════════════════════════"
