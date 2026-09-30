#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-get-state}"
PERSIST_DIR="$HOME/.local/state/omarchy/toggles/hypr"
PERSIST_LUA="$PERSIST_DIR/keyboard-layout.lua"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

case "$cmd" in
  get-state)
    python3 -c '
import subprocess, json, os, re, datetime

# 1. Date & Time
now = datetime.datetime.now()
time_str = now.strftime("%I:%M %p")
date_str = now.strftime("%A, %B %d, %Y")

# timedatectl
res = ""
try:
    res = subprocess.run(["timedatectl", "status"], capture_output=True, text=True, timeout=3).stdout
except Exception:
    pass

tz_match = re.search(r"Time zone:\s*([^\s]+)\s*\(([^\)]+)\)", res)
timezone = tz_match.group(1) if tz_match else ""
tz_offset = tz_match.group(2) if tz_match else ""
ntp_match = re.search(r"NTP service:\s*([^\s]+)", res)
ntp_active = "active" in (ntp_match.group(1).lower() if ntp_match else "") or "yes" in res.lower()

# 2. Weather & Location
weather_file = os.path.expanduser("~/.local/state/omarchy/settings/weather.json")
is_auto_loc = True
custom_city = ""
if os.path.exists(weather_file):
    try:
        with open(weather_file) as f:
            wdata = json.load(f)
            custom_city = wdata.get("name", "")
            if custom_city:
                is_auto_loc = False
    except Exception:
        pass

loc_name = ""
try:
    loc_name = subprocess.run(["omarchy-weather-location"], capture_output=True, text=True, timeout=4).stdout.strip()
except Exception:
    loc_name = custom_city or "Unknown"

weather_status = ""
try:
    weather_status = subprocess.run(["omarchy-weather-status"], capture_output=True, text=True, timeout=4).stdout.strip()
except Exception:
    pass

# 3. Shell.json clock format
shell_json_path = os.path.expanduser("~/.config/omarchy/shell.json")
clock_fmt = "dddd HH:mm"
if os.path.exists(shell_json_path):
    try:
        with open(shell_json_path) as f:
            sdata = json.load(f)
            for w in sdata.get("bar", {}).get("layout", {}).get("center", []):
                if w.get("id") == "omarchy.clock":
                    clock_fmt = w.get("format", clock_fmt)
    except Exception:
        pass

is_24h = "HH" in clock_fmt or ("H" in clock_fmt and "h" not in clock_fmt)
has_sec = ":ss" in clock_fmt or ":s" in clock_fmt

# 4. Hyprland keyboard layout
hypr_kb = ""
try:
    hypr_kb = subprocess.run(["hyprctl", "getoption", "input:kb_layout", "-j"], capture_output=True, text=True, timeout=3).stdout
    kb_layout = json.loads(hypr_kb).get("str", "us")
except Exception:
    kb_layout = "us"

hypr_opts = ""
try:
    hypr_opts = subprocess.run(["hyprctl", "getoption", "input:kb_options", "-j"], capture_output=True, text=True, timeout=3).stdout
    kb_options = json.loads(hypr_opts).get("str", "")
except Exception:
    kb_options = ""

hypr_vars = ""
try:
    hypr_vars = subprocess.run(["hyprctl", "getoption", "input:kb_variant", "-j"], capture_output=True, text=True, timeout=3).stdout
    kb_variant = json.loads(hypr_vars).get("str", "")
except Exception:
    kb_variant = ""

devices_raw = ""
try:
    devices_raw = subprocess.run(["hyprctl", "devices", "-j"], capture_output=True, text=True, timeout=3).stdout
    devices = json.loads(devices_raw).get("keyboards", [])
except Exception:
    devices = []

typed_kb = [k for k in devices if not re.match(r"^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)", k.get("name", ""))]
active_kb = typed_kb[0] if typed_kb else (devices[0] if devices else {})
active_layout = active_kb.get("active_keymap", "English (US)")
active_index = active_kb.get("active_layout_index", 0)
kb_device_name = active_kb.get("name", "")

switch_shortcut = "none"
if "grp:alt_shift_toggle" in kb_options:
    switch_shortcut = "alt_shift"
elif "grp:win_space_toggle" in kb_options:
    switch_shortcut = "win_space"
elif "grp:alts_toggle" in kb_options:
    switch_shortcut = "alts"
elif "grp:caps_toggle" in kb_options:
    switch_shortcut = "caps"
elif "grp:ctrl_shift_toggle" in kb_options:
    switch_shortcut = "ctrl_shift"

# 5. Locales
loc_raw = ""
try:
    loc_raw = subprocess.run(["localectl", "status"], capture_output=True, text=True, timeout=3).stdout
except Exception:
    pass

lang_match = re.search(r"System Locale:\s*LANG=([^\s]+)", loc_raw)
sys_locale = lang_match.group(1) if lang_match else "en_US.UTF-8"

installed_locales = []
try:
    loc_list_raw = subprocess.run(["locale", "-a"], capture_output=True, text=True, timeout=3).stdout
    installed_locales = [l.strip() for l in loc_list_raw.splitlines() if l.strip() and l.strip() not in ("C", "POSIX")]
except Exception:
    installed_locales = ["en_US.utf8"]

fcitx_active = False
try:
    fcitx_active = subprocess.run(["pgrep", "-x", "fcitx5"], capture_output=True, text=True).returncode == 0
except Exception:
    pass

configured_layouts = [l.strip() for l in kb_layout.split(",") if l.strip()]

print(json.dumps({
    "time": time_str,
    "date": date_str,
    "timezone": timezone,
    "timezoneOffset": tz_offset,
    "ntpActive": ntp_active,
    "clockFormat": clock_fmt,
    "is24Hour": is_24h,
    "hasSeconds": has_sec,
    "locationName": loc_name,
    "isAutoLocation": is_auto_loc,
    "customCity": custom_city,
    "weatherStatus": weather_status,
    "kbLayout": kb_layout,
    "kbVariant": kb_variant,
    "kbOptions": kb_options,
    "configuredLayouts": configured_layouts,
    "activeLayout": active_layout,
    "activeLayoutIndex": active_index,
    "kbDeviceName": kb_device_name,
    "switchShortcut": switch_shortcut,
    "systemLocale": sys_locale,
    "installedLocales": installed_locales,
    "fcitxActive": fcitx_active
}, indent=2))
'
    ;;

  set-timezone)
    target="${2:-}"
    if [[ -n "$target" ]]; then
      timedatectl set-timezone "$target" >/dev/null 2>&1 || true
      omarchy-shell -q omarchy.clock refresh >/dev/null 2>&1 || true
    fi
    exec "$0" get-state
    ;;

  open-timezone-menu)
    if command -v omarchy-menu-timezone >/dev/null 2>&1; then
      omarchy-menu-timezone >/dev/null 2>&1 &
    fi
    echo '{"status":"ok"}'
    ;;

  set-time-format)
    mode="${2:-24}" # 24 or 12
    python3 -c '
import json, os, sys

mode = sys.argv[1]
shell_path = os.path.expanduser("~/.config/omarchy/shell.json")
if not os.path.exists(shell_path):
    sys.exit(0)

with open(shell_path, "r") as f:
    data = json.load(f)

for w in data.get("bar", {}).get("layout", {}).get("center", []):
    if w.get("id") == "omarchy.clock":
        curr = w.get("format", "dddd HH:mm")
        has_sec = ":ss" in curr or ":s" in curr
        if mode == "12":
            w["format"] = "dddd h:mm:ss A" if has_sec else "dddd h:mm A"
        else:
            w["format"] = "dddd HH:mm:ss" if has_sec else "dddd HH:mm"

with open(shell_path, "w") as f:
    json.dump(data, f, indent=2)
' "$mode"
    omarchy-shell -q omarchy.clock refresh >/dev/null 2>&1 || true
    exec "$0" get-state
    ;;

  toggle-seconds)
    python3 -c '
import json, os

shell_path = os.path.expanduser("~/.config/omarchy/shell.json")
if not os.path.exists(shell_path):
    exit(0)

with open(shell_path, "r") as f:
    data = json.load(f)

for w in data.get("bar", {}).get("layout", {}).get("center", []):
    if w.get("id") == "omarchy.clock":
        curr = w.get("format", "dddd HH:mm")
        if ":ss" in curr:
            w["format"] = curr.replace(":ss", "")
        elif ":s" in curr:
            w["format"] = curr.replace(":s", "")
        else:
            if "A" in curr:
                w["format"] = curr.replace(" A", ":ss A")
            else:
                w["format"] = curr + ":ss"

with open(shell_path, "w") as f:
    json.dump(data, f, indent=2)
'
    omarchy-shell -q omarchy.clock refresh >/dev/null 2>&1 || true
    exec "$0" get-state
    ;;

  set-location)
    city="${2:-}"
    if [[ -n "$city" ]]; then
      omarchy-weather-location --set "$city" >/dev/null 2>&1 || true
      omarchy-shell -q omarchy.weather refresh >/dev/null 2>&1 || true
    fi
    exec "$0" get-state
    ;;

  clear-location)
    omarchy-weather-location --clear >/dev/null 2>&1 || true
    omarchy-shell -q omarchy.weather refresh >/dev/null 2>&1 || true
    exec "$0" get-state
    ;;

  switch-layout)
    kb_name=$(python3 -c '
import subprocess, json, re
devices_raw = subprocess.run(["hyprctl", "devices", "-j"], capture_output=True, text=True).stdout
devices = json.loads(devices_raw).get("keyboards", []) if devices_raw else []
typed_kb = [k for k in devices if not re.match(r"^(hl-virtual-keyboard|power-button|sleep-button|lid-switch|video-bus)", k.get("name", ""))]
print(typed_kb[0]["name"] if typed_kb else (devices[0]["name"] if devices else ""))
')
    if [[ -n "$kb_name" ]]; then
      hyprctl switchxkblayout "$kb_name" next >/dev/null 2>&1 || true
      omarchy-shell -q omarchy.keyboard-layout refresh >/dev/null 2>&1 || true
    fi
    exec "$0" get-state
    ;;

  set-keyboard-config)
    # Args: layouts [variants] [shortcut]
    layouts="${2:-us}"
    variants="${3:-}"
    shortcut="${4:-alt_shift}"

    mkdir -p "$PERSIST_DIR"

    opt_code="compose:caps,shift:both_capslock_cancel"
    if [[ "$shortcut" == "alt_shift" ]]; then
      opt_code="$opt_code,grp:alt_shift_toggle"
    elif [[ "$shortcut" == "win_space" ]]; then
      opt_code="$opt_code,grp:win_space_toggle"
    elif [[ "$shortcut" == "alts" ]]; then
      opt_code="$opt_code,grp:alts_toggle"
    elif [[ "$shortcut" == "caps" ]]; then
      opt_code="$opt_code,grp:caps_toggle"
    elif [[ "$shortcut" == "ctrl_shift" ]]; then
      opt_code="$opt_code,grp:ctrl_shift_toggle"
    fi

    cat > "$PERSIST_LUA" << EOF
-- Omarchy Keyboard Layout Settings
hl.config({
  input = {
    kb_layout = "$layouts",
    kb_variant = "$variants",
    kb_options = "$opt_code",
  },
})
EOF

    hyprctl reload >/dev/null 2>&1 || true
    omarchy-shell -q omarchy.keyboard-layout refresh >/dev/null 2>&1 || true
    exec "$0" get-state
    ;;

  launch-fcitx5-config)
    if command -v fcitx5-configtool >/dev/null 2>&1; then
      fcitx5-configtool >/dev/null 2>&1 &
      echo '{"status":"launched"}'
    else
      echo '{"status":"not-installed"}'
    fi
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    exit 1
    ;;
esac
