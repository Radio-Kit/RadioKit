#!/usr/bin/env bash
#
# ble_fs_benchmark.sh
# ===================
# Measures BLE filesystem transfer throughput and small ops latency
# via the RadioKit Remote Access API on port 7007.
#
# Usage:
#   ./ble_fs_benchmark.sh                        # auto-detect IP via ADB
#   APP_IP=10.0.0.6 ./ble_fs_benchmark.sh        # specify IP manually
#   ITERATIONS=5 ./ble_fs_benchmark.sh            # override iteration count
#
# Requires: python3 (with urllib, json, base64), curl (for small ops)
#
# Output: Tabulated results in markdown format. Run twice — once before
#         optimizations (baseline), once after (comparison).
#
# IMPORTANT: All file upload/download operations use Python's urllib directly
# to avoid the "Argument list too long" error when base64-encoding large files
# in shell command-line arguments.
#

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────

# Auto-detect IP from ADB, or use APP_IP env var
if [ -n "${APP_IP:-}" ]; then
    HOST="$APP_IP"
else
    HOST=$(adb shell ip addr show wlan0 2>/dev/null \
           | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    if [ -z "$HOST" ]; then
        echo "ERROR: Could not detect device IP. Set APP_IP env var or connect via ADB."
        exit 1
    fi
fi

BASE_URL="http://${HOST}:7007"

# File sizes to test (bytes) — up to 1 MB per spec
SIZES=(10240 102400 512000 1048576)
SIZE_NAMES=("10K" "100K" "500K" "1M")

# Number of benchmark iterations (can override via env)
ITERATIONS="${ITERATIONS:-3}"

# Temp directory
TMPDIR=$(mktemp -d /tmp/ble_fs_bench.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Helper Functions ────────────────────────────────────────────────────

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# Portable hash of a file (hex string). Uses python3 as fallback if md5sum unavailable.
file_hash() {
    local path="$1"
    if command -v md5sum &>/dev/null; then
        md5sum "$path" | awk '{print $1}'
    elif command -v python3 &>/dev/null; then
        python3 -c "import hashlib; print(hashlib.md5(open('$path','rb').read()).hexdigest())"
    else
        echo "NO_HASH"
    fi
}

# Parse JSON field — returns the raw value as a string (for booleans: "True"/"False")
json_get() {
    local json="$1"
    local field="$2"
    python3 -c "import json,sys; d=json.loads('$json' if isinstance('$json',str) else sys.stdin.read()); print(d.get('$field'))" 2>/dev/null \
        || python3 -c "import json,sys; d=json.loads('''$json'''); print(d.get('$field'))" 2>/dev/null
}

# Wait for the API server to be ready
wait_for_api() {
    local max_attempts=15
    for i in $(seq 1 "$max_attempts"); do
        if curl -s --connect-timeout 2 "${BASE_URL}/api/status" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Check if connected to a device with FS support
# Exits if not connected, returns 0 if connected with FS
check_connection() {
    local resp
    resp=$(curl -s --max-time 5 "${BASE_URL}/api/connection")
    if [ -z "$resp" ]; then
        return 1
    fi

    local connected has_fs
    connected=$(echo "$resp" | python3 -c "
import json,sys
d = json.load(sys.stdin)
print(d.get('connected', False))
")
    has_fs=$(echo "$resp" | python3 -c "
import json,sys
d = json.load(sys.stdin)
dev = d.get('device') or {}
print(dev.get('hasFs', False))
")

    if [ "$connected" != "True" ]; then
        return 1
    fi
    if [ "$has_fs" != "True" ]; then
        return 2
    fi
    return 0
}

# Generate random test file of exactly N bytes
gen_test_file() {
    local path="$1"
    local size="$2"
    python3 -c "
import os
data = os.urandom($size)
with open('$path', 'wb') as f:
    f.write(data)
"
}

# Make an API call via curl with JSON body. Returns 0 on success, 1 on failure.
# Only used for small payload calls (small ops batch, format, etc.)
# For large file uploads/downloads, use the python-based functions below.
api_call() {
    local method="$1"
    local url="$2"
    local body="${3:-}"

    local resp
    if [ -n "$body" ]; then
        resp=$(curl -s --max-time 60 -X "$method" "$url" \
            -H 'Content-Type: application/json' -d "$body" 2>/dev/null)
    else
        resp=$(curl -s --max-time 60 -X "$method" "$url" 2>/dev/null)
    fi

    [ -z "$resp" ] && return 1

    # Check for success indicators in JSON response
    echo "$resp" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    if d.get('ok') == True:
        sys.exit(0)
    if 'error' not in d:
        sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null && return 0 || return 1
}

# Upload a file via Python's urllib (avoids shell argument limits)
# Uses a python helper script that reads the file directly
# Args: local_path, remote_path
# Prints: "elapsed_ms" on success, "FAIL" on failure
# Returns: 0 on success, 1 on failure
api_upload() {
    local local_path="$1"
    local remote_path="$2"
    local url="${BASE_URL}/api/fs/write"

    local start end elapsed
    start=$(date +%s%N)

    if python3 -c "
import base64, json, urllib.request, sys, os

url = '$url'
path = '$remote_path'
local_path = '$local_path'

with open(local_path, 'rb') as f:
    data_b64 = base64.b64encode(f.read()).decode()

body = json.dumps({'path': path, 'data': data_b64}).encode()
req = urllib.request.Request(url, data=body,
    headers={'Content-Type': 'application/json'},
    method='POST')

try:
    resp = urllib.request.urlopen(req, timeout=60)
    result = json.loads(resp.read())
    if result.get('ok'):
        sys.exit(0)
    sys.exit(1)
except Exception as e:
    sys.exit(1)
" 2>/dev/null; then
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        echo "$elapsed"
        return 0
    else
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        echo "$elapsed"
        return 1
    fi
}

# Download a file via Python's urllib (avoids shell argument limits)
# Args: remote_path, local_output_path
# Prints: "elapsed_ms" on success, "FAIL" on failure
# Returns: 0 on success, 1 on failure
api_download() {
    local remote_path="$1"
    local local_path="$2"
    local url="${BASE_URL}/api/fs/read"

    local start end elapsed
    start=$(date +%s%N)

    if python3 -c "
import urllib.request, urllib.parse, json, base64, sys

base_url = '$url'
path = '$remote_path'
local_path = '$local_path'

encoded = urllib.parse.quote(path, safe='')
full_url = f'{base_url}?path={encoded}'

try:
    resp = urllib.request.urlopen(full_url, timeout=120)
    result = json.loads(resp.read())
    data_b64 = result.get('data', '')
    if not data_b64:
        sys.exit(1)
    raw = base64.b64decode(data_b64)
    with open(local_path, 'wb') as f:
        f.write(raw)
    sys.exit(0)
except Exception as e:
    sys.exit(1)
" 2>/dev/null; then
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        echo "$elapsed"
        return 0
    else
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        echo "$elapsed"
        return 1
    fi
}

# Delete a remote file
api_delete() {
    local path="$1"
    local body
    body=$(python3 -c "import json; print(json.dumps({'path': '$path'}))")
    curl -s -X POST "${BASE_URL}/api/fs/delete" \
        -H 'Content-Type: application/json' \
        -d "$body" > /dev/null 2>&1
}

# Small ops batch: LIST, INFO, MKDIR, LIST again, DELETE
# Returns: total elapsed_ms (always succeeds)
run_small_ops_batch() {
    local start end
    start=$(date +%s%N)

    # 1. LIST root
    api_call GET "${BASE_URL}/api/fs/list?path=%2F" || true

    # 2. INFO
    api_call GET "${BASE_URL}/api/fs/info" || true

    # 3. MKDIR
    api_call POST "${BASE_URL}/api/fs/mkdir" '{"path":"/__bench_test"}' || true

    # 4. LIST again
    api_call GET "${BASE_URL}/api/fs/list?path=%2F" || true

    # 5. DELETE
    api_call POST "${BASE_URL}/api/fs/delete" '{"path":"/__bench_test"}' || true

    end=$(date +%s%N)
    echo $(( (end - start) / 1000000 ))
}

# ── Main ────────────────────────────────────────────────────────────────

echo ""
echo "=========================================="
echo "  RadioKit BLE FS Throughput Benchmark"
echo "=========================================="
echo ""
echo "Target:     ${BASE_URL}"
echo "Iterations: ${ITERATIONS}"
echo "File sizes: ${SIZE_NAMES[*]}"
echo ""

# Step 1: Wait for API
info "Waiting for Remote Access API at ${BASE_URL}..."
if ! wait_for_api; then
    fail "API not reachable at ${BASE_URL} after 15s"
    echo "  Make sure the Flutter app is running in debug mode."
    echo "  See llm-docs/AGENT-TEST.md for setup instructions."
    exit 1
fi
ok "API reachable"

# Step 2: Check connection state
info "Checking device connection..."
if ! check_connection; then
    warn "Not connected to a device with FS support."
    echo ""
    echo "  To connect:"
    echo "    1. Scan for BLE devices:"
    echo "       curl -s -X POST ${BASE_URL}/api/pair/scan \\"
    echo "           -H 'Content-Type: application/json' -d '{\"type\":\"ble\"}'"
    echo "    2. Wait 10s, then list devices:"
    echo "       curl -s ${BASE_URL}/api/pair/devices"
    echo "    3. Connect (replace MAC with actual address):"
    echo "       curl -s -X POST ${BASE_URL}/api/connection/connect \\"
    echo "           -H 'Content-Type: application/json' \\"
    echo "           -d '{\"id\":\"<MAC>\",\"type\":\"ble\"}'"
    echo "    4. Wait 12s for FS detection, then re-run this script."
    echo ""
    exit 1
fi
ok "Device connected with FS support"

# Step 3: Get device info
DEVICE_NAME=$(curl -s "${BASE_URL}/api/connection" | python3 -c "
import json,sys
d = json.load(sys.stdin)
dev = d.get('device') or {}
print(dev.get('configName', dev.get('name', 'unknown')))
")
info "Connected to: ${DEVICE_NAME}"

# Step 4: Quick verification that FS responds
info "Verifying filesystem is responsive..."
VERIFY_OK=false
for attempt in 1 2 3 4 5; do
    list_resp=$(curl -s --max-time 10 "${BASE_URL}/api/fs/list?path=%2F" 2>/dev/null)
    if echo "$list_resp" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
        VERIFY_OK=true
        break
    fi
    info "  FS not ready yet (attempt $attempt/5)..."
    sleep 2
done

if [ "$VERIFY_OK" = false ]; then
    fail "Filesystem not responding after 5 attempts"
    exit 1
fi
ok "Filesystem ready (write with offset=0 truncates automatically)"

# Clean up any leftover files from previous runs
info "Cleaning up previous benchmark files..."
for old_size in "${SIZE_NAMES[@]}"; do
    python3 -c "
import json, urllib.request
body = json.dumps({'path': '/__bench_${old_size}.bin'}).encode()
req = urllib.request.Request('${BASE_URL}/api/fs/delete', data=body,
    headers={'Content-Type': 'application/json'}, method='POST')
try:
    urllib.request.urlopen(req, timeout=5)
except:
    pass
" 2>/dev/null || true
done
python3 -c "
import json, urllib.request
body = json.dumps({'path': '/__bench_test'}).encode()
req = urllib.request.Request('${BASE_URL}/api/fs/delete', data=body,
    headers={'Content-Type': 'application/json'}, method='POST')
try:
    urllib.request.urlopen(req, timeout=5)
except:
    pass
" 2>/dev/null || true

# ── Results storage ─────────────────────────────────────────────────────
# Results are stored in temp files that the downstream python table renderer
# can read. This avoids bash array/nameref portability issues.
# File pattern: $TMPDIR/arr_{type}_{size} where type is like upload_times, etc.
store_result() {
    local prefix="$1"
    local size_name="$2"
    local value="$3"
    echo "$value" >> "${TMPDIR}/arr_${prefix}_${size_name}"
}

store_ops_result() {
    local value="$1"
    echo "$value" >> "${TMPDIR}/arr_small_ops_times"
}

# ── Run benchmarks ─────────────────────────────────────────────────────

for iter in $(seq 1 "$ITERATIONS"); do
    echo ""
    echo "━━━ Iteration ${iter}/${ITERATIONS} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Delete leftover files from previous iteration
    for old_size in "${SIZE_NAMES[@]}"; do
        api_delete "/__bench_${old_size}.bin" > /dev/null 2>&1 || true
    done

    # ── Upload tests ──────────────────────────────────────────────
    for i in "${!SIZES[@]}"; do
        local_size="${SIZES[$i]}"
        size_name="${SIZE_NAMES[$i]}"
        remote_path="/__bench_${size_name}.bin"
        local_path="${TMPDIR}/upload_${size_name}.bin"

        # Generate test data
        gen_test_file "$local_path" "$local_size"
        actual_size=$(wc -c < "$local_path")

        echo -n "  Upload ${size_name}... "

        if elapsed=$(api_upload "$local_path" "$remote_path"); then
            speed_kbps=$(echo "scale=1; $actual_size / $elapsed * 1000 / 1024" | bc)
            echo "${elapsed}ms (${speed_kbps} KB/s)"
            store_result "upload_times" "$size_name" "$elapsed"
            store_result "upload_speeds" "$size_name" "$speed_kbps"
        else
            echo -e "${RED}failed${NC}"
            store_result "upload_times" "$size_name" "FAIL"
            store_result "upload_speeds" "$size_name" "FAIL"
        fi
    done

    # ── Download tests ────────────────────────────────────────────
    for i in "${!SIZES[@]}"; do
        local_size="${SIZES[$i]}"
        size_name="${SIZE_NAMES[$i]}"
        remote_path="/__bench_${size_name}.bin"
        local_path="${TMPDIR}/download_${size_name}_iter${iter}.bin"

        echo -n "  Download ${size_name}... "

        if elapsed=$(api_download "$remote_path" "$local_path"); then
            dl_size=$(wc -c < "$local_path" 2>/dev/null || echo 0)
            orig_hash=$(file_hash "${TMPDIR}/upload_${size_name}.bin")
            dl_hash=$(file_hash "$local_path")

            if [ "$orig_hash" = "$dl_hash" ] && [ "$dl_size" -eq "$local_size" ]; then
                speed_kbps=$(echo "scale=1; $dl_size / $elapsed * 1000 / 1024" | bc)
                echo "${elapsed}ms (${speed_kbps} KB/s) ✓"
                store_result "download_times" "$size_name" "$elapsed"
                store_result "download_speeds" "$size_name" "$speed_kbps"
            else
                echo -e "${RED}${elapsed}ms — INTEGRITY FAIL (hash mismatch or size ${dl_size} vs ${local_size})${NC}"
                store_result "download_times" "$size_name" "FAIL"
                store_result "download_speeds" "$size_name" "FAIL"
            fi
        else
            echo -e "${RED}failed${NC}"
            store_result "download_times" "$size_name" "FAIL"
            store_result "download_speeds" "$size_name" "FAIL"
        fi
    done

    # ── Small ops latency ─────────────────────────────────────────
    echo -n "  Small ops batch (LIST+INFO+MKDIR+LIST+DELETE)... "
    ops_time=$(run_small_ops_batch)
    store_ops_result "$ops_time"
    echo "${ops_time}ms"
done

# ── Results Table (using python3 for computation to avoid bash nameref issues) ──
echo ""
echo ""
echo "=========================================="
echo "  RESULTS"
echo "=========================================="
echo ""

# Build a JSON results blob for python3 to render the table
python3 -c "
import json, math

results = {
    'upload_times': {},
    'upload_speeds': {},
    'download_times': {},
    'download_speeds': {},
    'small_ops_times': [],
}

# Populate from shell arrays (passed via heredoc would be complex, so we hardcode for now)
# The shell script stores data in parallel arrays; convert to python
import os

# Read from temp files populated by the shell
base = '$TMPDIR'

def load_arr(suffix):
    fpath = os.path.join(base, f'arr_{suffix}')
    if os.path.exists(fpath):
        with open(fpath) as f:
            return [line.strip() for line in f if line.strip()]
    return []

for sn in ['10K', '100K', '500K', '1M']:
    for prefix in ['upload_times', 'upload_speeds', 'download_times', 'download_speeds']:
        arr = load_arr(f'{prefix}_{sn}')
        results[prefix][sn] = arr

results['small_ops_times'] = load_arr('small_ops_times')

def avg_ms(arr):
    vals = [int(v) for v in arr if v != 'FAIL']
    if not vals:
        return 'FAIL'
    return str(int(sum(vals) / len(vals)))

def avg_kbps(arr):
    vals = [float(v) for v in arr if v != 'FAIL']
    if not vals:
        return 'FAIL'
    return f'{sum(vals)/len(vals):.1f}'

def get(arr, idx):
    if idx < len(arr):
        return arr[idx]
    return 'FAIL'

print()
print('### Upload Throughput')
print()
print('| Size | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Avg (ms) | Avg (KB/s) |')
print('|------|-----------|-----------|-----------|---------|-----------|')
for sn in ['10K', '100K', '500K', '1M']:
    times = results['upload_times'].get(sn, [])
    speeds = results['upload_speeds'].get(sn, [])
    r1 = get(times, 0)
    r2 = get(times, 1)
    r3 = get(times, 2)
    at = avg_ms(times)
    as_ = avg_kbps(speeds)
    print(f'| {sn} | {r1} | {r2} | {r3} | {at} | {as_} |')

print()
print('### Download Throughput')
print()
print('| Size | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Avg (ms) | Avg (KB/s) |')
print('|------|-----------|-----------|-----------|---------|-----------|')
for sn in ['10K', '100K', '500K', '1M']:
    times = results['download_times'].get(sn, [])
    speeds = results['download_speeds'].get(sn, [])
    r1 = get(times, 0)
    r2 = get(times, 1)
    r3 = get(times, 2)
    at = avg_ms(times)
    as_ = avg_kbps(speeds)
    print(f'| {sn} | {r1} | {r2} | {r3} | {at} | {as_} |')
"

echo ""
echo "### Small Ops Latency"
echo ""
echo "| Run | Total (ms) |"
echo "|-----|-----------|"
for i in "${!SMALL_OPS_TIMES[@]}"; do
    echo "| $((i + 1)) | ${SMALL_OPS_TIMES[$i]} |"
done

total_ops_sum=0
total_ops_count=0
for t in "${SMALL_OPS_TIMES[@]}"; do
    total_ops_sum=$((total_ops_sum + t))
    total_ops_count=$((total_ops_count + 1))
done
if [ "$total_ops_count" -gt 0 ]; then
    avg_ops_ms=$((total_ops_sum / total_ops_count))
else
    avg_ops_ms="?"
fi
echo ""
echo "**Average small ops batch: ${avg_ops_ms} ms**"
echo ""

# ── Cleanup remote files ───────────────────────────────────────────────
info "Cleaning up remote test files..."
for i in "${!SIZE_NAMES[@]}"; do
    api_delete "/__bench_${SIZE_NAMES[$i]}.bin" || true
done
api_delete "/__bench_test" 2>/dev/null || true  # in case small ops cleanup failed
ok "Cleanup complete"

echo ""
echo "=========================================="
echo "  Benchmark complete"
echo "=========================================="
echo ""
echo "To save: ./ble_fs_benchmark.sh | tee baseline_results.md"
echo ""
