#!/usr/bin/env python3
import sys
import os
import json
import difflib
import subprocess
import time
from pathlib import Path

BASE_TMP = Path("/tmp/omarchy-control-panel")
BASE_TMP.mkdir(parents=True, exist_ok=True)
HISTORY_FILE = BASE_TMP / "history.json"
LATEST_FILE = BASE_TMP / "latest.json"

HOME = Path.home()

CATEGORY_FILES = {
    "windows": HOME / ".local/state/omarchy/toggles/hypr/wm-settings.lua",
    "input": HOME / ".local/state/omarchy/toggles/hypr/touch-settings.lua",
    "region": HOME / ".local/state/omarchy/toggles/hypr/keyboard-layout.lua",
    "power": HOME / ".config/omarchy/shell.json",
    "defaults": HOME / ".config/mimeapps.list",
    "appearance": (HOME / ".local/state/omarchy/current/theme.name") if (HOME / ".local/state/omarchy/current/theme.name").exists() else (HOME / ".config/omarchy/shell.json"),
    "displays": HOME / ".config/hypr/monitors.lua",
    "shortcuts": HOME / ".config/hypr/bindings.lua",
    "notifications": HOME / ".config/omarchy/shell.json",
    "sound": HOME / ".config/omarchy/shell.json",
    "bluetooth": HOME / ".config/omarchy/shell.json",
    "network": HOME / ".config/omarchy/shell.json",
    "updates": Path("/var/log/pacman.log"),
    "about": HOME / ".config/omarchy/shell.json",
}

def to_display_path(p: Path) -> str:
    s = str(p)
    home_str = str(HOME)
    if s.startswith(home_str):
        return "~" + s[len(home_str):]
    return s

def parse_diff_lines(diff_text: str):
    parsed = []
    lines_added = 0
    lines_removed = 0
    for line in diff_text.splitlines():
        if line.startswith("---") or line.startswith("+++"):
            continue
        elif line.startswith("@@"):
            parsed.append({"type": "header", "text": line})
        elif line.startswith("+"):
            lines_added += 1
            parsed.append({"type": "add", "text": line})
        elif line.startswith("-"):
            lines_removed += 1
            parsed.append({"type": "del", "text": line})
        else:
            parsed.append({"type": "context", "text": line})
    return parsed, lines_added, lines_removed

def cmd_snapshot(file_path_str: str):
    p = Path(file_path_str).expanduser()
    snap_id = f"snap_{int(time.time()*1000)}"
    snap_file = BASE_TMP / snap_id
    if p.exists():
        snap_file.write_bytes(p.read_bytes())
    else:
        snap_file.write_text("")
    print(str(snap_file))

def cmd_record(category: str, title: str, target_path_str: str, before_snap_str: str):
    target = Path(target_path_str).expanduser()
    before_snap = Path(before_snap_str)
    
    before_text = before_snap.read_text(errors="replace") if before_snap.exists() else ""
    after_text = target.read_text(errors="replace") if target.exists() else ""
    
    if before_snap.exists():
        try:
            before_snap.unlink()
        except OSError:
            pass
            
    if before_text == after_text:
        print(json.dumps({"hasDiff": False, "message": "No file changes detected"}))
        return

    diff_lines = list(difflib.unified_diff(
        before_text.splitlines(keepends=True),
        after_text.splitlines(keepends=True),
        fromfile=to_display_path(target),
        tofile=to_display_path(target),
        n=3
    ))
    diff_text = "".join(diff_lines)
    parsed_lines, lines_added, lines_removed = parse_diff_lines(diff_text)
    
    entry = {
        "id": int(time.time() * 1000),
        "timestamp": time.strftime("%H:%M:%S"),
        "category": category,
        "title": title,
        "file": str(target),
        "displayFile": to_display_path(target),
        "hasDiff": True,
        "diff": diff_text,
        "lines": parsed_lines,
        "linesAdded": lines_added,
        "linesRemoved": lines_removed
    }
    
    # Save latest
    LATEST_FILE.write_text(json.dumps(entry, indent=2))
    
    # Update history
    history = []
    if HISTORY_FILE.exists():
        try:
            history = json.loads(HISTORY_FILE.read_text())
        except Exception:
            history = []
    history.insert(0, entry)
    history = history[:50]
    HISTORY_FILE.write_text(json.dumps(history, indent=2))
    
    print(json.dumps(entry))

def cmd_get_latest():
    if LATEST_FILE.exists():
        try:
            data = json.loads(LATEST_FILE.read_text())
            print(json.dumps(data))
            return
        except Exception:
            pass
    print(json.dumps({"hasDiff": False}))

def cmd_get_history():
    if HISTORY_FILE.exists():
        try:
            data = json.loads(HISTORY_FILE.read_text())
            print(json.dumps(data))
            return
        except Exception:
            pass
    print("[]")

def cmd_get_category_file(category: str):
    p = CATEGORY_FILES.get(category, CATEGORY_FILES["windows"])
    exists = p.exists()
    content = ""
    line_count = 0
    if exists:
        try:
            lines = p.read_text(errors="replace").splitlines()
            line_count = len(lines)
            content = "\n".join(lines[:300]) # cap at 300 lines for UI speed
        except Exception as e:
            content = f"Error reading file: {e}"
            
    res = {
        "category": category,
        "file": str(p),
        "displayFile": to_display_path(p),
        "exists": exists,
        "lineCount": line_count,
        "content": content
    }
    print(json.dumps(res))

def cmd_get_file_content(path_str: str):
    p = Path(path_str).expanduser()
    exists = p.exists()
    content = ""
    line_count = 0
    if exists:
        try:
            lines = p.read_text(errors="replace").splitlines()
            line_count = len(lines)
            content = "\n".join(lines[:300])
        except Exception as e:
            content = f"Error reading file: {e}"
    res = {
        "file": str(p),
        "displayFile": to_display_path(p),
        "exists": exists,
        "lineCount": line_count,
        "content": content
    }
    print(json.dumps(res))

def cmd_open_editor(path_str: str):
    p = Path(path_str).expanduser()
    target = str(p)
    # Check if VS Code is available
    if os.path.exists("/usr/bin/code"):
        subprocess.Popen(["code", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"success": True, "editor": "code"}))
        return
    # Check if Alacritty + Neovim
    if os.path.exists("/usr/bin/alacritty") and os.path.exists("/usr/bin/nvim"):
        subprocess.Popen(["alacritty", "-e", "nvim", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"success": True, "editor": "nvim"}))
        return
    # Fallback to xdg-open
    subprocess.Popen(["xdg-open", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(json.dumps({"success": True, "editor": "xdg-open"}))

def cmd_record_command(category: str, title: str, display_target: str, cmd_str: str, note_str: str = ""):
    entry = {
        "id": int(time.time() * 1000),
        "timestamp": time.strftime("%H:%M:%S"),
        "category": category,
        "title": title,
        "file": display_target,
        "displayFile": display_target,
        "hasDiff": True,
        "changeType": "command",
        "diff": f"@@ {title} @@\n+ Executed: {cmd_str}\n" + (f"  Note: {note_str}\n" if note_str else ""),
        "lines": [
            {"type": "header", "text": f"@@ Runtime Action: {title} @@"},
            {"type": "add", "text": f"+ Executed: {cmd_str}"}
        ] + ([{"type": "context", "text": f"  Detail: {note_str}"}] if note_str else []),
        "linesAdded": 1,
        "linesRemoved": 0
    }
    LATEST_FILE.write_text(json.dumps(entry, indent=2))
    history = []
    if HISTORY_FILE.exists():
        try:
            history = json.loads(HISTORY_FILE.read_text())
        except Exception:
            history = []
    history.insert(0, entry)
    history = history[:50]
    HISTORY_FILE.write_text(json.dumps(history, indent=2))
    print(json.dumps(entry))

def cmd_clear_history():
    if HISTORY_FILE.exists():
        HISTORY_FILE.unlink()
    if LATEST_FILE.exists():
        LATEST_FILE.unlink()
    print(json.dumps({"success": True}))

def main():
    if len(sys.argv) < 2:
        print("Usage: config-tracker.sh <snapshot|record|record-command|get-latest|get-history|get-category-file|get-file-content|open-editor|clear-history> [args...]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    if cmd == "snapshot":
        if len(sys.argv) < 3:
            print("Missing file path for snapshot")
            sys.exit(1)
        cmd_snapshot(sys.argv[2])
    elif cmd == "record":
        if len(sys.argv) < 6:
            print("Missing arguments for record: category title target before_snap")
            sys.exit(1)
        cmd_record(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif cmd == "record-command":
        if len(sys.argv) < 6:
            print("Missing arguments for record-command: category title target command [note]")
            sys.exit(1)
        category = sys.argv[2]
        title = sys.argv[3]
        target = sys.argv[4]
        command = sys.argv[5]
        note = sys.argv[6] if len(sys.argv) > 6 else ""
        cmd_record_command(category, title, target, command, note)
    elif cmd == "get-latest":
        cmd_get_latest()
    elif cmd == "get-history":
        cmd_get_history()
    elif cmd == "clear-history":
        cmd_clear_history()
    elif cmd == "get-category-file":
        cat = sys.argv[2] if len(sys.argv) > 2 else "windows"
        cmd_get_category_file(cat)
    elif cmd == "get-file-content":
        if len(sys.argv) < 3:
            print("Missing file path")
            sys.exit(1)
        cmd_get_file_content(sys.argv[2])
    elif cmd == "open-editor":
        if len(sys.argv) < 3:
            print("Missing file path")
            sys.exit(1)
        cmd_open_editor(sys.argv[2])
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)

if __name__ == "__main__":
    main()
