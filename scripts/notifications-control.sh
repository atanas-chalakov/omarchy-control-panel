#!/usr/bin/env bash
# Control script for Notifications & Do Not Disturb in omarchy-control-panel

set -u

cmd="${1:-get-state}"

get_state() {
  local dnd_state="off"
  if command -v omarchy-shell >/dev/null 2>&1; then
    dnd_state=$(omarchy-shell notifications dndState 2>/dev/null || echo "off")
  fi

  local is_dnd=false
  [[ "$dnd_state" == "on" ]] && is_dnd=true

  local history_dir="$HOME/.local/state/omarchy/notifications/history"
  local history_json="[]"
  local history_count=0

  if [[ -d "$history_dir" ]]; then
    local files
    files=$(ls -t "$history_dir"/*.json 2>/dev/null | head -n 12 || true)
    if [[ -n "$files" ]]; then
      history_json=$(cat $files 2>/dev/null | jq -s 'sort_by(.timestamp) | reverse | [.[] | {
        id: (.id // 0),
        app: (.app // "System"),
        summary: (.summary // "Notification"),
        body: (.body // ""),
        urgency: (.urgency // 1),
        timestamp: (.timestamp // 0)
      }]' 2>/dev/null || echo "[]")
      history_count=$(echo "$history_json" | jq '. | length' 2>/dev/null || echo 0)
    fi
  fi

  cat <<EOF
{
  "dnd": $is_dnd,
  "historyCount": $history_count,
  "history": $history_json
}
EOF
}

case "$cmd" in
  get-state)
    get_state
    ;;
  toggle-dnd)
    if command -v omarchy-shell >/dev/null 2>&1; then
      omarchy-shell notifications toggleDnd >/dev/null 2>&1 || true
      omarchy-shell -q omarchy.indicators refresh >/dev/null 2>&1 || true
    fi
    get_state
    ;;
  set-dnd)
    val="${2:-false}"
    if command -v omarchy-shell >/dev/null 2>&1; then
      omarchy-shell notifications setDnd "$val" >/dev/null 2>&1 || true
      omarchy-shell -q omarchy.indicators refresh >/dev/null 2>&1 || true
    fi
    get_state
    ;;
  show-history)
    if command -v omarchy-shell >/dev/null 2>&1; then
      omarchy-shell notifications showHistory >/dev/null 2>&1 || true
    fi
    echo '{"status":"replayed"}'
    ;;
  clear-history)
    if command -v omarchy-shell >/dev/null 2>&1; then
      omarchy-shell notifications clear >/dev/null 2>&1 || true
    fi
    get_state
    ;;
  dismiss-all)
    if command -v omarchy-shell >/dev/null 2>&1; then
      omarchy-shell notifications dismissAll >/dev/null 2>&1 || true
    fi
    echo '{"status":"dismissed"}'
    ;;
  send-test)
    if command -v omarchy-notification-send >/dev/null 2>&1; then
      omarchy-notification-send "Control Panel" "Notifications are working properly!" -g "󰂚" >/dev/null 2>&1 || true
    else
      notify-send "Control Panel" "Notifications are working properly!" >/dev/null 2>&1 || true
    fi
    echo '{"status":"sent"}'
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
