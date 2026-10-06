#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cmd="${1:-get-state}"

case "$cmd" in
  get-state)
    brightness=$(omarchy brightness display 2>/dev/null || echo "100")
    if [[ -z "$brightness" || "$brightness" == "0" ]]; then
      brightness="100"
    fi

    monitors=$(hyprctl monitors all -j 2>/dev/null || echo "[]")
    nightlight=$(omarchy-toggle-nightlight --status 2>/dev/null || echo '{"enabled":false,"temperature":6500}')

    jq -n \
      --argjson brightness "$brightness" \
      --argjson monitors "$monitors" \
      --argjson nightlight "$nightlight" \
      '{
        brightness: ($brightness | tonumber),
        nightlight: $nightlight,
        monitors: [
          $monitors[] | {
            id: .id,
            name: .name,
            make: .make,
            model: .model,
            description: .description,
            width: .width,
            height: .height,
            refreshRate: (.refreshRate | round),
            scale: .scale,
            focused: .focused,
            modes: (.availableModes // [])
          }
        ]
      }'
    ;;

  set-nightlight-toggle)
    omarchy-toggle-nightlight >/dev/null 2>&1 || true
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record-command "displays" "Night Light Toggle" "hyprsunset" "omarchy-toggle-nightlight" "Toggled night light" >/dev/null 2>&1 || true
    fi
    ;;

  set-nightlight-temp)
    temp="${2:-4000}"
    if ! pgrep -x hyprsunset >/dev/null; then
      setsid uwsm-app -- hyprsunset &
    fi
    for _ in {1..5}; do
      hyprctl hyprsunset temperature "$temp" >/dev/null 2>&1 || true
      sleep 0.1
      curr=$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE '[0-9]+' | head -n1 || echo "")
      [[ "$curr" == "$temp" ]] && break
    done
    omarchy-shell -q nightlight refresh >/dev/null 2>&1 || true
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record-command "displays" "Night Light Temperature" "hyprsunset" "hyprctl hyprsunset temperature $temp" "Set screen temperature to ${temp}K" >/dev/null 2>&1 || true
    fi
    ;;

  set-brightness)
    val="${2:-}"
    if [[ -n "$val" ]]; then
      num=$(printf '%.0f' "$val")
      if (( num < 5 )); then num=5; fi
      if (( num > 100 )); then num=100; fi
      omarchy brightness display --no-osd "${num}%" >/dev/null 2>&1 || true
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "displays" "Display Brightness" "brightnessctl" "omarchy brightness display ${num}%" "Set display brightness to ${num}%" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  set-scale)
    scale="${2:-}"
    monitor="${3:-}"
    if [[ -z "$monitor" ]]; then
      monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '(.[] | select(.focused == true) | .name) // .[0].name // empty' | head -n1)
    fi
    if [[ -n "$scale" ]]; then
      lua_file="$HOME/.config/hypr/monitors.lua"
      snap=""
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$lua_file" ]]; then
        snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$lua_file" 2>/dev/null || true)
      fi

      monitor_info=$(hyprctl monitors -j 2>/dev/null | jq -e -c --arg m "$monitor" '(.[] | select(.name == $m)) // (.[] | select(.focused == true)) // .[0]' 2>/dev/null || echo "{}")
      mon_w=$(echo "$monitor_info" | jq -r '.width // 1920' 2>/dev/null || echo "1920")
      mon_h=$(echo "$monitor_info" | jq -r '.height // 1080' 2>/dev/null || echo "1080")

      clean_s=$(awk -v scale="$scale" -v width="$mon_w" -v height="$mon_h" '
        function gcd(a, b, t) { while (b) { t = a % b; a = b; b = t } return a }
        BEGIN {
          g = gcd(width * 120, height * 120)
          k = int(scale * 120 + 0.5)
          if (k > g) k = g
          while (g % k != 0) k++
          printf "%g\n", k / 120
        }')
      [[ -z "$clean_s" ]] && clean_s="$scale"

      # 1. Omarchy scaling utility sets GDK_SCALE and writes to audit logs
      omarchy hyprland monitor scaling "$clean_s" >/dev/null 2>&1 || true

      # 2. Get current active mode for this monitor so we preserve active resolution
      mode=$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$monitor" '
        (.[] | select(.name == $m) | "\(.width)x\(.height)@\(.refreshRate | round)") // "preferred"
      ' | head -n1)
      if [[ -z "$mode" || "$mode" == "@" || "$mode" == "0x0@0" ]]; then
        mode="preferred"
      fi

      # 3. Modern Hyprland eval for Lua configuration
      if [[ -n "$monitor" ]]; then
        hyprctl eval "hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $clean_s })" >/dev/null 2>&1 || true
        hyprctl eval "hl.dsp.window.center()" >/dev/null 2>&1 || true
      fi

      # 4. Persist to monitors.lua specifically for this monitor so subsequent reloads don't revert to scale 1
      if [[ -f "$lua_file" && -n "$monitor" ]]; then
        if grep -q "output = \"$monitor\"" "$lua_file" 2>/dev/null; then
          sed -i -E "s|hl\.monitor\(\{[^}]*output = \"$monitor\"[^}]*\}.*|hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $clean_s })|g" "$lua_file"
        else
          echo "hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $clean_s })" >> "$lua_file"
        fi
      fi

      # 5. Keep omarchy_monitor_scale and omarchy_gdk_scale in sync if present
      if [[ -f "$lua_file" ]] && grep -q '^local omarchy_monitor_scale = ' "$lua_file"; then
        gdk_scale=$(awk -v s="$clean_s" 'BEGIN { printf "%d", int(s + 0.5) }')
        sed -i -E \
          -e "s|^local omarchy_monitor_scale = .*|local omarchy_monitor_scale = ${clean_s}|" \
          -e "s|^local omarchy_gdk_scale = .*|local omarchy_gdk_scale = ${gdk_scale}|" \
          "$lua_file"
      fi

      if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record "displays" "Display Scaling ($clean_s)" "$lua_file" "$snap" >/dev/null 2>&1 || true
      elif [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "displays" "Display Scaling ($clean_s)" "hyprctl" "omarchy hyprland monitor scaling $clean_s" "Set display scale to $clean_s" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  set-mode)
    monitor="${2:-}"
    mode="${3:-}"
    scale="${4:-}"
    if [[ -z "$monitor" ]]; then
      monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '(.[] | select(.focused == true) | .name) // .[0].name // empty' | head -n1)
    fi
    if [[ -z "$scale" ]]; then
      scale=$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$monitor" '(.[] | select(.name == $m) | .scale) // empty' | head -n1)
      [[ -z "$scale" || "$scale" == "null" ]] && scale="1"
    fi
    if [[ -n "$monitor" && -n "$mode" ]]; then
      # Modern Hyprland eval for Lua configuration
      hyprctl eval "hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $scale })" >/dev/null 2>&1 || true
      hyprctl eval "hl.dsp.window.center()" >/dev/null 2>&1 || true
      
      # Persist to monitors.lua
      lua_file="$HOME/.config/hypr/monitors.lua"
      snap=""
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        mkdir -p "$(dirname "$lua_file")"
        touch "$lua_file"
        snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$lua_file" 2>/dev/null || true)
      fi
      if grep -q "output = \"$monitor\"" "$lua_file" 2>/dev/null; then
        sed -i -E "s|hl\.monitor\(\{[^}]*output = \"$monitor\"[^}]*\}.*|hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $scale })|g" "$lua_file"
      else
        echo "hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $scale })" >> "$lua_file"
      fi
      if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record "displays" "Display Resolution ($mode)" "$lua_file" "$snap" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
