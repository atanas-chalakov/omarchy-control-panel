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

    # 5. Gaming & High Performance Mode
    game_mode=false
    [[ -f "$HOME/.local/state/omarchy/toggles/game-mode" ]] && game_mode=true

    jq -n \
      --arg profile "$profile" \
      --argjson bat_present "$bat_present" \
      --argjson bat_cap "$bat_cap" \
      --arg bat_status "$bat_status" \
      --argjson ac_online "$ac_online" \
      --argjson screensaver "$screensaver" \
      --argjson lock "$lock" \
      --argjson stay_awake "$stay_awake" \
      --argjson gameMode "$game_mode" \
      '{
        profile: $profile,
        stayAwake: $stay_awake,
        gameMode: $gameMode,
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

  set-game-mode)
    action="${2:-toggle}"
    mkdir -p "$HOME/.local/state/omarchy/toggles"
    game_file="$HOME/.local/state/omarchy/toggles/game-mode"
    
    current=false
    [[ -f "$game_file" ]] && current=true
    
    target=false
    if [[ "$action" == "enable" || "$action" == "on" ]]; then
      target=true
    elif [[ "$action" == "disable" || "$action" == "off" ]]; then
      target=false
    elif [[ "$action" == "toggle" ]]; then
      [[ "$current" == "true" ]] && target=false || target=true
    fi

    if [[ "$target" == "true" ]]; then
      prev_profile=$(powerprofilesctl get 2>/dev/null || echo "balanced")
      printf '%s\n' "$prev_profile" > "$HOME/.local/state/omarchy/toggles/game-mode-prev-profile"
      touch "$game_file"
      
      powerprofilesctl set performance >/dev/null 2>&1 || true
      omarchy-toggle-idle enable >/dev/null 2>&1 || true
      hyprctl --batch "keyword animations:enabled 0; keyword decoration:blur:enabled 0; keyword decoration:drop_shadow 0; keyword misc:vfr 0" >/dev/null 2>&1 || true
      
      touch "$HOME/.local/state/omarchy/toggles/notifications-dnd-gamemode"
      if command -v makoctl >/dev/null 2>&1; then
        makoctl mode -a dnd >/dev/null 2>&1 || true
      fi

      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "power" "Gaming Mode Enabled" "game-mode" "scripts/power-control.sh set-game-mode enable" "Switched to performance governor, disabled animations & blur, inhibited idle, and activated DND" >/dev/null 2>&1 || true
      fi
      echo '{"success":true,"gameMode":true}'
    else
      rm -f "$game_file"
      prev_profile="balanced"
      if [[ -f "$HOME/.local/state/omarchy/toggles/game-mode-prev-profile" ]]; then
        prev_profile=$(cat "$HOME/.local/state/omarchy/toggles/game-mode-prev-profile" 2>/dev/null || echo "balanced")
        rm -f "$HOME/.local/state/omarchy/toggles/game-mode-prev-profile"
      fi
      powerprofilesctl set "$prev_profile" >/dev/null 2>&1 || true
      omarchy-toggle-idle disable >/dev/null 2>&1 || true
      hyprctl reload >/dev/null 2>&1 || true
      
      if [[ -f "$HOME/.local/state/omarchy/toggles/notifications-dnd-gamemode" ]]; then
        rm -f "$HOME/.local/state/omarchy/toggles/notifications-dnd-gamemode"
        if command -v makoctl >/dev/null 2>&1; then
          makoctl mode -r dnd >/dev/null 2>&1 || true
        fi
      fi

      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "power" "Gaming Mode Disabled" "game-mode" "scripts/power-control.sh set-game-mode disable" "Restored $prev_profile governor, re-enabled animations and notification alerts" >/dev/null 2>&1 || true
      fi
      echo '{"success":true,"gameMode":false}'
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
      (
        umask 077
        jq --argjson s "$actual_screensaver" --argjson l "$actual_lock" \
          '.idle.screensaver = $s | .idle.lock = $l' "$shell_json" > "$tmp_file"
      )
      chmod 600 "$tmp_file" 2>/dev/null || true
      mv "$tmp_file" "$shell_json"

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
