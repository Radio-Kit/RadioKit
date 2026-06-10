#!/bin/bash
set -e

echo "=== Dual-Auth End-to-End Test ==="

# Wait for HTTP server
for i in $(seq 1 30); do
    resp=$(curl -s --connect-timeout 2 http://127.0.0.1:7007/api/connection 2>&1)
    if [ $? -eq 0 ] && [ -n "$resp" ]; then
        echo "HTTP server up (attempt $i)"
        break
    fi
    echo "Waiting... $i"
    sleep 1
done

# Scan
echo ""
echo "--- Scanning ---"
curl -s -X POST http://127.0.0.1:7007/api/pair/scan -H 'Content-Type: application/json' -d '{"type":"ble"}'
echo ""
sleep 12

# Connect
echo ""
echo "--- Connecting ---"
curl -s -X POST http://127.0.0.1:7007/api/connection/connect -H 'Content-Type: application/json' -d '{"id":"10:20:BA:2F:91:1D","type":"ble"}'
echo ""
sleep 25

# Check connection state
echo ""
echo "--- Connection State ---"
curl -s http://127.0.0.1:7007/api/connection | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('connected:', d.get('connected'))
dev = d.get('device', {})
print('device:', dev.get('name'))
print('hasFs:', dev.get('hasFs'))
print('hasOta:', dev.get('hasOta'))
"

# Check NVS state (pre-auth)
echo ""
echo "--- NVS State (pre-auth) ---"
curl -s http://127.0.0.1:7007/api/settings/nvs
echo ""

# Set both passwords via NVS
echo ""
echo "--- Setting connection password + admin password ---"
curl -s -X POST http://127.0.0.1:7007/api/settings/nvs -H 'Content-Type: application/json' -d '{"password":"conn123","adminPassword":"admin456"}'
echo ""
sleep 5

# Check NVS state after setting passwords
echo ""
echo "--- NVS State (after setting) ---"
curl -s http://127.0.0.1:7007/api/settings/nvs
echo ""

# Disconnect
echo ""
echo "--- Disconnecting ---"
curl -s -X POST http://127.0.0.1:7007/api/connection/disconnect
echo ""
sleep 3

# Reconnect
echo ""
echo "--- Reconnecting ---"
curl -s -X POST http://127.0.0.1:7007/api/pair/scan -H 'Content-Type: application/json' -d '{"type":"ble"}'
echo ""
sleep 12

curl -s -X POST http://127.0.0.1:7007/api/connection/connect -H 'Content-Type: application/json' -d '{"id":"10:20:BA:2F:91:1D","type":"ble"}'
echo ""
sleep 30

# Verify password gate shows
echo ""
echo "--- NVS State (reconnected, gate should show) ---"
curl -s http://127.0.0.1:7007/api/settings/nvs | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('hasPassword:', d.get('hasPassword'))
print('hasAdminPassword:', d.get('hasAdminPassword'))
print('isAuthenticated:', d.get('isAuthenticated'))
print('isAdminMode:', d.get('isAdminMode'))
print('isUserMode:', d.get('isUserMode'))
hasPwd = d.get('hasPassword', False)
hasAdmin = d.get('hasAdminPassword', False)
auth = d.get('isAuthenticated', False)
if hasPwd and hasAdmin and not auth:
    print('PASS: Password gate showing correctly')
else:
    print('FAIL: Expected hasPassword=true, hasAdminPassword=true, isAuthenticated=false')
    exit(1)
"

# Test user mode: authenticate with connection password
echo ""
echo "--- Authenticating with CONNECTION password (user mode) ---"
curl -s -X POST http://127.0.0.1:7007/api/settings/nvs/authenticate -H 'Content-Type: application/json' -d '{"password":"conn123"}'
echo ""
sleep 3

echo ""
echo "--- NVS State (user mode) ---"
curl -s http://127.0.0.1:7007/api/settings/nvs | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('isAuthenticated:', d.get('isAuthenticated'))
print('isAdminMode:', d.get('isAdminMode'))
print('isUserMode:', d.get('isUserMode'))
if d.get('isAuthenticated') and not d.get('isAdminMode') and d.get('isUserMode'):
    print('PASS: User mode active')
else:
    print('FAIL: Expected isAuthenticated=true, isAdminMode=false, isUserMode=true')
    exit(1)
"

# Upgrade to admin mode
echo ""
echo "--- Authenticating as ADMIN ---"
curl -s -X POST http://127.0.0.1:7007/api/settings/nvs/authenticate -H 'Content-Type: application/json' -d '{"password":"admin456"}'
echo ""
sleep 3

echo ""
echo "--- NVS State (admin mode) ---"
curl -s http://127.0.0.1:7007/api/settings/nvs | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('isAuthenticated:', d.get('isAuthenticated'))
print('isAdminMode:', d.get('isAdminMode'))
print('isUserMode:', d.get('isUserMode'))
if d.get('isAuthenticated') and d.get('isAdminMode') and not d.get('isUserMode'):
    print('PASS: Admin mode active')
else:
    print('FAIL: Expected isAuthenticated=true, isAdminMode=true, isUserMode=false')
    exit(1)
"

# Clean up - disconnect
echo ""
echo "--- Disconnecting ---"
curl -s -X POST http://127.0.0.1:7007/api/connection/disconnect
echo ""

echo ""
echo "=== All dual-auth flow tests PASSED ==="
