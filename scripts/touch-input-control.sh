#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="$HOME/.local/state/omarchy/toggles/hypr"
PERSIST_LUA="$STATE_DIR/touch-settings.lua"
mkdir -p "$STATE_DIR"

ensure_persist_file() {
  if [[ ! -f "$PERSIST_LUA" ]]; then
    cat > "$PERSIST_LUA" << 'EOF'
-- Omarchy Touch & Input Settings
hl.config({
  input = {
    touchpad = {
      natural_scroll = false,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
      disable_while_typing = false,
    },
    sensitivity = 0.0,
  },
  gestures = {
    workspace_swipe_touch = false,
  },
})
EOF
  fi
}

update_persist_lua() {
  ensure_persist_file

  # Read current hyprctl values
  local nat_scroll=$(hyprctl getoption input:touchpad:natural_scroll -j 2>/dev/null | jq -r '.bool // false')
  local clickfinger=$(hyprctl getoption input:touchpad:clickfinger_behavior -j 2>/dev/null | jq -r '.bool // true')
  local scroll_factor=$(hyprctl getoption input:touchpad:scroll_factor -j 2>/dev/null | jq -r '.float // 0.4')
  local dwt=$(hyprctl getoption input:touchpad:disable_while_typing -j 2>/dev/null | jq -r '.bool // false')
  local swipe_touch=$(hyprctl getoption gestures:workspace_swipe_touch -j 2>/dev/null | jq -r '.bool // false')
  local sens=$(hyprctl getoption input:sensitivity -j 2>/dev/null | jq -r '.float // 0.0')
  local touch_out=$(hyprctl getoption input:touchdevice:output -j 2>/dev/null | jq -r '.str // "[[Auto]]"')

  local out_clause=""
  if [[ "$touch_out" != "[[Auto]]" && -n "$touch_out" ]]; then
    out_clause="touchdevice = { output = \"$touch_out\" },"
  fi

  cat > "$PERSIST_LUA" << EOF
-- Omarchy Touch & Input Settings
hl.config({
  input = {
    touchpad = {
      natural_scroll = $nat_scroll,
      clickfinger_behavior = $clickfinger,
      scroll_factor = $scroll_factor,
      disable_while_typing = $dwt,
    },
    $out_clause
    sensitivity = $sens,
  },
  gestures = {
    workspace_swipe_touch = $swipe_touch,
  },
})
EOF
}

cmd_get_state() {
  # Detect touchscreen hardware
  local ts_dev=""
  if command -v omarchy-hw-touchscreen >/dev/null 2>&1; then
    ts_dev=$(omarchy-hw-touchscreen 2>/dev/null || true)
  fi
  if [[ -z "$ts_dev" ]]; then
    ts_dev=$(hyprctl devices -j 2>/dev/null | jq -r '[.touch[]?.name, .tablets[]?.name] | first // empty' || true)
  fi

  local ts_present="false"
  local ts_enabled="true"
  if [[ -n "$ts_dev" ]]; then
    ts_present="true"
    if [[ -f "$STATE_DIR/touchscreen-disabled-name" ]]; then
      ts_enabled="false"
    fi
  fi

  # Detect touchpad hardware
  local tp_dev=""
  if command -v omarchy-hw-touchpad >/dev/null 2>&1; then
    tp_dev=$(omarchy-hw-touchpad 2>/dev/null || true)
  fi
  if [[ -z "$tp_dev" ]]; then
    tp_dev=$(hyprctl devices -j 2>/dev/null | jq -r '[.mice[]?.name | select(test("touchpad|trackpad"; "i"))] | first // empty' || true)
  fi

  local tp_present="false"
  local tp_enabled="true"
  if [[ -n "$tp_dev" ]]; then
    tp_present="true"
    if [[ -f "$STATE_DIR/touchpad-disabled-name" ]]; then
      tp_enabled="false"
    fi
  fi

  # Options
  local nat_scroll=$(hyprctl getoption input:touchpad:natural_scroll -j 2>/dev/null | jq -r '.bool // false')
  local clickfinger=$(hyprctl getoption input:touchpad:clickfinger_behavior -j 2>/dev/null | jq -r '.bool // true')
  local scroll_factor=$(hyprctl getoption input:touchpad:scroll_factor -j 2>/dev/null | jq -r '.float // 0.4')
  local dwt=$(hyprctl getoption input:touchpad:disable_while_typing -j 2>/dev/null | jq -r '.bool // false')
  local swipe_touch=$(hyprctl getoption gestures:workspace_swipe_touch -j 2>/dev/null | jq -r '.bool // false')
  local sens=$(hyprctl getoption input:sensitivity -j 2>/dev/null | jq -r '.float // 0.0')
  local touch_out=$(hyprctl getoption input:touchdevice:output -j 2>/dev/null | jq -r '.str // "[[Auto]]"')

  # Monitors
  local monitors=$(hyprctl monitors -j 2>/dev/null | jq -c '[.[].name]' || echo '[]')

  # Virtual keyboard status
  local vk_present="false"
  if hyprctl devices -j 2>/dev/null | jq -e '.keyboards[]? | select(.name | test("virtual|fcitx|wvkbd"; "i"))' >/dev/null 2>&1; then
    vk_present="true"
  fi

  jq -n \
    --arg ts_present "$ts_present" \
    --arg ts_name "$ts_dev" \
    --arg ts_enabled "$ts_enabled" \
    --arg tp_present "$tp_present" \
    --arg tp_name "$tp_dev" \
    --arg tp_enabled "$tp_enabled" \
    --argjson nat_scroll "$nat_scroll" \
    --argjson clickfinger "$clickfinger" \
    --argjson scroll_factor "$scroll_factor" \
    --argjson dwt "$dwt" \
    --argjson swipe_touch "$swipe_touch" \
    --argjson sens "$sens" \
    --arg touch_out "$touch_out" \
    --argjson monitors "$monitors" \
    --argjson vk_present "$vk_present" \
    '{
      touchscreen: {
        present: ($ts_present == "true"),
        name: $ts_name,
        enabled: ($ts_enabled == "true")
      },
      touchpad: {
        present: ($tp_present == "true"),
        name: $tp_name,
        enabled: ($tp_enabled == "true"),
        naturalScroll: $nat_scroll,
        clickfingerBehavior: $clickfinger,
        scrollFactor: $scroll_factor,
        disableWhileTyping: $dwt
      },
      gestures: {
        workspaceSwipeTouch: $swipe_touch
      },
      sensitivity: $sens,
      touchOutput: $touch_out,
      monitors: $monitors,
      virtualKeyboard: $vk_present
    }'
}

case "${1:-get-state}" in
  get-state)
    cmd_get_state
    ;;

  toggle-touchscreen)
    action="${2:-toggle}"
    if command -v omarchy-toggle-touchscreen >/dev/null 2>&1; then
      omarchy-toggle-touchscreen "$action"
    elif command -v omarchy-toggle-input-device >/dev/null 2>&1; then
      omarchy-toggle-input-device touchscreen "$action"
    fi
    cmd_get_state
    ;;

  toggle-touchpad)
    action="${2:-toggle}"
    if command -v omarchy-toggle-touchpad >/dev/null 2>&1; then
      omarchy-toggle-touchpad "$action"
    elif command -v omarchy-toggle-input-device >/dev/null 2>&1; then
      omarchy-toggle-input-device touchpad "$action"
    fi
    cmd_get_state
    ;;

  set-natural-scroll)
    val="${2:-false}"
    hyprctl eval "hl.config({ input = { touchpad = { natural_scroll = $val } } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-clickfinger)
    val="${2:-true}"
    hyprctl eval "hl.config({ input = { touchpad = { clickfinger_behavior = $val } } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-scroll-factor)
    val="${2:-0.4}"
    hyprctl eval "hl.config({ input = { touchpad = { scroll_factor = $val } } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-disable-while-typing)
    val="${2:-false}"
    hyprctl eval "hl.config({ input = { touchpad = { disable_while_typing = $val } } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-workspace-swipe-touch)
    val="${2:-false}"
    hyprctl eval "hl.config({ gestures = { workspace_swipe_touch = $val } } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-sensitivity)
    val="${2:-0.0}"
    hyprctl eval "hl.config({ input = { sensitivity = $val } })" >/dev/null
    update_persist_lua
    cmd_get_state
    ;;

  set-touch-output)
    out="${2:-[[Auto]]}"
    if [[ "$out" == "[[Auto]]" || "$out" == "Auto" || -z "$out" ]]; then
      hyprctl eval 'hl.config({ input = { touchdevice = { output = "[[Auto]]" } } })' >/dev/null
    else
      hyprctl eval "hl.config({ input = { touchdevice = { output = \"$out\" } } })" >/dev/null
    fi
    update_persist_lua
    cmd_get_state
    ;;

  *)
    echo "Unknown command: ${1:-}" >&2
    exit 1
    ;;
esac
