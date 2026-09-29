#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-get-state}"

case "$cmd" in
  get-state)
    show_out=$(bluetoothctl show 2>/dev/null || true)
    powered_val=$(echo "$show_out" | grep -E "^[[:space:]]*Powered:" | awk '{print $2}' || echo "no")
    discovering_val=$(echo "$show_out" | grep -E "^[[:space:]]*Discovering:" | awk '{print $2}' || echo "no")
    adapter_name=$(echo "$show_out" | grep -E "^[[:space:]]*Alias:" | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//' || echo "")
    adapter_mac=$(echo "$show_out" | grep -E "^Controller " | head -n1 | awk '{print $2}' || echo "")

    is_powered=false
    [[ "$powered_val" == "yes" ]] && is_powered=true

    is_discovering=false
    [[ "$discovering_val" == "yes" ]] && is_discovering=true

    devices_json="[]"
    if [[ "$is_powered" == "true" ]]; then
      connected_macs=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}' || echo "")
      paired_macs=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' || echo "")

      devices_json=$(bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
        if [[ -z "$mac" ]]; then continue; fi
        is_conn=false
        is_pair=false
        echo "$connected_macs" | grep -q "$mac" && is_conn=true
        echo "$paired_macs" | grep -q "$mac" && is_pair=true
        icon_type=$(bluetoothctl info "$mac" 2>/dev/null | grep -E "^[[:space:]]*Icon:" | awk '{print $2}' || echo "bluetooth")
        printf "%s\t%s\t%s\t%s\t%s\n" "$mac" "$name" "$is_conn" "$is_pair" "$icon_type"
      done | jq -R 'split("\t") | {mac: .[0], name: .[1], connected: (.[2] == "true"), paired: (.[3] == "true"), iconType: .[4]}' | jq -s 'sort_by(-(.connected | if . then 2 else 0 end) - (.paired | if . then 1 else 0 end))' || echo "[]")
    fi

    jq -n \
      --argjson powered "$is_powered" \
      --argjson discovering "$is_discovering" \
      --arg adapterName "$adapter_name" \
      --arg adapterMac "$adapter_mac" \
      --argjson devices "$devices_json" \
      '{
        powered: $powered,
        discovering: $discovering,
        adapter: {
          name: $adapterName,
          mac: $adapterMac
        },
        devices: ($devices // [])
      }'
    ;;

  bluetooth-toggle)
    show_out=$(bluetoothctl show 2>/dev/null || true)
    powered=$(echo "$show_out" | grep -E "^[[:space:]]*Powered:" | awk '{print $2}' || echo "no")
    if [[ "$powered" == "yes" ]]; then
      bluetoothctl power off >/dev/null 2>&1 || true
    else
      bluetoothctl power on >/dev/null 2>&1 || true
    fi
    ;;

  scan-trigger)
    # Run scan for 4 seconds in background to refresh available devices
    ( bluetoothctl --timeout 4 scan on >/dev/null 2>&1 || true ) &
    ;;

  device-toggle)
    mac="${2:-}"
    if [[ -n "$mac" ]]; then
      if bluetoothctl devices Connected 2>/dev/null | grep -q "$mac"; then
        bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
      else
        bluetoothctl connect "$mac" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  device-pair)
    mac="${2:-}"
    if [[ -n "$mac" ]]; then
      bluetoothctl pair "$mac" >/dev/null 2>&1 || true
      bluetoothctl trust "$mac" >/dev/null 2>&1 || true
      bluetoothctl connect "$mac" >/dev/null 2>&1 || true
    fi
    ;;

  device-remove)
    mac="${2:-}"
    if [[ -n "$mac" ]]; then
      bluetoothctl remove "$mac" >/dev/null 2>&1 || true
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
