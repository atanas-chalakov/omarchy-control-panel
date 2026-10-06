#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

    # If screensaver-off toggle is active, report 0 (Never)
    if [[ -f "$HOME/.local/state/omarchy/toggles/screensaver-off" ]] || omarchy-toggle-enabled screensaver-off 2>/dev/null; then
      screensaver=0
    elif (( screensaver == 0 )); then
      screensaver=0
    fi

    # Lock >= 86400 is treated as Never (0)
    if (( lock >= 86400 || lock == 0 )); then
      lock=0
    fi

    # 4. Stay Awake (Inhibit Idle / Sleep)
    stay_awake=$(omarchy-toggle-idle status 2>/dev/null | jq -r '.enabled // false' 2>/dev/null || echo "false")
    [[ "$stay_awake" == "true" ]] && stay_awake=true || stay_awake=false

    jq -n \
      --arg profile "$profile" \
      --argjson bat_present "$bat_present" \
      --argjson bat_cap "$bat_cap" \
      --arg bat_status "$bat_status" \
      --argjson ac_online "$ac_online" \
      --argjson screensaver "$screensaver" \
      --argjson lock "$lock" \
      --argjson stay_awake "$stay_awake" \
      '{
        profile: $profile,
        stayAwake: $stay_awake,
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

  set-stay-awake)
    action="${2:-toggle}"
    omarchy-toggle-idle "$action" >/dev/null 2>&1 || true
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      cur_state="disabled"
      [[ -f "$HOME/.local/state/omarchy/indicators/stay-awake" ]] && cur_state="enabled (idle inhibited)"
      "$SCRIPT_DIR/config-tracker.sh" record-command "power" "Stay Awake (Idle Inhibition)" "omarchy-toggle-idle" "omarchy-toggle-idle $action" "Stay Awake set to $cur_state" >/dev/null 2>&1 || true
    fi
    ;;

  set-profile)
    profile="${2:-}"
    if [[ "$profile" =~ ^(power-saver|balanced|performance)$ ]]; then
      powerprofilesctl set "$profile" >/dev/null 2>&1 || true
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "power" "Power Profile" "powerprofilesctl" "powerprofilesctl set $profile" "Governor switched to $profile" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  set-idle)
    screensaver="${2:-}"
    lock="${3:-}"
    shell_json="$HOME/.config/omarchy/shell.json"

    snap=""
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$shell_json" ]]; then
      snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$shell_json" 2>/dev/null || true)
    fi

    # 1. Screensaver handling (0 = Never -> screensaver-off toggle)
    if [[ "$screensaver" == "0" ]]; then
      mkdir -p "$HOME/.local/state/omarchy/toggles"
      touch "$HOME/.local/state/omarchy/toggles/screensaver-off"
      actual_screensaver=150
    else
      rm -f "$HOME/.local/state/omarchy/toggles/screensaver-off"
      actual_screensaver="$screensaver"
    fi

    # 2. Lock handling (0 = Never -> 86400s)
    if [[ "$lock" == "0" ]]; then
      actual_lock=86400
    else
      actual_lock="$lock"
    fi

    if [[ -f "$shell_json" && -n "$actual_screensaver" && -n "$actual_lock" ]]; then
      tmp_file="${shell_json}.tmp.$$"
      jq --argjson s "$actual_screensaver" --argjson l "$actual_lock" \
        '.idle.screensaver = $s | .idle.lock = $l' "$shell_json" > "$tmp_file" && mv "$tmp_file" "$shell_json"

      if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record "power" "Screen Idle & Lock Timeouts" "$shell_json" "$snap" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
