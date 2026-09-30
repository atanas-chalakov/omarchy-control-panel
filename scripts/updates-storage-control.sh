#!/usr/bin/env bash
# Control script for System Updates & Storage management in omarchy-control-panel

set -u

cmd="${1:-get-state}"

format_bytes_kb() {
  local kb=$1
  if (( kb > 1048576 )); then
    awk -v k="$kb" 'BEGIN { printf "%.1f GB", k / 1048576 }'
  elif (( kb > 1024 )); then
    awk -v k="$kb" 'BEGIN { printf "%.1f MB", k / 1024 }'
  else
    echo "${kb} KB"
  fi
}

get_state() {
  # 1. Updates
  local pacman_updates=()
  local aur_updates=()
  local pacman_count=0
  local aur_count=0

  # Check Pacman updates
  if command -v checkupdates >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # line format: "pkg old -> new"
      local name="" old="" arrow="" new=""
      read -r name old arrow new <<< "$line"
      pacman_updates+=("{\"name\":\"$name\",\"old_version\":\"$old\",\"new_version\":\"$new\",\"source\":\"pacman\"}")
      (( pacman_count++ )) || true
    done < <(checkupdates 2>/dev/null || true)
  fi

  # Check AUR updates
  if command -v yay >/dev/null 2>&1; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # line format: "pkg old -> new [time]"
      local name="" old="" arrow="" new="" extra=""
      read -r name old arrow new extra <<< "$line"
      aur_updates+=("{\"name\":\"$name\",\"old_version\":\"$old\",\"new_version\":\"$new\",\"source\":\"aur\"}")
      (( aur_count++ )) || true
    done < <(yay -Qua 2>/dev/null || true)
  fi

  local total_updates=$(( pacman_count + aur_count ))

  # 2. Partitions
  local partitions=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # format: mount total used avail pct
    local mount="" total="" used="" avail="" pct=""
    read -r mount total used avail pct <<< "$line"
    local pct_num="${pct%\%}"
    local total_str used_str avail_str
    total_str=$(format_bytes_kb "$total")
    used_str=$(format_bytes_kb "$used")
    avail_str=$(format_bytes_kb "$avail")

    local label="$mount"
    if [[ "$mount" == "/" ]]; then
      label="Root System (/)"
    elif [[ "$mount" == "/boot" ]]; then
      label="Boot Partition (/boot)"
    elif [[ "$mount" == "/home" ]]; then
      label="Home Storage (/home)"
    fi

    partitions+=("{\"mount\":\"$mount\",\"label\":\"$label\",\"total_str\":\"$total_str\",\"used_str\":\"$used_str\",\"avail_str\":\"$avail_str\",\"percent\":$pct_num}")
  done < <(df -P -k / /boot 2>/dev/null | awk 'NR>1 {print $6, $2, $3, $4, $5}' || true)

  # 3. Cache & Maintenance metrics
  local pac_cache="0B"
  if [[ -d /var/cache/pacman/pkg ]]; then
    pac_cache=$( (du -sh /var/cache/pacman/pkg 2>/dev/null || true) | awk '{print $1}' )
  fi
  pac_cache="${pac_cache:-0B}"

  local journal_size="0B"
  if command -v journalctl >/dev/null 2>&1; then
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]\+[KMGTP]' | head -n 1 || true)
  fi
  journal_size="${journal_size:-0B}"

  local user_cache="0B"
  if [[ -d "$HOME/.cache" ]]; then
    user_cache=$( (du -sh "$HOME/.cache" 2>/dev/null || true) | awk '{print $1}' )
  fi
  user_cache="${user_cache:-0B}"

  local orphans_count
  orphans_count=$( (pacman -Qtdq 2>/dev/null || true) | wc -l | tr -d ' ' )

  # Join json arrays
  local pac_json aur_json part_json
  IFS=, ; pac_json="${pacman_updates[*]:-}"
  IFS=, ; aur_json="${aur_updates[*]:-}"
  IFS=, ; part_json="${partitions[*]:-}"

  cat <<EOF
{
  "updates": {
    "total_count": $total_updates,
    "pacman_count": $pacman_count,
    "aur_count": $aur_count,
    "pacman_items": [$pac_json],
    "aur_items": [$aur_json]
  },
  "storage": {
    "partitions": [$part_json],
    "pacman_cache": "$pac_cache",
    "journal_size": "$journal_size",
    "user_cache": "$user_cache",
    "orphans_count": $orphans_count
  }
}
EOF
}

case "$cmd" in
  get-state)
    get_state
    ;;
  launch-update)
    if command -v omarchy-launch-floating-terminal-with-presentation >/dev/null 2>&1; then
      omarchy-launch-floating-terminal-with-presentation omarchy-update &
    elif command -v omarchy-launch-terminal >/dev/null 2>&1; then
      omarchy-launch-terminal -e omarchy update &
    else
      xdg-terminal-exec -e omarchy update &
    fi
    echo '{"status":"launched"}'
    ;;
  prune-cache)
    if command -v omarchy-launch-floating-terminal-with-presentation >/dev/null 2>&1; then
      omarchy-launch-floating-terminal-with-presentation "sudo paccache -rk2" &
    else
      xdg-terminal-exec -e sudo paccache -rk2 &
    fi
    echo '{"status":"pruning"}'
    ;;
  vacuum-journal)
    if command -v omarchy-launch-floating-terminal-with-presentation >/dev/null 2>&1; then
      omarchy-launch-floating-terminal-with-presentation "sudo journalctl --vacuum-time=7d" &
    else
      xdg-terminal-exec -e sudo journalctl --vacuum-time=7d &
    fi
    echo '{"status":"vacuuming"}'
    ;;
  remove-orphans)
    if command -v omarchy-launch-floating-terminal-with-presentation >/dev/null 2>&1; then
      omarchy-launch-floating-terminal-with-presentation omarchy-update-orphan-pkgs &
    else
      xdg-terminal-exec -e omarchy-update-orphan-pkgs &
    fi
    echo '{"status":"removing-orphans"}'
    ;;
  clean-user-cache)
    rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
    echo '{"status":"cleaned"}'
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
