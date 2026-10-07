#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
      theme_file="$HOME/.local/state/omarchy/current/theme.name"
      snap=""
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$theme_file" ]]; then
        snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$theme_file" 2>/dev/null || true)
      fi
      omarchy theme set "$target" >/dev/null 2>&1 || true
      if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record "appearance" "Theme changed to $target" "$theme_file" "$snap" >/dev/null 2>&1 || true
      elif [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "appearance" "Theme changed to $target" "omarchy-theme" "omarchy theme set $target" "Switched active theme to $target" >/dev/null 2>&1 || true
      fi
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

    # 5. Application Playback Streams
    apps_json=$(pactl -f json list sink-inputs 2>/dev/null | jq -c '[.[] | {
      id: .index,
      name: (.properties["application.name"] // "Application"),
      icon: (.properties["application.icon_name"] // "audio-speakers"),
      muted: .mute,
      volume: ((.volume["front-left"].value_percent // "100%") | rtrimstr("%") | tonumber)
    }]' 2>/dev/null || echo "[]")

    jq -n \
      --argjson volume "$vol_percent" \
      --argjson muted "$is_muted" \
      --argjson sinks "$sinks_json" \
      --argjson inputVolume "$input_vol_percent" \
      --argjson inputMuted "$input_is_muted" \
      --argjson sources "$sources_json" \
      --argjson apps "${apps_json:-[]}" \
      '{
        volume: $volume,
        muted: $muted,
        sinks: ($sinks // []),
        inputVolume: $inputVolume,
        inputMuted: $inputMuted,
        sources: ($sources // []),
        apps: ($apps // [])
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
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "sound" "Default Audio Output Device" "wireplumber" "wpctl set-default $sink_id" "Set default audio output device" >/dev/null 2>&1 || true
      fi
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
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record-command "sound" "Default Audio Input Device" "wireplumber" "wpctl set-default $source_id" "Set default audio input device" >/dev/null 2>&1 || true
      fi
    fi
    ;;

  audio-set-app-volume)
    stream_id="${2:-}"
    val="${3:-}"
    if [[ -n "$stream_id" && -n "$val" ]]; then
      num=$(printf '%.0f' "$val")
      if (( num < 0 )); then num=0; fi
      if (( num > 100 )); then num=100; fi
      pactl set-sink-input-volume "$stream_id" "${num}%" >/dev/null 2>&1 || true
    fi
    ;;

  audio-set-app-mute)
    stream_id="${2:-}"
    action="${3:-toggle}"
    if [[ -n "$stream_id" ]]; then
      pactl set-sink-input-mute "$stream_id" "$action" >/dev/null 2>&1 || true
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
    tz_str=$(timedatectl status 2>/dev/null | grep "Time zone:" | sed -e 's/^[[:space:]]*Time zone:[[:space:]]*//' || echo "")
    ntp_str=$(timedatectl status 2>/dev/null | grep "NTP service:" | awk '{print $3}' || echo "unknown")

    jq -n \
      --arg os "$os_name" \
      --arg ver "$os_ver" \
      --arg kernel "$kernel" \
      --arg cpu "$cpu" \
      --arg ram "$ram" \
      --arg uptime "$uptime_str" \
      --arg hostname "$host_name" \
      --arg timezone "$tz_str" \
      --arg ntp "$ntp_str" \
      '{
        os: $os,
        version: $ver,
        kernel: $kernel,
        cpu: $cpu,
        ram: $ram,
        uptime: $uptime,
        hostname: $hostname,
        timezone: $timezone,
        ntp: $ntp
      }'
    ;;

  about-set-timezone)
    if command -v omarchy-menu-timezone >/dev/null 2>&1; then
      omarchy-menu-timezone &
    fi
    echo '{"status":"timezone-picker-launched"}'
    ;;

  agents-get)
    python3 -c '
import os, json, glob, shutil

default_file = os.path.expanduser("~/.config/omarchy/defaults/agent")
default_agent = ""
if os.path.exists(default_file):
    with open(default_file) as f:
        default_agent = f.read().strip()
if not default_agent:
    default_agent = "agy"

known_agents = [
    {"id": "agy", "name": "Antigravity", "cmd": "agy", "desc": "Google DeepMind Advanced Agentic Assistant"},
    {"id": "claude", "name": "Claude Code", "cmd": "claude", "desc": "Anthropic Claude Code CLI"},
    {"id": "codex", "name": "Codex", "cmd": "codex", "desc": "OpenAI Codex CLI"},
    {"id": "copilot", "name": "GitHub Copilot", "cmd": "copilot", "desc": "GitHub Copilot CLI"},
    {"id": "opencode", "name": "OpenCode", "cmd": "opencode", "desc": "OpenCode AI Coding Agent"},
    {"id": "pi", "name": "Pi", "cmd": "pi", "desc": "Inflection Pi Coding Assistant"},
    {"id": "hermes", "name": "Hermes", "cmd": "hermes", "desc": "Hermes Autonomous Agent"}
]

for a in known_agents:
    a["installed"] = shutil.which(a["cmd"]) is not None
    a["isDefault"] = (a["id"] == default_agent)

usage_dir = os.path.expanduser("~/.local/state/omarchy/agents/usage")
usage_records = []
if os.path.isdir(usage_dir):
    for fpath in sorted(glob.glob(os.path.join(usage_dir, "*.json"))):
        try:
            with open(fpath) as f:
                data = json.load(f)
                usage_records.append(data)
        except Exception:
            pass

print(json.dumps({
    "defaultAgent": default_agent,
    "agents": known_agents,
    "usage": usage_records
}))
'
    ;;

  agent-set-default)
    target="${2:-}"
    if [[ -n "$target" ]]; then
      mkdir -p "$HOME/.config/omarchy/defaults"
      printf '%s\n' "$target" > "$HOME/.config/omarchy/defaults/agent"
    fi
    ;;

  agent-launch)
    target="${2:-}"
    if [[ -n "$target" ]]; then
      mkdir -p "$HOME/.config/omarchy/defaults"
      printf '%s\n' "$target" > "$HOME/.config/omarchy/defaults/agent"
    fi
    if command -v omarchy-launch-floating-terminal-with-presentation >/dev/null 2>&1; then
      omarchy-launch-floating-terminal-with-presentation omarchy-agent >/dev/null 2>&1 &
    elif command -v omarchy-agent >/dev/null 2>&1; then
      omarchy-agent >/dev/null 2>&1 &
    fi
    ;;

  agent-refresh-usage)
    omarchy-agent-usage-update >/dev/null 2>&1 || true
    ;;

  backup-export)
    python3 -c '
import os, sys, tarfile, datetime, subprocess, json

home = os.path.expanduser("~")
backup_dir = os.path.join(home, ".local/state/omarchy/backups/control-panel")
os.makedirs(backup_dir, exist_ok=True)

targets = [
    ".config/hypr",
    ".config/omarchy/shell.json",
    ".config/omarchy/defaults",
    ".local/state/omarchy/toggles",
    ".local/state/omarchy/current/theme.name",
    ".config/mimeapps.list"
]

files_to_add = []
for rel in targets:
    full = os.path.join(home, rel)
    if os.path.isfile(full):
        files_to_add.append(rel)
    elif os.path.isdir(full):
        for root, dirs, files in os.walk(full):
            for f in files:
                if ".bak" in f or f.endswith("~") or f.startswith(".git"):
                    continue
                files_to_add.append(os.path.relpath(os.path.join(root, f), home))

ts_raw = datetime.datetime.now()
stamp = ts_raw.strftime("%Y%m%d-%H%M%S")
ts_display = ts_raw.strftime("%Y-%m-%d %H:%M:%S")
filename = "backup-" + stamp + ".tar.gz"
archive_path = os.path.join(backup_dir, filename)

with tarfile.open(archive_path, "w:gz") as tar:
    for rel in files_to_add:
        full = os.path.join(home, rel)
        tar.add(full, arcname=rel)

size_bytes = os.path.getsize(archive_path)
size_str = f"{size_bytes / 1024:.1f} KB" if size_bytes < 1048576 else f"{size_bytes / 1048576:.2f} MB"

tracker = os.path.join(os.path.dirname(os.path.abspath(__file__ if "__file__" in dir() else sys.argv[0])), "config-tracker.sh")
if not os.path.isfile(tracker):
    tracker = os.path.expanduser("~/.config/omarchy/plugins/ac.control-panel/scripts/config-tracker.sh")
if os.path.isfile(tracker):
    subprocess.run([tracker, "record-command", "about", "System Configuration Backup", "backup", "scripts/system-control.sh backup-export", f"Exported configuration archive: {filename}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print(json.dumps({
    "success": True,
    "filename": filename,
    "path": archive_path,
    "timestamp": ts_display,
    "filesCount": len(files_to_add),
    "size": size_str
}))
'
    ;;

  backup-list)
    python3 -c '
import os, json, tarfile, datetime, glob

home = os.path.expanduser("~")
backup_dir = os.path.join(home, ".local/state/omarchy/backups/control-panel")
if not os.path.isdir(backup_dir):
    print("[]")
    exit(0)

archives = sorted(glob.glob(os.path.join(backup_dir, "backup-*.tar.gz")), key=os.path.getmtime, reverse=True)
results = []
for fpath in archives:
    try:
        fname = os.path.basename(fpath)
        mtime = os.path.getmtime(fpath)
        dt = datetime.datetime.fromtimestamp(mtime)
        ts_display = dt.strftime("%Y-%m-%d %H:%M:%S")
        size_bytes = os.path.getsize(fpath)
        size_str = f"{size_bytes / 1024:.1f} KB" if size_bytes < 1048576 else f"{size_bytes / 1048576:.2f} MB"
        
        count = 0
        with tarfile.open(fpath, "r:gz") as tar:
            count = len(tar.getmembers())

        results.append({
            "filename": fname,
            "timestamp": ts_display,
            "size": size_str,
            "filesCount": count
        })
    except Exception:
        pass

print(json.dumps(results))
'
    ;;

  backup-restore)
    target="${2:-}"
    if [[ -z "$target" ]]; then
      echo '{"success":false,"error":"Missing backup filename"}' >&2
      exit 1
    fi
    python3 -c '
import os, sys, tarfile, subprocess, json

home = os.path.expanduser("~")
backup_dir = os.path.join(home, ".local/state/omarchy/backups/control-panel")
fname = sys.argv[1]

base = os.path.basename(fname)
if base != fname or not fname.endswith(".tar.gz") or not fname.startswith("backup-"):
    print(json.dumps({"success": False, "error": "Invalid backup filename"}))
    sys.exit(1)

archive_path = os.path.join(backup_dir, base)
if not os.path.isfile(archive_path):
    print(json.dumps({"success": False, "error": "Backup file not found"}))
    sys.exit(1)

try:
    with tarfile.open(archive_path, "r:gz") as tar:
        tar.extractall(path=home, filter="data")

    theme_name_file = os.path.join(home, ".local/state/omarchy/current/theme.name")
    if os.path.isfile(theme_name_file):
        try:
            with open(theme_name_file) as f:
                tname = f.read().strip()
                if tname:
                    subprocess.run(["omarchy", "theme", "set", tname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["omarchy", "restart", "shell"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    tracker = os.path.join(os.path.dirname(os.path.abspath(__file__ if "__file__" in dir() else sys.argv[0])), "config-tracker.sh")
    if not os.path.isfile(tracker):
        tracker = os.path.expanduser("~/.config/omarchy/plugins/ac.control-panel/scripts/config-tracker.sh")
    if os.path.isfile(tracker):
        subprocess.run([tracker, "record-command", "about", "Restored System Configuration", "restore", f"scripts/system-control.sh backup-restore {base}", f"Restored configuration archive: {base}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print(json.dumps({
        "success": True,
        "message": f"Restored {base} successfully"
    }))
except Exception as e:
    print(json.dumps({"success": False, "error": str(e)}))
    sys.exit(1)
' "$target"
    ;;

  backup-delete)
    target="${2:-}"
    if [[ -z "$target" ]]; then
      echo '{"success":false,"error":"Missing backup filename"}' >&2
      exit 1
    fi
    python3 -c '
import os, sys, json

home = os.path.expanduser("~")
backup_dir = os.path.join(home, ".local/state/omarchy/backups/control-panel")
fname = sys.argv[1]
base = os.path.basename(fname)
if base != fname or not fname.endswith(".tar.gz") or not fname.startswith("backup-"):
    print(json.dumps({"success": False, "error": "Invalid backup filename"}))
    sys.exit(1)

archive_path = os.path.join(backup_dir, base)
if os.path.isfile(archive_path):
    os.remove(archive_path)
    print(json.dumps({"success": True, "message": f"Deleted {base}"}))
else:
    print(json.dumps({"success": False, "error": "Backup file not found"}))
' "$target"
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
