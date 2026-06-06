#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"

RED='\033[0;31m';    GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'
NC='\033[0m'

die()   { echo -e "${RED}Error:${NC} $*" >&2; exit 1; }
info()  { echo -e "${BLUE}::${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }

check_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found on PATH. Install Android platform tools."
}

# ──── Device listing ────

list_usb_devices() {
  adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" && !index($1,":") {print $1}'
}

list_wireless_devices() {
  adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" && index($1,":") {print $1}'
}

# ──── Device queries ────

device_model() {
  local serial="$1"
  adb -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo "?"
}

device_ip() {
  local serial="$1"
  if [[ "$serial" == *:* ]]; then
    echo "${serial%%:*}"
  else
    adb -s "$serial" shell ip addr show wlan0 2>/dev/null \
      | grep -o 'inet [0-9.]*' | head -1 | cut -d' ' -f2 || true
  fi
}

device_sdk()   { adb -s "$1" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r' || echo "?"; }
device_mfr()   { adb -s "$1" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r' || echo "?"; }
device_tid()   { adb devices -l 2>/dev/null | awk -v s="$1" '$1==s {for(i=3;i<=NF;i++) if($i ~ /^transport_id:/) {split($i,a,":"); print a[2]}}'; }

# ──── Build deduplicated device list ────
# Returns lines of: <ip>|<usb_serial|->|<wifi_serial|->|<model>|<mfr>
# Where USB+WiFi entries sharing the same IP are merged into one line.

collect_devices() {
  declare -A ip_usb    # ip → usb_serial
  declare -A ip_wifi   # ip → wifi_serial
  declare -A ip_model  # ip → model
  declare -A ip_mfr    # ip → manufacturer

  while IFS= read -r serial; do
    [[ -z "$serial" ]] && continue
    local ip; ip=$(device_ip "$serial") || true
    local model; model=$(device_model "$serial") || true
    local mfr; mfr=$(device_mfr "$serial") || true
    if [[ "$serial" == *:* ]]; then
      ip_wifi["$ip"]="$serial"
    else
      ip_usb["$ip"]="$serial"
    fi
    ip_model["$ip"]="$model"
    ip_mfr["$ip"]="$mfr"
  done < <(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')

  local all_ips=()
  for ip in "${!ip_usb[@]}"; do all_ips+=("$ip"); done
  for ip in "${!ip_wifi[@]}"; do
    local seen=false
    for s in "${all_ips[@]}"; do [[ "$s" == "$ip" ]] && seen=true && break; done
    $seen || all_ips+=("$ip")
  done

  for ip in "${all_ips[@]}"; do
    local usb="${ip_usb[$ip]:--}"
    local wifi="${ip_wifi[$ip]:--}"
    local model="${ip_model[$ip]:-?}"
    local mfr="${ip_mfr[$ip]:-?}"
    echo "$ip|$usb|$wifi|$model|$mfr"
  done
}

# ──── Screen ────

clear_screen() { printf '\033[2J\033[H'; }
pause() { echo ""; read -rp "Press Enter to continue..."; }

# ──── Tasks ────

task_show_info() {
  local ip="$1" usb="$2" wifi="$3" model="$4" mfr="$5"
  clear_screen
  echo "=== Device Info ==="
  printf "  %-14s %s\n" "Device:"    "$mfr $model"
  printf "  %-14s %s\n" "IP:"        "$ip"
  [[ "$usb"  != "-" ]] && printf "  %-14s %s\n" "USB:"   "$usb"   && printf "  %-14s %s\n" "USB TID:" "$(device_tid "$usb")"
  [[ "$wifi" != "-" ]] && printf "  %-14s %s\n" "WiFi:"  "$wifi"  && printf "  %-14s %s\n" "WiFi TID:" "$(device_tid "$wifi")"
  [[ "$usb"  != "-" ]] && printf "  %-14s %s\n" "SDK:"   "$(device_sdk "$usb")"
  pause
}

task_switch_to_wireless() {
  local serial="$1"
  local ip; ip=$(device_ip "$serial")
  if [[ -z "$ip" ]]; then
    warn "Could not determine device IP. Ensure WiFi is enabled."
    pause; return 1
  fi
  info "Switching $serial from USB to Wireless (IP: $ip)"
  if ! adb -s "$serial" tcpip 5555 >/dev/null 2>&1; then
    warn "adb tcpip failed."; pause; return 1
  fi
  info "Waiting for ADB to restart in TCP mode..."
  sleep 3
  info "Connecting to $ip:5555..."
  local result; result=$(adb connect "$ip:5555" 2>&1) || true
  echo "$result" | grep -qi "connected" && ok "Wireless: $ip:5555" || warn "$result"
  pause
}

task_switch_to_usb() {
  local serial="$1"
  info "Switching $serial to USB..."
  adb -s "$serial" usb >/dev/null 2>&1 && ok "Switched to USB." || warn "adb usb failed."
  pause
}

task_disconnect() {
  local serial="$1"
  info "Disconnecting $serial..."
  adb disconnect "$serial" >/dev/null 2>&1 || true
  ok "Disconnected $serial"
  pause
}

task_connect_wifi() {
  echo ""
  local usb_serials
  mapfile -t usb_serials < <(list_usb_devices)

  if [[ ${#usb_serials[@]} -eq 1 ]]; then
    local ser="${usb_serials[0]}"
    echo "USB device found: $ser ($(device_model "$ser"))"
    echo "  1) Switch to Wireless (adb tcpip)"
    echo "  2) Enter IP:port manually"
    read -rp "Choose [1/2]: " c
    if [[ "$c" == "2" ]]; then
      read -rp "Enter IP:port [10.0.0.6:5555]: " ep
      ep="${ep:-10.0.0.6:5555}"
      info "Connecting to $ep..."
      local r; r=$(adb connect "$ep" 2>&1) || true
      echo "$r" | grep -qi "connected" && ok "Connected" || warn "$r"
    else
      task_switch_to_wireless "$ser"
    fi
  else
    read -rp "Enter IP:port [10.0.0.6:5555]: " ep
    ep="${ep:-10.0.0.6:5555}"
    info "Connecting to $ep..."
    local r; r=$(adb connect "$ep" 2>&1) || true
    echo "$r" | grep -qi "connected" && ok "Connected" || warn "$r"
  fi
  pause
}

task_pair_and_connect() {
  echo ""
  echo "From Developer Options → Wireless debugging → Pair device"
  read -rp "Pairing IP:port (e.g. 10.0.0.6:37099): " pair_ep
  [[ -z "$pair_ep" ]] && { warn "No endpoint."; pause; return; }
  read -rp "6-digit code: " code
  [[ -z "$code" ]] && { warn "No code."; pause; return; }

  info "Pairing..."
  local r; r=$(adb pair "$pair_ep" "$code" 2>&1) || true
  if ! echo "$r" | grep -qi "success"; then
    warn "$r"; pause; return
  fi
  ok "Paired!"

  local base="${pair_ep%%:*}"
  read -rp "Connect IP:port [${base}:5555]: " conn
  conn="${conn:-${base}:5555}"
  info "Connecting..."
  local r2; r2=$(adb connect "$conn" 2>&1) || true
  echo "$r2" | grep -qi "connected" && ok "Connected" || warn "$r2"
  pause
}

task_connect_usb() {
  info "Plug in USB. Scanning..."
  local before; before=$(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}' | sort)
  for ((i=0; i<10; i++)); do
    sleep 1
    local after; after=$(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}' | sort)
    local new; new=$(comm -13 <(echo "$before") <(echo "$after") 2>/dev/null || true)
    if [[ -n "$new" ]]; then
      ok "New device:"; echo "$new"; pause; return
    fi
  done
  warn "No device detected in 10s."
  pause
}

# ──── Menus ────

device_menu() {
  local ip="$1" usb="$2" wifi="$3" model="$4" mfr="$5"

  local transport
  if [[ "$usb" != "-" && "$wifi" != "-" ]]; then transport="USB/WiFi"
  elif [[ "$usb" != "-" ]]; then transport="USB"
  else transport="WiFi"; fi

  while true; do
    clear_screen
    echo "  $mfr $model - $ip - $transport"
    echo ""
    echo "  1) Show device info"
    if [[ "$transport" == "USB/WiFi" ]]; then
      echo "  2) Disconnect wireless (keep USB)"
      echo "  3) Disconnect both"
    elif [[ "$transport" == "USB" ]]; then
      echo "  2) Switch to Wireless"
      echo "  3) Disconnect"
    else
      echo "  2) Switch to USB"
      echo "  3) Disconnect"
    fi
    echo "  4) Back"
    echo ""
    read -rp "Select [1-4]: " choice

    case "$choice" in
       1) task_show_info "$ip" "$usb" "$wifi" "$model" "$mfr" ;;
      2)
        if [[ "$transport" == "USB/WiFi" ]]; then
          task_disconnect "$wifi"
          wifi="-"; transport="USB"
        elif [[ "$transport" == "USB" ]]; then
          task_switch_to_wireless "$usb"
        else
          task_switch_to_usb "$wifi"
        fi
        # re-evaluate
        if [[ "$transport" == "USB" ]]; then
          wifi=$(list_wireless_devices | grep -F "${ip}:" 2>/dev/null || echo "-")
          [[ -n "$wifi" ]] && transport="USB/WiFi" || transport="USB"
        fi
        ;;
      3)
        if [[ "$transport" == "USB/WiFi" ]]; then
          task_disconnect "$wifi"
          task_disconnect "$usb"
        else
          local ser; [[ "$usb" != "-" ]] && ser="$usb" || ser="$wifi"
          task_disconnect "$ser"
        fi
        return ;;
      4) return ;;
      *) warn "Invalid."; sleep 1 ;;
    esac
  done
}

connect_menu() {
  while true; do
    clear_screen
    echo ""
    echo "  Connect New Device"
    echo ""
    echo "  1) Connect via Wi-Fi (adb connect)"
    echo "  2) Pair & connect (adb pair)"
    echo "  3) Connect via USB (plug in)"
    echo "  4) Back"
    echo ""
    read -rp "Select [1-4]: " choice

    case "$choice" in
      1) task_connect_wifi ;;
      2) task_pair_and_connect ;;
      3) task_connect_usb ;;
      4) return ;;
      *) warn "Invalid."; sleep 1 ;;
    esac
  done
}

main_menu() {
  check_adb

  while true; do
    clear_screen
    echo "ADB Connection Manager  v$VERSION"
    echo ""

    # Collect deduplicated devices
    local dev_lines=()
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      dev_lines+=("$line")
    done < <(collect_devices)

    echo "  1) Connect New Device"
    echo ""

    if [[ ${#dev_lines[@]} -gt 0 ]]; then
      local idx=2
      for line in "${dev_lines[@]}"; do
        local IFS='|'
        local parts=($line)
        local ip="${parts[0]}"
        local usb="${parts[1]}"
        local wifi="${parts[2]}"
        local model="${parts[3]}"
        local mfr="${parts[4]}"
        local tr
        if [[ "$usb" != "-" && "$wifi" != "-" ]]; then tr="USB/WiFi"
        elif [[ "$usb" != "-" ]]; then tr="USB"
        else tr="WiFi"; fi
        printf "  %d) %s %s - %s - %s\n" "$idx" "$mfr" "$model" "$ip" "$tr"
        ((idx++))
      done
    else
      echo "  (no devices)"
    fi

    echo ""
    read -rp "Select [1-$((1+${#dev_lines[@]})) or q]: " choice
    echo ""

    case "$choice" in
      q|Q) exit 0 ;;
      1) connect_menu ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 2 ]] && [[ "$choice" -le $((1+${#dev_lines[@]})) ]]; then
          local IFS='|'
          local parts=(${dev_lines[$((choice-2))]})
          device_menu "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}"
        else
          warn "Invalid."; sleep 1
        fi
        ;;
    esac
  done
}

main_menu
