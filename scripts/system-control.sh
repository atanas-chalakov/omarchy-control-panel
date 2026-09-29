#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"

case "$cmd" in
  theme-get)
    current=$(omarchy-theme-current 2>/dev/null || omarchy theme current 2>/dev/null || echo "Default")
    themes=$(omarchy theme list 2>/dev/null || echo "")

    themes_json=$(echo "$themes" | grep -v '^$' | jq -R . | jq -s .)

    jq -n \
      --arg current "$current" \
      --argjson list "$themes_json" \
      '{
        current: $current,
        themes: $list
      }'
    ;;

  theme-set)
    target="${2:-}"
    if [[ -n "$target" ]]; then
      omarchy theme set "$target" >/dev/null 2>&1 || true
    fi
    ;;

  audio-get)
    # 1. Volume & Mute
    vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.5")
    vol_num=$(echo "$vol_raw" | awk '{print $2}')
    is_muted=false
    [[ "$vol_raw" =~ \[MUTED\] ]] && is_muted=true

    vol_percent=$(awk -v v="$vol_num" 'BEGIN { printf "%d", (v * 100) + 0.5 }')
    if (( vol_percent > 100 )); then vol_percent=100; fi
    if (( vol_percent < 0 )); then vol_percent=0; fi

    # 2. Sinks
    sinks_json=$(wpctl status 2>/dev/null | awk '
      /Audio/,/Sources/ {
        if ($0 ~ /Sinks:/) { in_sinks=1; next }
        if ($0 ~ /Sources:/) { in_sinks=0 }
        if (in_sinks && match($0, /([0-9]+)\.[[:space:]]+(.*)[[:space:]]+\[vol:/, m)) {
          is_default = ($0 ~ /\*/) ? "true" : "false"
          gsub(/[[:space:]]+$/, "", m[2])
          printf "%s\t%s\t%s\n", m[1], m[2], is_default
        }
      }
    ' | jq -R 'split("\t") | {id: .[0], name: .[1], isDefault: (.[2] == "true")}' | jq -s .)

    # 3. Input (Microphone) Volume & Mute
    input_vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || echo "Volume: 1.0")
    input_vol_num=$(echo "$input_vol_raw" | awk '{print $2}')
    input_is_muted=false
    [[ "$input_vol_raw" =~ \[MUTED\] ]] && input_is_muted=true

    input_vol_percent=$(awk -v v="$input_vol_num" 'BEGIN { printf "%d", (v * 100) + 0.5 }')
    if (( input_vol_percent > 100 )); then input_vol_percent=100; fi
    if (( input_vol_percent < 0 )); then input_vol_percent=0; fi

    # 4. Input Sources (Microphones)
    sources_json=$(wpctl status 2>/dev/null | awk '
      /Sources:/,/Filters:/ {
        if ($0 ~ /Sources:/) { in_sources=1; next }
        if ($0 ~ /Filters:/ || $0 ~ /Streams:/) { in_sources=0 }
        if (in_sources && match($0, /([0-9]+)\.[[:space:]]+(.*)[[:space:]]+\[vol:/, m)) {
          is_default = ($0 ~ /\*/) ? "true" : "false"
          gsub(/[[:space:]]+$/, "", m[2])
          printf "%s\t%s\t%s\n", m[1], m[2], is_default
        }
      }
    ' | jq -R 'split("\t") | {id: .[0], name: .[1], isDefault: (.[2] == "true")}' | jq -s .)

    jq -n \
      --argjson volume "$vol_percent" \
      --argjson muted "$is_muted" \
      --argjson sinks "$sinks_json" \
      --argjson inputVolume "$input_vol_percent" \
      --argjson inputMuted "$input_is_muted" \
      --argjson sources "$sources_json" \
      '{
        volume: $volume,
        muted: $muted,
        sinks: ($sinks // []),
        inputVolume: $inputVolume,
        inputMuted: $inputMuted,
        sources: ($sources // [])
      }'
    ;;

  audio-set-volume)
    val="${2:-}"
    if [[ -n "$val" ]]; then
      num=$(printf '%.0f' "$val")
      if (( num < 0 )); then num=0; fi
      if (( num > 100 )); then num=100; fi
      # wpctl requires float 0.0 - 1.0 (e.g. 0.50 for 50%)
      float_val=$(awk -v n="$num" 'BEGIN { printf "%.2f", n / 100 }')
      wpctl set-volume @DEFAULT_AUDIO_SINK@ "$float_val" >/dev/null 2>&1 || true
    fi
    ;;

  audio-set-mute)
    action="${2:-toggle}"
    wpctl set-mute @DEFAULT_AUDIO_SINK@ "$action" >/dev/null 2>&1 || true
    ;;

  audio-set-sink)
    sink_id="${2:-}"
    if [[ -n "$sink_id" ]]; then
      wpctl set-default "$sink_id" >/dev/null 2>&1 || true
    fi
    ;;

  audio-set-input-volume)
    val="${2:-}"
    if [[ -n "$val" ]]; then
      num=$(printf '%.0f' "$val")
      if (( num < 0 )); then num=0; fi
      if (( num > 100 )); then num=100; fi
      float_val=$(awk -v n="$num" 'BEGIN { printf "%.2f", n / 100 }')
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$float_val" >/dev/null 2>&1 || true
    fi
    ;;

  audio-set-input-mute)
    action="${2:-toggle}"
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ "$action" >/dev/null 2>&1 || true
    ;;

  audio-set-source)
    source_id="${2:-}"
    if [[ -n "$source_id" ]]; then
      wpctl set-default "$source_id" >/dev/null 2>&1 || true
    fi
    ;;

  about-get)
    os_name=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d= -f2 | tr -d '"' || echo "Omarchy")
    os_ver=$(cat /etc/os-release 2>/dev/null | grep "^VERSION_ID=" | cut -d= -f2 | tr -d '"' || echo "4.0.3")
    kernel=$(uname -r 2>/dev/null || echo "")
    cpu=$(lscpu 2>/dev/null | grep "Model name" | head -n 1 | sed 's/Model name:[[:space:]]*//' || echo "")
    ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 " used / " $2 " total"}')
    uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "")
    host_name=$(hostname 2>/dev/null || echo "")

    jq -n \
      --arg os "$os_name" \
      --arg ver "$os_ver" \
      --arg kernel "$kernel" \
      --arg cpu "$cpu" \
      --arg ram "$ram" \
      --arg uptime "$uptime_str" \
      --arg hostname "$host_name" \
      '{
        os: $os,
        version: $ver,
        kernel: $kernel,
        cpu: $cpu,
        ram: $ram,
        uptime: $uptime,
        hostname: $hostname
      }'
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
