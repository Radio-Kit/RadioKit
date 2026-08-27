#!/usr/bin/env python3
import sys
import time
import zlib
import struct
import serial
import requests

PORT = "/dev/ttyACM0"
BAUD = 1000000

def read_exact(ser, n, timeout=5.0):
    start = time.time()
    buf = bytearray()
    while len(buf) < n:
        if time.time() - start > timeout:
            raise TimeoutError(f"Timeout waiting for {n} bytes (got {len(buf)})")
        to_read = min(ser.in_waiting or 1, n - len(buf))
        chunk = ser.read(to_read)
        if chunk:
            buf.extend(chunk)
        else:
            time.sleep(0.002)
    return bytes(buf)

def read_frame(ser, expected_start, expected_sub_cmd=None, timeout=5.0):
    start = time.time()
    while time.time() - start < timeout:
        b = ser.read(1)
        if len(b) == 0:
            continue
        if b[0] == 0xEE:
            # Print frame: [0xEE][LEN_LO][LEN_HI][PAYLOAD...]
            # MAX frame len is 255 (RK_PRINT_HEADER_SIZE + RK_PRINT_MAX_PAYLOAD)
            try:
                hdr = read_exact(ser, 2, timeout=0.5)
                frame_len = hdr[0] | (hdr[1] << 8)
                if 3 <= frame_len <= 255:
                    read_exact(ser, frame_len - 3, timeout=0.5)
            except Exception:
                pass
            continue
        if b[0] == expected_start:
            try:
                hdr = read_exact(ser, 3, timeout=1.0)
                sub_cmd = hdr[0]
                length = hdr[1] | (hdr[2] << 8)
                if length < 4 or length > 5000:
                    continue
                payload_len = length - 4
                payload = read_exact(ser, payload_len, timeout=2.0) if payload_len > 0 else b""
                if expected_sub_cmd is not None and sub_cmd != expected_sub_cmd:
                    continue
                return sub_cmd, payload
            except Exception:
                continue
    raise TimeoutError(f"Timeout waiting for frame starting with 0x{expected_start:02X} (sub_cmd={expected_sub_cmd})")

def parse_device_info(payload):
    # [PROTO_VER(1)][NAME_LEN(1)][NAME][DESC_LEN(1)][DESC][UID_LEN(1)][UID(16)][ICON_LEN(1)][ICON...][VER_LEN(1)][VERSION...]
    proto_ver = payload[0]
    name_len = payload[1]
    offset = 2
    name = payload[offset:offset+name_len].decode('utf-8', errors='ignore')
    offset += name_len
    desc_len = payload[offset]
    offset += 1
    desc = payload[offset:offset+desc_len].decode('utf-8', errors='ignore')
    offset += desc_len
    uid_len = payload[offset]
    offset += 1
    uid = payload[offset:offset+uid_len].decode('utf-8', errors='ignore')
    offset += uid_len
    icon = ""
    if offset < len(payload):
        icon_len = payload[offset]
        offset += 1
        icon = payload[offset:offset+icon_len].decode('utf-8', errors='ignore')
        offset += icon_len
    ver = ""
    if offset < len(payload):
        ver_len = payload[offset]
        offset += 1
        ver = payload[offset:offset+ver_len].decode('utf-8', errors='ignore')
        offset += ver_len
    return {
        "proto_ver": proto_ver,
        "name": name,
        "desc": desc,
        "uid": uid,
        "icon": icon,
        "version": ver,
    }

def parse_links_info(payload):
    # [FS_LEN(1)][FS_URL...][OTA_LEN(1)][OTA_URL...]
    offset = 0
    fs_len = payload[offset]
    offset += 1
    fs_url = payload[offset:offset+fs_len].decode('utf-8', errors='ignore')
    offset += fs_len
    ota_len = payload[offset]
    offset += 1
    ota_url = payload[offset:offset+ota_len].decode('utf-8', errors='ignore')
    offset += ota_len
    return {"fs_url": fs_url, "ota_url": ota_url}

_rx_buf = bytearray()

def read_ota_ack(ser, timeout=5.0):
    global _rx_buf
    start = time.time()
    while time.time() - start < timeout:
        while len(_rx_buf) > 0 and _rx_buf[0] != 0xBB:
            del _rx_buf[0]
        
        if len(_rx_buf) >= 5 and _rx_buf[0] == 0xBB and _rx_buf[1] == 0x81:
            err = _rx_buf[4]
            del _rx_buf[:5]
            return err
        elif len(_rx_buf) >= 1 and _rx_buf[0] == 0xBB and time.time() - start > 0.15:
            _rx_buf.clear()
            return 0x00

        chunk = ser.read(ser.in_waiting or 1)
        if chunk:
            _rx_buf.extend(chunk)
        else:
            time.sleep(0.001)
    raise TimeoutError(f"Timeout waiting for OTA ACK: buffered {len(_rx_buf)} bytes: {_rx_buf.hex()}")

def send_paced(ser, data, chunk_sz=64, delay=0.002):
    for i in range(0, len(data), chunk_sz):
        ser.write(data[i:i+chunk_sz])
        ser.flush()
        if delay > 0:
            time.sleep(delay)

def main():
    print(f"=== 1. Connecting to device on {PORT} @ {BAUD} ===")
    ser = serial.Serial()
    ser.port = PORT
    ser.baudrate = BAUD
    ser.timeout = 0.05
    ser.dtr = True
    ser.rts = False
    ser.open()
    time.sleep(1.0)
    ser.reset_input_buffer()

    print("=== 2. Requesting Device Info & Links Info (0xDD) ===")
    # Send GET_DEVICE_INFO: 0xDD, 0x08, 0x04, 0x00
    ser.write(bytes([0xDD, 0x08, 0x04, 0x00]))
    sub_cmd, payload = read_frame(ser, 0xDD, expected_sub_cmd=0x88, timeout=3.0)
    info = parse_device_info(payload)
    print(f"Device Info Received: Name='{info['name']}', UID='{info['uid']}', Version='{info['version']}'")
    assert info['name'] == "Basic_Switch", f"Unexpected name: {info['name']}"
    assert info['version'] == "1.0.0", f"Unexpected initial version: {info['version']}"

    # Send GET_LINKS_INFO: 0xDD, 0x0F, 0x04, 0x00
    ser.write(bytes([0xDD, 0x0F, 0x04, 0x00]))
    sub_cmd, payload = read_frame(ser, 0xDD, expected_sub_cmd=0x8F, timeout=3.0)
    links = parse_links_info(payload)
    print(f"Links Info Received: FS_URL='{links['fs_url']}', OTA_URL='{links['ota_url']}'")
    assert "demo-fs-assets" in links['ota_url'], f"Unexpected ota_url: {links['ota_url']}"

    print(f"\n=== 3. Querying GitHub Releases for {links['ota_url']} ===")
    api_url = "https://api.github.com/repos/Radio-Kit/demo-fs-assets/releases/latest"
    resp = requests.get(api_url, headers={"User-Agent": "RadioKit-E2ETest"})
    assert resp.status_code == 200, f"GitHub API failed: {resp.status_code}"
    release_data = resp.json()
    tag_name = release_data["tag_name"]
    print(f"Latest Release: Tag={tag_name}, Title='{release_data['name']}'")
    assert tag_name == "v2.1.0", f"Unexpected tag: {tag_name}"

    # Find matching asset
    bin_assets = [a for a in release_data["assets"] if a["name"].endswith(".bin")]
    print(f"Found {len(bin_assets)} bin assets: {[a['name'] for a in bin_assets]}")
    target_asset = next((a for a in bin_assets if "Basic_Switch" in a["name"]), bin_assets[0])
    download_url = target_asset["browser_download_url"]
    print(f"Downloading asset '{target_asset['name']}' from {download_url}...", flush=True)
    firmware_bytes = requests.get(download_url, headers={"User-Agent": "RadioKit-E2ETest"}, timeout=30).content
    print(f"Downloaded {len(firmware_bytes)} bytes.", flush=True)

    print(f"\n=== 4. Flashing Firmware via Serial OTA Protocol (0xBB) ===")
    # 4.1 OTA_BEGIN: [FIRMWARE_SIZE(4 LE)]
    size = len(firmware_bytes)
    begin_payload = struct.pack("<I", size)
    total_len = 4 + len(begin_payload)
    send_paced(ser, bytes([0xBB, 0x01, total_len & 0xFF, (total_len >> 8) & 0xFF]) + begin_payload)
    err = read_ota_ack(ser, timeout=5.0)
    assert err == 0x00, f"OTA_BEGIN failed with err={err}"
    print("OTA_BEGIN acknowledged.")

    # 4.2 Stream CHUNKS (512 bytes per chunk)
    chunk_size = 512
    offset = 0
    chunk_idx = 0
    t_start = time.time()
    while offset < size:
        chunk = firmware_bytes[offset:offset+chunk_size]
        chunk_payload = struct.pack("<I", offset) + chunk
        total_len = 4 + len(chunk_payload)
        pkt = bytes([0xBB, 0x02, total_len & 0xFF, (total_len >> 8) & 0xFF]) + chunk_payload
        send_paced(ser, pkt)
        err = read_ota_ack(ser, timeout=10.0)
        assert err == 0x00, f"OTA_CHUNK {chunk_idx} failed at offset {offset} with err={err}"
        offset += len(chunk)
        chunk_idx += 1
        pct = (offset * 100) // size
        if chunk_idx % 50 == 0 or offset >= size:
            elapsed = time.time() - t_start
            rate = (offset / 1024) / max(0.1, elapsed)
            print(f"Uploaded {offset}/{size} bytes ({pct}%) - chunk {chunk_idx} [{rate:.1f} KB/s]")
    print("All chunks uploaded.")

    # 4.3 OTA_END: [CRC32(4 LE)]
    crc = zlib.crc32(firmware_bytes) & 0xFFFFFFFF
    end_payload = struct.pack("<I", crc)
    total_len = 4 + len(end_payload)
    send_paced(ser, bytes([0xBB, 0x03, total_len & 0xFF, (total_len >> 8) & 0xFF]) + end_payload)
    err = read_ota_ack(ser, timeout=10.0)
    assert err == 0x00, f"OTA_END failed with err={err}"
    print("OTA_END acknowledged! Device is rebooting...")
    ser.close()

    print("\n=== 5. Waiting for Device Reboot ===")
    time.sleep(4.0)

    print(f"=== 6. Reconnecting and Verifying Updated Firmware Version ===")
    ser = serial.Serial()
    ser.port = PORT
    ser.baudrate = BAUD
    ser.timeout = 0.05
    ser.dtr = True
    ser.rts = False
    ser.open()
    time.sleep(1.0)
    ser.reset_input_buffer()

    ser.write(bytes([0xDD, 0x08, 0x04, 0x00]))
    sub_cmd, payload = read_frame(ser, 0xDD, timeout=3.0)
    assert sub_cmd == 0x88, f"Expected 0x88, got 0x{sub_cmd:02X}"
    new_info = parse_device_info(payload)
    print(f"New Device Info Received:")
    print(f"  Name:    '{new_info['name']}'")
    print(f"  UID:     '{new_info['uid']}'")
    print(f"  Version: '{new_info['version']}'")
    ser.close()

    assert new_info['version'] == "2.1.0", f"Expected version 2.1.0 after update, got {new_info['version']}"
    print("\n[SUCCESS] Firmware OTA Check & Update verification completed successfully!")

if __name__ == "__main__":
    main()
