#!/usr/bin/env python3
"""
Test API→BLE→Firmware round-trip timing.
Sends rapid slider commands and measures:
1. API response time (app processing)
2. Time until firmware sees the change (via serial monitoring)
"""
import time, json, urllib.request, serial, re

API = 'http://127.0.0.1:17007'

def send_cmd(widget_id, value):
    t0 = time.time()
    data = json.dumps({'values': [value]}).encode()
    req = urllib.request.Request(f'{API}/api/widgets/{widget_id}',
                               data=data, method='PUT',
                               headers={'Content-Type': 'application/json'})
    try:
        resp = urllib.request.urlopen(req, timeout=3)
        body = resp.read()
        return (time.time() - t0) * 1000
    except Exception as e:
        return -1

ser = serial.Serial('/dev/ttyACM0', 115200, timeout=0.5)
ser.reset_input_buffer()

# Drain initial output
start = time.time()
while time.time() - start < 2:
    ser.readline()

print("=== API → BLE → Firmware Latency Test ===")
print()

results = []

# Phase 1: Single commands with full firmware capture
print("--- Phase 1: Single commands (2s gap) ---")
for i in range(5):
    val = (i % 200) - 100
    t_api_start = time.time()
    api_ms = send_cmd(0, val)
    t_api_end = time.time()
    
    # Wait for firmware to process and print
    firmware_ms = -1
    search_end = time.time() + 3
    while time.time() < search_end:
        raw = ser.readline()
        if raw:
            try:
                line = raw.decode('utf-8', errors='replace').strip()
                if '[SLIDER]' in line:
                    val_match = re.search(r'val=(-?\d+)', line)
                    if val_match and int(val_match.group(1)) == val:
                        firmware_ms = (time.time() - t_api_start) * 1000
                        print(f"  cmd={val:4d}  API={api_ms:.0f}ms  FW_total={firmware_ms:.0f}ms  FW-only={firmware_ms-api_ms:.0f}ms")
                        results.append(('single', val, api_ms, firmware_ms))
                        break
            except: pass
    
    if firmware_ms < 0:
        print(f"  cmd={val:4d}  API={api_ms:.0f}ms  FW=TIMEOUT")
    time.sleep(1)

# Phase 2: Rapid fire - send 20 commands quickly, see how many firmware receives
print()
print("--- Phase 2: Rapid fire (20 cmds, no gap) ---")
t_batch_start = time.time()
sent_times = []
for i in range(20):
    val = 50 + (i % 5)  # vary slightly
    t0 = time.time()
    api_ms = send_cmd(0, val)
    sent_times.append((time.time() - t_api_start, val, api_ms))

# Collect all firmware responses for 5 seconds
fw_received = []
search_end = time.time() + 5
while time.time() < search_end:
    raw = ser.readline()
    if raw:
        try:
            line = raw.decode('utf-8', errors='replace').strip()
            if '[SLIDER]' in line:
                val_match = re.search(r'val=(-?\d+)', line)
                if val_match:
                    fw_time = time.time() - t_batch_start
                    fw_val = int(val_match.group(1))
                    fw_received.append((fw_time, fw_val))
        except: pass

print(f"  Sent: {len(sent_times)} commands in {(sent_times[-1][0])*1000:.0f}ms")
print(f"  Firmware received: {len(fw_received)} changes")
if fw_received:
    intervals = []
    for i in range(1, len(fw_received)):
        dt = (fw_received[i][0] - fw_received[i-1][0]) * 1000
        intervals.append(dt)
    if intervals:
        print(f"  FW interval avg: {sum(intervals)/len(intervals):.0f}ms  min: {min(intervals):.0f}ms  max: {max(intervals):.0f}ms")
    # Show first 10
    for t, v in fw_received[:10]:
        print(f"    t={t*1000:.0f}ms val={v}")

ser.close()

print()
print("=== SUMMARY ===")
if results:
    api_avg = sum(r[2] for r in results) / len(results)
    fw_avg = sum(r[3] for r in results) / len(results)
    print(f"API avg: {api_avg:.0f}ms")
    print(f"FW total avg: {fw_avg:.0f}ms")
    print(f"BLE transport overhead: {fw_avg - api_avg:.0f}ms")
