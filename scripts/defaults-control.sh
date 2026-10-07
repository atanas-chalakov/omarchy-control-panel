#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIME_FILE="$HOME/.config/mimeapps.list"

cmd_get_state() {
  python3 - << 'EOF'
import subprocess, json, shutil, os

def check_bin(b):
    return shutil.which(b) is not None

all_browsers = [
    {"id": "brave-browser.desktop", "name": "Brave", "icon": "󰖟", "bin": "brave"},
    {"id": "chromium.desktop", "name": "Chromium", "icon": "", "bin": "chromium"},
    {"id": "firefox.desktop", "name": "Firefox", "icon": "󰈹", "bin": "firefox"},
    {"id": "google-chrome.desktop", "name": "Google Chrome", "icon": "", "bin": "google-chrome-stable"},
    {"id": "zen-browser.desktop", "name": "Zen Browser", "icon": "󰖟", "bin": "zen-browser"}
]

all_editors = [
    {"id": "code.desktop", "code": "code", "name": "Visual Studio Code", "icon": "󰨞", "bin": "code"},
    {"id": "nvim.desktop", "code": "nvim", "name": "Neovim", "icon": "", "bin": "nvim"},
    {"id": "zed.desktop", "code": "zed", "name": "Zed", "icon": "󰅩", "bin": "zed"},
    {"id": "helix.desktop", "code": "helix", "name": "Helix", "icon": "󰅩", "bin": "helix"},
    {"id": "emacs.desktop", "code": "emacs", "name": "Emacs", "icon": "", "bin": "emacs"}
]

all_terminals = [
    {"id": "Alacritty.desktop", "name": "Alacritty", "icon": "", "bin": "alacritty"},
    {"id": "foot.desktop", "name": "Foot", "icon": "", "bin": "foot"},
    {"id": "kitty.desktop", "name": "Kitty", "icon": "󰄛", "bin": "kitty"},
    {"id": "com.mitchellh.ghostty.desktop", "name": "Ghostty", "icon": "󱙝", "bin": "ghostty"}
]

all_file_managers = [
    {"id": "org.gnome.Nautilus.desktop", "name": "Nautilus (GNOME Files)", "icon": "", "bin": "nautilus"},
    {"id": "thunar.desktop", "name": "Thunar", "icon": "", "bin": "thunar"},
    {"id": "org.kde.dolphin.desktop", "name": "Dolphin", "icon": "", "bin": "dolphin"}
]

cur_browser = "chromium.desktop"
if shutil.which("omarchy-cmd-default-browser"):
    try:
        out = subprocess.run(["omarchy-cmd-default-browser"], capture_output=True, text=True).stdout.strip()
        if out: cur_browser = out
    except Exception:
        pass
elif shutil.which("xdg-settings"):
    try:
        out = subprocess.run(["xdg-settings", "get", "default-web-browser"], capture_output=True, text=True).stdout.strip()
        if out: cur_browser = out
    except Exception:
        pass

home = os.path.expanduser("~")
ed_file = os.path.join(home, ".local/state/omarchy/defaults/editor")
cur_editor = "nvim"
if os.path.exists(ed_file):
    with open(ed_file) as f: cur_editor = f.read().strip() or "nvim"

term_file = os.path.join(home, ".config/xdg-terminals.list")
cur_term = "Alacritty.desktop"
if os.path.exists(term_file):
    with open(term_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                cur_term = line
                break

cur_fm = "org.gnome.Nautilus.desktop"
if shutil.which("xdg-mime"):
    try:
        out = subprocess.run(["xdg-mime", "query", "default", "inode/directory"], capture_output=True, text=True).stdout.strip()
        if out: cur_fm = out
    except Exception:
        pass

res = {
    "browser": {
        "current": cur_browser,
        "installed": [b for b in all_browsers if check_bin(b["bin"])]
    },
    "editor": {
        "current": cur_editor,
        "installed": [e for e in all_editors if check_bin(e["bin"])]
    },
    "terminal": {
        "current": cur_term,
        "installed": [t for t in all_terminals if check_bin(t["bin"])]
    },
    "fileManager": {
        "current": cur_fm,
        "installed": [f for f in all_file_managers if check_bin(f["bin"])]
    }
}
print(json.dumps(res))
EOF
}

case "${1:-get-state}" in
  get-state)
    cmd_get_state
    ;;

  set-browser)
    desktop_id="${2:-}"
    if [[ -n "$desktop_id" ]]; then
      snap=""
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$MIME_FILE" ]]; then
        snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$MIME_FILE" 2>/dev/null || true)
      fi

      xdg-settings set default-web-browser "$desktop_id" 2>/dev/null || true
      xdg-mime default "$desktop_id" x-scheme-handler/http x-scheme-handler/https text/html

      if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record "defaults" "Default Web Browser ($desktop_id)" "$MIME_FILE" "$snap" >/dev/null 2>&1 || true
      fi
    fi
    cmd_get_state
    ;;

  set-editor)
    code="${2:-nvim}"
    desktop_id="${3:-nvim.desktop}"
    mkdir -p "$HOME/.local/state/omarchy/defaults"
    echo "$code" > "$HOME/.local/state/omarchy/defaults/editor"
    if [[ -n "$desktop_id" ]]; then
      snap=""
      if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$MIME_FILE" ]]; then
        snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$MIME_FILE" 2>/dev/null || true)
      fi

      xdg-mime default "$desktop_id" text/plain 2>/dev/null || true

      if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
        "$SCRIPT_DIR/config-tracker.sh" record "defaults" "Default Text Editor ($desktop_id)" "$MIME_FILE" "$snap" >/dev/null 2>&1 || true
      fi
    fi
    cmd_get_state
    ;;

  set-terminal)
    desktop_id="${2:-Alacritty.desktop}"
    term_list="$HOME/.config/xdg-terminals.list"
    snap=""
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$term_list" ]]; then
      snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$term_list" 2>/dev/null || true)
    fi

    cat > "$term_list" << EOF
# Terminal emulator preference order for xdg-terminal-exec
# The first found and valid terminal will be used
$desktop_id
EOF

    if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record "defaults" "Default Terminal ($desktop_id)" "$term_list" "$snap" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  set-file-manager)
    desktop_id="${2:-org.gnome.Nautilus.desktop}"
    snap=""
    if [[ -x "$SCRIPT_DIR/config-tracker.sh" && -f "$MIME_FILE" ]]; then
      snap=$("$SCRIPT_DIR/config-tracker.sh" snapshot "$MIME_FILE" 2>/dev/null || true)
    fi

    xdg-mime default "$desktop_id" inode/directory

    if [[ -n "$snap" && -x "$SCRIPT_DIR/config-tracker.sh" ]]; then
      "$SCRIPT_DIR/config-tracker.sh" record "defaults" "Default File Manager ($desktop_id)" "$MIME_FILE" "$snap" >/dev/null 2>&1 || true
    fi
    cmd_get_state
    ;;

  launch-app)
    kind="${2:-browser}"
    case "$kind" in
      browser) omarchy-launch-browser >/dev/null 2>&1 & ;;
      editor) omarchy-launch-editor "$HOME" >/dev/null 2>&1 & ;;
      terminal) omarchy-launch-terminal >/dev/null 2>&1 & ;;
      file-manager) omarchy-launch-nautilus >/dev/null 2>&1 & ;;
    esac
    ;;

  *)
    echo "Unknown command: ${1:-}" >&2
    exit 1
    ;;
esac
