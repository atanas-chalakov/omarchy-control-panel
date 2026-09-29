#!/usr/bin/env bash
set -euo pipefail

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
    ;;

  set-brightness)
    val="${2:-}"
    if [[ -n "$val" ]]; then
      num=$(printf '%.0f' "$val")
      if (( num < 5 )); then num=5; fi
      if (( num > 100 )); then num=100; fi
      omarchy brightness display --no-osd "${num}%" >/dev/null 2>&1 || true
    fi
    ;;

  set-scale)
    scale="${2:-}"
    if [[ -n "$scale" ]]; then
      omarchy hyprland monitor scaling "$scale" >/dev/null 2>&1 || true
    fi
    ;;

  set-mode)
    monitor="${2:-}"
    mode="${3:-}"
    scale="${4:-1}"
    if [[ -n "$monitor" && -n "$mode" ]]; then
      # Modern Hyprland eval for Lua configuration
      hyprctl eval "hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $scale })" >/dev/null 2>&1 || true
      
      # Persist to monitors.lua
      lua_file="$HOME/.config/hypr/monitors.lua"
      if [[ -f "$lua_file" ]]; then
        if grep -q "output = \"$monitor\"" "$lua_file"; then
          sed -i -E "s|hl\.monitor\(\{ output = \"$monitor\", mode = \"[^\"]+\"|hl.monitor({ output = \"$monitor\", mode = \"$mode\"|" "$lua_file"
        else
          echo "hl.monitor({ output = \"$monitor\", mode = \"$mode\", position = \"auto\", scale = $scale })" >> "$lua_file"
        fi
      fi
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
