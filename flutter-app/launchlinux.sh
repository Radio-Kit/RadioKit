#!/bin/bash
# RadioKit — Linux desktop development launcher
# Runs the app on the native Linux target in debug mode with hot-reload enabled.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔══════════════════════════════════════╗"
echo "║   RadioKit — Linux Desktop (debug)   ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Target device : linux"
echo "Mode          : debug (hot-reload active)"
echo ""

# Forward the host system D-Bus socket so universal_ble can reach BlueZ.
# Inside Toolbx the host socket is bind-mounted at this path.
HOST_DBUS_SOCKET="/run/host/run/dbus/system_bus_socket"
if [ -S "$HOST_DBUS_SOCKET" ]; then
  export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$HOST_DBUS_SOCKET"
  echo "D-Bus  : using host socket ($HOST_DBUS_SOCKET)"
else
  echo "D-Bus  : host socket not found, using default (BLE may not work)"
fi
echo ""

flutter run -d linux \
  --debug \
  --no-pub
