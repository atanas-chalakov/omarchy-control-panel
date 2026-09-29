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
    
    jq -n \
      --argjson brightness "$brightness" \
      --argjson monitors "$monitors" \
      '{
        brightness: ($brightness | tonumber),
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

  set-brightness)
    val="${2:-}"
    if [[ -n "$val" ]]; then
      # Clamp between 5 and 100
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
      hyprctl keyword monitor "${monitor},${mode},auto,${scale}" >/dev/null 2>&1 || true
      # Update monitors.lua if present
      lua_file="$HOME/.config/hypr/monitors.lua"
      if [[ -f "$lua_file" ]]; then
        # Update or set the monitor definition
        if grep -q "output = \"$monitor\"" "$lua_file"; then
          sed -i -E "s|hl\.monitor\(\{ output = \"$monitor\", mode = \"[^\"]+\"|hl.monitor({ output = \"$monitor\", mode = \"$mode\"|" "$lua_file"
        fi
      fi
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
