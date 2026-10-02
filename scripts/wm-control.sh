#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.local/state/omarchy/toggles/hypr"
PERSIST_LUA="$STATE_DIR/wm-settings.lua"
mkdir -p "$STATE_DIR"

ensure_persist_file() {
  if [[ ! -f "$PERSIST_LUA" ]]; then
    cat > "$PERSIST_LUA" << 'EOF'
-- Omarchy Window Manager Settings
hl.config({
  animations = {
    enabled = true,
  },
  general = {
    gaps_in = 5,
    gaps_out = 10,
    border_size = 2,
  },
  decoration = {
    rounding = 0,
    inactive_opacity = 1.0,
    blur = {
      enabled = false,
    },
  },
})
EOF
  fi
}

update_persist_lua() {
  local title="${1:-Window Manager Settings}"
  ensure_persist_file

  local snap=""
  if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
    snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$PERSIST_LUA" 2>/dev/null || true)
  fi

  local anim=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r 'if .bool != null then .bool else true end')
  local gaps_in_css=$(hyprctl getoption general:gaps_in -j 2>/dev/null | jq -r '.css // "5 5 5 5"')
  local gaps_in=$(echo "$gaps_in_css" | awk '{print $1}')
  local gaps_out_css=$(hyprctl getoption general:gaps_out -j 2>/dev/null | jq -r '.css // "10 10 10 10"')
  local gaps_out=$(echo "$gaps_out_css" | awk '{print $1}')
  local border=$(hyprctl getoption general:border_size -j 2>/dev/null | jq -r '.int // 2')
  local rounding=$(hyprctl getoption decoration:rounding -j 2>/dev/null | jq -r '.int // 0')
  local opacity=$(hyprctl getoption decoration:inactive_opacity -j 2>/dev/null | jq -r '.float // 1.0')
  local blur=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r 'if .bool != null then .bool else false end')

  cat > "$PERSIST_LUA" << EOF
-- Omarchy Window Manager Settings
hl.config({
  animations = {
    enabled = $anim,
  },
  general = {
    gaps_in = $gaps_in,
    gaps_out = $gaps_out,
    border_size = $border,
  },
  decoration = {
    rounding = $rounding,
    inactive_opacity = $opacity,
    blur = {
      enabled = $blur,
    },
  },
})
EOF

  if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
    "$SCRIPT_DIR/config-tracker.sh" record "windows" "$title" "$PERSIST_LUA" "$snap" >/dev/null 2>&1 || true
  fi
}

cmd_get_state() {
  local anim=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r 'if .bool != null then .bool else true end')
  local gaps_in_css=$(hyprctl getoption general:gaps_in -j 2>/dev/null | jq -r '.css // "5 5 5 5"')
  local gaps_in=$(echo "$gaps_in_css" | awk '{print $1}')
  local gaps_out_css=$(hyprctl getoption general:gaps_out -j 2>/dev/null | jq -r '.css // "10 10 10 10"')
  local gaps_out=$(echo "$gaps_out_css" | awk '{print $1}')
  local border=$(hyprctl getoption general:border_size -j 2>/dev/null | jq -r '.int // 2')
  local rounding=$(hyprctl getoption decoration:rounding -j 2>/dev/null | jq -r '.int // 0')
  local opacity=$(hyprctl getoption decoration:inactive_opacity -j 2>/dev/null | jq -r '.float // 1.0')
  local blur=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r 'if .bool != null then .bool else false end')

  local bar_hidden="false"
  if [[ -f "$HOME/.local/state/omarchy/toggles/bar-off" ]]; then
    bar_hidden="true"
  fi

  local shell_json="$HOME/.config/omarchy/shell.json"
  local bar_pos="top"
  local bar_trans="false"
  local show_pct="true"
  if [[ -f "$shell_json" ]]; then
    bar_pos=$(jq -r '.bar.position // "top"' "$shell_json" 2>/dev/null || echo "top")
    bar_trans=$(jq -r '.bar.transparent // false' "$shell_json" 2>/dev/null || echo "false")
    show_pct=$(jq -r '[.bar.layout.right[]? | select(.id == "omarchy.power") | .showPercentage] | if first != null then first else true end' "$shell_json" 2>/dev/null || echo "true")
  fi

  local single_aspect="false"
  if [[ -f "$HOME/.local/state/omarchy/toggles/hypr/single-window-aspect-ratio.lua" ]]; then
    single_aspect="true"
  fi

  local ws_layout=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.tiledLayout // "dwindle"')

  jq -n \
    --argjson anim "$anim" \
    --argjson gapsIn "$gaps_in" \
    --argjson gapsOut "$gaps_out" \
    --argjson border "$border" \
    --argjson rounding "$rounding" \
    --argjson opacity "$opacity" \
    --argjson blur "$blur" \
    --argjson barHidden "$bar_hidden" \
    --arg barPos "$bar_pos" \
    --argjson barTrans "$bar_trans" \
    --argjson showPct "$show_pct" \
    --argjson singleAspect "$single_aspect" \
    --arg wsLayout "$ws_layout" \
    '{
      animations: $anim,
      gapsIn: $gapsIn,
      gapsOut: $gapsOut,
      borderSize: $border,
      rounding: $rounding,
      inactiveOpacity: $opacity,
      blur: $blur,
      barHidden: $barHidden,
      barPosition: $barPos,
      barTransparent: $barTrans,
      showPercentage: $showPct,
      singleWindowAspect: $singleAspect,
      workspaceLayout: $wsLayout
    }'
}

case "${1:-get-state}" in
  get-state)
    cmd_get_state
    ;;

  set-animations)
    val="${2:-true}"
    hyprctl eval "hl.config({ animations = { enabled = $val } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-gaps)
    gin="${2:-5}"
    gout="${3:-10}"
    hyprctl eval "hl.config({ general = { gaps_in = $gin, gaps_out = $gout } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-border-size)
    bsize="${2:-2}"
    hyprctl eval "hl.config({ general = { border_size = $bsize } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-rounding)
    rad="${2:-0}"
    hyprctl eval "hl.config({ decoration = { rounding = $rad } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-inactive-opacity)
    op="${2:-1.0}"
    hyprctl eval "hl.config({ decoration = { inactive_opacity = $op } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-blur)
    val="${2:-false}"
    hyprctl eval "hl.config({ decoration = { blur = { enabled = $val } } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  toggle-bar)
    omarchy-toggle bar-off toggle
    omarchy-shell -q omarchy.bar syncHidden 2>/dev/null || true
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record-command "windows" "Toggle Omarchy Bar" "omarchy-shell" "omarchy-toggle bar-off toggle" "Toggled bar visibility" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  set-bar-position)
    pos="${2:-top}"
    shell_json="$HOME/.config/omarchy/shell.json"
    snap=""
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$shell_json" ]]; then
      snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$shell_json" 2>/dev/null || true)
    fi
    omarchy bar position "$pos" 2>/dev/null || true
    if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record "windows" "Bar Position ($pos)" "$shell_json" "$snap" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  toggle-bar-transparent)
    shell_json="$HOME/.config/omarchy/shell.json"
    snap=""
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$shell_json" ]]; then
      snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$shell_json" 2>/dev/null || true)
    fi
    cur=$(jq -r '.bar.transparent // false' "$shell_json" 2>/dev/null || echo "false")
    if [[ "$cur" == "true" ]]; then
      omarchy bar transparent false 2>/dev/null || true
    else
      omarchy bar transparent true 2>/dev/null || true
    fi
    if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record "windows" "Bar Transparency" "$shell_json" "$snap" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  toggle-battery-percentage)
    shell_json="$HOME/.config/omarchy/shell.json"
    snap=""
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$shell_json" ]]; then
      snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$shell_json" 2>/dev/null || true)
    fi
    omarchy-shell omarchy.power togglePercentage 2>/dev/null || true
    if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record "windows" "Battery Percentage Indicator" "$shell_json" "$snap" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  toggle-single-window-aspect)
    omarchy-hyprland-window-single-square-aspect-toggle >/dev/null 2>&1 || true
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record-command "windows" "Single Window Aspect Ratio" "hyprland" "omarchy-hyprland-window-single-square-aspect-toggle" "Toggled square aspect ratio" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  toggle-workspace-layout)
    omarchy-hyprland-workspace-layout-toggle >/dev/null 2>&1 || true
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record-command "windows" "Workspace Layout" "hyprland" "omarchy-hyprland-workspace-layout-toggle" "Switched workspace tiling layout" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  *)
    echo "Unknown command: ${1:-}" >&2
    exit 1
    ;;
esac
