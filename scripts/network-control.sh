#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cmd="${1:-get-state}"

case "$cmd" in
  get-state)
    wifi_status=$(nmcli -t radio wifi 2>/dev/null || echo "disabled")
    wifi_enabled=false
    [[ "$wifi_status" == "enabled" ]] && wifi_enabled=true

    active_dev=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}' || echo "")
    active_json="null"

    if [[ -n "$active_dev" && "$wifi_enabled" == "true" ]]; then
      ssid=$(nmcli -t -f in-use,ssid dev wifi list --rescan no 2>/dev/null | awk -F: '$1 ~ /\*/{print $2; exit}' || echo "")
      ip=$(nmcli -t -f IP4.ADDRESS dev show "$active_dev" 2>/dev/null | head -n1 | cut -d: -f2 | cut -d/ -f1 || echo "")
      
      # Try omarchy-network-status for extra details like signal & frequency
      net_status=$(omarchy-network-status 2>/dev/null || echo "")
      sig=$(echo "$net_status" | awk '{print $3}')
      freq=$(echo "$net_status" | awk '{print $4}')
      [[ -z "$sig" ]] && sig=100
      [[ -z "$freq" ]] && freq="2.4GHz"

      active_json=$(jq -n \
        --arg dev "$active_dev" \
        --arg ssid "$ssid" \
        --arg ip "$ip" \
        --argjson signal "${sig:-100}" \
        --arg freq "$freq" \
        '{
          device: $dev,
          ssid: $ssid,
          ip: $ip,
          signal: ($signal | tonumber),
          frequency: $freq
        }')
    fi

    networks_json="[]"
    if [[ "$wifi_enabled" == "true" ]]; then
      networks_json=$(nmcli -t -f in-use,ssid,signal,security dev wifi list --rescan no 2>/dev/null | awk -F: '
        {
          in_use = ($1 ~ /\*/) ? "true" : "false"
          ssid = $2
          if (ssid == "" || ssid == "--") next
          signal = $3
          security = $4
          if (seen[ssid] && seen_signal[ssid] >= signal) next
          seen[ssid] = 1
          seen_signal[ssid] = signal
          printf "%s\t%s\t%s\t%s\n", in_use, ssid, signal, security
        }
      ' | jq -R 'split("\t") | {inUse: (.[0] == "true"), ssid: .[1], signal: (.[2] | tonumber), security: .[3]}' | jq -s 'sort_by(-.signal)' || echo "[]")
    fi

    jq -n \
      --argjson enabled "$wifi_enabled" \
      --argjson active "$active_json" \
      --argjson networks "$networks_json" \
      '{
        enabled: $enabled,
        active: $active,
        networks: ($networks // [])
      }'
    ;;

  wifi-toggle)
    current=$(nmcli -t radio wifi 2>/dev/null || echo "disabled")
    if [[ "$current" == "enabled" ]]; then
      nmcli radio wifi off >/dev/null 2>&1 || true
      action="off"
    else
      nmcli radio wifi on >/dev/null 2>&1 || true
      action="on"
    fi
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record-command "network" "Wi-Fi Power ($action)" "NetworkManager" "nmcli radio wifi $action" "Turned Wi-Fi $action" >/dev/null 2>&1 || true
    fi
    ;;

  wifi-rescan)
    nmcli dev wifi rescan >/dev/null 2>&1 || true
    ;;

  wifi-connect)
    ssid="${2:-}"
    pass="${3:-}"
    if [[ -n "$ssid" ]]; then
      if [[ -n "$pass" ]]; then
        nmcli dev wifi connect "$ssid" password "$pass" >/dev/null 2>&1 || true
      else
        nmcli dev wifi connect "$ssid" >/dev/null 2>&1 || true
      fi
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "network" "Wi-Fi Connection ($ssid)" "NetworkManager" "nmcli dev wifi connect $ssid" "Connected to SSID $ssid" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  wifi-disconnect)
    active_dev=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}' || echo "")
    if [[ -n "$active_dev" ]]; then
      nmcli dev disconnect "$active_dev" >/dev/null 2>&1 || true
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "network" "Wi-Fi Disconnect ($active_dev)" "NetworkManager" "nmcli dev disconnect $active_dev" "Disconnected from Wi-Fi" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
