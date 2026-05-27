#!/bin/bash
# RadioKit — Android development launcher
# Runs the app on a connected Android device in debug mode with hot-reload enabled.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔══════════════════════════════════════╗"
echo "║   RadioKit — Android (debug)         ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Fix for JVM cgroup v2 log corruption on Fedora (corrupts build output)
export _JAVA_OPTIONS="-Xlog:disable"

# ---------------------------------------------------------------------------
# Device selection
# ---------------------------------------------------------------------------

# Get list of authorized ADB devices
DEVICES=$(adb devices 2>/dev/null | grep -w "device" | awk '{print $1}')
DEVICE_COUNT=$(echo "$DEVICES" | grep -c . 2>/dev/null || echo 0)

if [ -z "$DEVICES" ]; then
  echo "❌ No authorized Android devices found."
  echo ""
  echo "  1. Connect your device via USB"
  echo "  2. Enable Developer Options → USB Debugging"
  echo "  3. Accept the RSA key prompt on the device"
  echo ""
  echo "Then re-run this script."
  exit 1
fi

# If multiple devices, pick the first one (override with ANDROID_SERIAL env var)
if [ -n "$ANDROID_SERIAL" ]; then
  DEVICE_ID="$ANDROID_SERIAL"
  echo "Target device : $DEVICE_ID (from \$ANDROID_SERIAL)"
elif [ "$DEVICE_COUNT" -gt 1 ]; then
  DEVICE_ID=$(echo "$DEVICES" | head -n 1)
  echo "⚠️  Multiple devices found. Using first: $DEVICE_ID"
  echo "   Set ANDROID_SERIAL=<id> to choose a specific device."
else
  DEVICE_ID="$DEVICES"
  # Show friendly device name
  DEVICE_MODEL=$(adb -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
  ANDROID_VER=$(adb -s "$DEVICE_ID" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
  echo "Target device : $DEVICE_MODEL (Android $ANDROID_VER) [$DEVICE_ID]"
fi

echo "Mode          : debug (hot-reload active)"
echo ""

flutter run \
  -d "$DEVICE_ID" \
  --debug \
  --no-pub
