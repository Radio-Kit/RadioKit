#!/usr/bin/env python3
"""
package_release.py

Packages PlatformIO build outputs into standard ESP Web Tools compatible .zip bundles
containing manifest.json and component partition binaries.
"""

import argparse
import json
import os
import sys
import zipfile

# Standard 8KB otadata boot_app0 binary content (selects ota_0)
BOOT_APP0_DEFAULT = b'\x00' * 32 + b'\x00' * (8192 - 32)

def package_bundle(build_dir, out_dir, name="RadioKit RC Engine", version="1.0.0", chip_family="ESP32-S3", board="tracklink_v3"):
    if not os.path.exists(build_dir):
        print(f"[ERROR] Build directory not found: {build_dir}", file=sys.stderr)
        return False

    bootloader = os.path.join(build_dir, "bootloader.bin")
    partitions = os.path.join(build_dir, "partitions.bin")
    firmware = os.path.join(build_dir, "firmware.bin")
    littlefs = os.path.join(build_dir, "littlefs.bin")
    boot_app0 = os.path.join(build_dir, "boot_app0.bin")

    if not os.path.exists(firmware):
        print(f"[ERROR] firmware.bin missing in {build_dir}", file=sys.stderr)
        return False

    parts = []
    zip_files = []

    # 1. Bootloader @ 0x0000
    if os.path.exists(bootloader):
        parts.append({"path": "bootloader.bin", "offset": 0})
        zip_files.append(("bootloader.bin", bootloader))

    # 2. Partition Table @ 0x8000 (32768)
    if os.path.exists(partitions):
        parts.append({"path": "partitions.bin", "offset": 32768})
        zip_files.append(("partitions.bin", partitions))

    # 3. OTA Data @ 0xE000 (57344)
    if os.path.exists(boot_app0):
        parts.append({"path": "boot_app0.bin", "offset": 57344})
        zip_files.append(("boot_app0.bin", boot_app0))
    elif os.path.exists(bootloader):
        # Generate standard 8KB otadata if missing but bootloader is present
        temp_otadata = os.path.join(build_dir, "_gen_boot_app0.bin")
        with open(temp_otadata, "wb") as f:
            f.write(BOOT_APP0_DEFAULT)
        parts.append({"path": "boot_app0.bin", "offset": 57344})
        zip_files.append(("boot_app0.bin", temp_otadata))

    # 4. App Firmware @ 0x10000 (65536)
    parts.append({"path": "firmware.bin", "offset": 65536})
    zip_files.append(("firmware.bin", firmware))

    # 5. LittleFS @ 0x310000 (3211264)
    if os.path.exists(littlefs):
        parts.append({"path": "littlefs.bin", "offset": 3211264})
        zip_files.append(("littlefs.bin", littlefs))

    manifest = {
        "name": name,
        "version": version,
        "home_assistant_domain": "radiokit",
        "builds": [
            {
                "chipFamily": chip_family,
                "parts": parts
            }
        ]
    }

    os.makedirs(out_dir, exist_ok=True)
    zip_filename = f"{name.replace(' ', '_')}-{version}-{chip_family.lower()}-{board}.zip"
    zip_path = os.path.join(out_dir, zip_filename)

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("manifest.json", json.dumps(manifest, indent=2))
        for arcname, filepath in zip_files:
            zf.write(filepath, arcname=arcname)

    print(f"[OK] Created release bundle: {zip_path}")
    print(f"     Chip: {chip_family} | Parts: {len(parts)} | Size: {os.path.getsize(zip_path)} bytes")
    return zip_path

def main():
    parser = argparse.ArgumentParser(description="Package RadioKit firmware into ESP Web Tools .zip bundle")
    parser.add_argument("--build-dir", required=True, help="Path to PlatformIO build output directory")
    parser.add_argument("--out-dir", default="./dist", help="Output directory for .zip release bundle")
    parser.add_argument("--name", default="RadioKit RC Engine", help="Release name")
    parser.add_argument("--version", default="1.0.0", help="Release version")
    parser.add_argument("--chip", default="ESP32-S3", help="Target chip family (e.g. ESP32, ESP32-S3)")
    parser.add_argument("--board", default="tracklink_v3", help="Target board identifier")

    args = parser.parse_args()
    res = package_bundle(
        build_dir=args.build_dir,
        out_dir=args.out_dir,
        name=args.name,
        version=args.version,
        chip_family=args.chip,
        board=args.board
    )
    if not res:
        sys.exit(1)

if __name__ == "__main__":
    main()
