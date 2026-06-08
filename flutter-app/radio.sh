#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export _JAVA_OPTIONS="-Xlog:disable"
export CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-$(which chromium-browser 2>/dev/null || which chromium 2>/dev/null || true)}"

HOST_DBUS_SOCKET="/run/host/run/dbus/system_bus_socket"

while true; do
  echo "╔══════════════════════════════════════╗"
  echo "║         RadioKit Launcher            ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "1) Android"
  echo "2) Linux"
  echo "3) Web"
  echo ""
  read -rp "Select target [1-3] (q quit): " opt

  case "$opt" in
    1) target="Android" ;;
    2) target="Linux" ;;
    3) target="Web" ;;
    q|Q) echo "Aborted."; exit 0 ;;
    *) clear; continue ;;
  esac

  clear
  echo "Target: $target"
  echo ""

  # ── Linux ────────────────────────────────────────────────────────────────
  if [ "$target" = "Linux" ]; then
    if [ -S "$HOST_DBUS_SOCKET" ]; then
      export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$HOST_DBUS_SOCKET"
      echo "D-Bus: using host socket ($HOST_DBUS_SOCKET)"
    else
      echo "D-Bus: host socket not found (BLE may not work)"
    fi

    exec flutter run -d linux --debug --no-pub
  fi

  # ── Web ──────────────────────────────────────────────────────────────────
  if [ "$target" = "Web" ]; then
    fuser -k 8080/tcp 2>/dev/null || true
    exec flutter run -d chrome --web-port 8080 --web-hostname 127.0.0.1 --debug --no-pub
  fi

  # ── Android ──────────────────────────────────────────────────────────────
  DEVICES=$(adb devices 2>/dev/null | grep -w "device" | awk '{print $1}')
  DEVICE_COUNT=$(echo "$DEVICES" | grep -c . 2>/dev/null || echo 0)

  if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "No authorized ADB devices found. Building APK only..."
    flutter build apk --debug
    echo "APK: build/app/outputs/flutter-apk/app-debug.apk"
    exit 0
  fi

  DEVICE_ID="$DEVICES"
  if [ "$DEVICE_COUNT" -gt 1 ]; then
    echo "Multiple devices found:"
    echo "$DEVICES" | nl
    read -rp "Select device [1]: " n
    n="${n:-1}"
    DEVICE_ID=$(echo "$DEVICES" | sed -n "${n}p")
  fi

  DEVICE_MODEL=$(adb -s "$DEVICE_ID" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
  echo ""
  echo "Device: $DEVICE_MODEL [$DEVICE_ID]"
  echo ""

  while true; do
    echo "1) Install APK to $DEVICE_MODEL"
    echo "2) Only Build APK"
    read -rp "Choice [1] (b back, q quit): " action
    action="${action:-1}"

    case "$action" in
      q|Q) echo "Aborted."; exit 0 ;;
      b|B) clear; break 2 ;;
      1|2) break ;;
      *) echo "Invalid." ;;
    esac
  done

  if [ "$action" = "2" ]; then
    flutter build apk --debug
    echo "APK: build/app/outputs/flutter-apk/app-debug.apk"
  else
    flutter build apk --debug
    echo "Installing to $DEVICE_ID..."
    adb -s "$DEVICE_ID" install -r build/app/outputs/flutter-apk/app-debug.apk
    echo "Done."
  fi

  exit 0
done
