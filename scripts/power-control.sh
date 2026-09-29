#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-get-state}"

case "$cmd" in
  get-state)
    # 1. Profile
    profile=$(powerprofilesctl get 2>/dev/null || echo "balanced")
    
    # 2. Battery & AC
    bat_cap=100
    bat_status="Unknown"
    bat_present=false
    ac_online=true

    if [[ -d /sys/class/power_supply/BAT1 ]]; then
      bat_present=true
      bat_cap=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100)
      bat_status=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Unknown")
    elif [[ -d /sys/class/power_supply/BAT0 ]]; then
      bat_present=true
      bat_cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
      bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
    fi

    if [[ -f /sys/class/power_supply/ADP1/online ]]; then
      [[ $(cat /sys/class/power_supply/ADP1/online) == "1" ]] && ac_online=true || ac_online=false
    elif [[ -f /sys/class/power_supply/AC/online ]]; then
      [[ $(cat /sys/class/power_supply/AC/online) == "1" ]] && ac_online=true || ac_online=false
    fi

    # 3. Idle from ~/.config/omarchy/shell.json
    shell_json="$HOME/.config/omarchy/shell.json"
    screensaver=150
    lock=300
    if [[ -f "$shell_json" ]]; then
      screensaver=$(jq -r '.idle.screensaver // 150' "$shell_json" 2>/dev/null || echo 150)
      lock=$(jq -r '.idle.lock // 300' "$shell_json" 2>/dev/null || echo 300)
    fi

    jq -n \
      --arg profile "$profile" \
      --argjson bat_present "$bat_present" \
      --argjson bat_cap "$bat_cap" \
      --arg bat_status "$bat_status" \
      --argjson ac_online "$ac_online" \
      --argjson screensaver "$screensaver" \
      --argjson lock "$lock" \
      '{
        profile: $profile,
        battery: {
          present: $bat_present,
          capacity: $bat_cap,
          status: $bat_status,
          acOnline: $ac_online
        },
        idle: {
          screensaver: $screensaver,
          lock: $lock
        }
      }'
    ;;

  set-profile)
    profile="${2:-}"
    if [[ "$profile" =~ ^(power-saver|balanced|performance)$ ]]; then
      powerprofilesctl set "$profile" >/dev/null 2>&1 || true
    fi
    ;;

  set-idle)
    screensaver="${2:-}"
    lock="${3:-}"
    shell_json="$HOME/.config/omarchy/shell.json"
    if [[ -f "$shell_json" && -n "$screensaver" && -n "$lock" ]]; then
      tmp_file="${shell_json}.tmp.$$"
      jq --argjson s "$screensaver" --argjson l "$lock" \
        '.idle.screensaver = $s | .idle.lock = $l' "$shell_json" > "$tmp_file" && mv "$tmp_file" "$shell_json"
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
