#!/usr/bin/env bash
# Control script for Shortcuts & Keybindings management in omarchy-control-panel

set -u

cmd="${1:-get-state}"

get_state() {
  local binds_json="[]"

  if command -v omarchy-menu-keybindings >/dev/null 2>&1; then
    binds_json=$(omarchy-menu-keybindings --print 2>/dev/null | awk -F" → " 'NF==2 {
      k = $1; d = $2;
      gsub(/[[:space:]]+$/, "", k);
      gsub(/^[[:space:]]+/, "", d);
      ld = tolower(d);
      cat = "general";
      if (ld ~ /window|split|full|float|pin|kill|close/) cat = "windows";
      else if (ld ~ /workspace/) cat = "workspaces";
      else if (ld ~ /terminal|browser|file manager|editor|app|slack|discord|music|herdr|tmux/) cat = "apps";
      else if (ld ~ /volume|mute|brightness|screenshot|screenrecording|color picker|media|camera|audio/) cat = "media";
      else if (ld ~ /lock|sleep|power|logout|reboot|shutdown|system/) cat = "system";

      gsub(/\\/, "\\\\", k);
      gsub(/"/, "\\\"", k);
      gsub(/\\/, "\\\\", d);
      gsub(/"/, "\\\"", d);

      printf "{\"keys\":\"%s\",\"desc\":\"%s\",\"category\":\"%s\"}\n", k, d, cat
    }' | jq -s . 2>/dev/null || echo "[]")
  fi

  local count=0
  count=$(echo "$binds_json" | jq '. | length' 2>/dev/null || echo 0)

  local config_file="$HOME/.config/hypr/bindings.lua"

  cat <<EOF
{
  "count": $count,
  "configFile": "$config_file",
  "bindings": $binds_json
}
EOF
}

case "$cmd" in
  get-state)
    get_state
    ;;
  open-config)
    config_file="$HOME/.config/hypr/bindings.lua"
    if command -v omarchy-launch-editor >/dev/null 2>&1; then
      omarchy-launch-editor "$config_file" &
    else
      xdg-open "$config_file" &
    fi
    echo '{"status":"opened"}'
    ;;
  open-menu)
    if command -v omarchy-menu-keybindings >/dev/null 2>&1; then
      omarchy-menu-keybindings &
    fi
    echo '{"status":"menu-launched"}'
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
