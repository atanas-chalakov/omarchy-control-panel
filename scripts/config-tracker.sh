#!/usr/bin/env python3
import sys
import os
import json
import difflib
import subprocess
import time
import re
import shutil
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

CONFIG_REGISTRY = [
    {"id": "wm", "category": "windows", "name": "Window Manager", "path": str(HOME / ".local/state/omarchy/toggles/hypr/wm-settings.lua"), "icon": "󰖲", "type": "lua"},
    {"id": "touch", "category": "input", "name": "Touch & Gestures", "path": str(HOME / ".local/state/omarchy/toggles/hypr/touch-settings.lua"), "icon": "󰟀", "type": "lua"},
    {"id": "bindings", "category": "shortcuts", "name": "Key Bindings", "path": str(HOME / ".config/hypr/bindings.lua"), "icon": "󰌌", "type": "lua"},
    {"id": "monitors", "category": "displays", "name": "Monitors & Scale", "path": str(HOME / ".config/hypr/monitors.lua"), "icon": "󰍹", "type": "lua"},
    {"id": "shell", "category": "power", "name": "Shell UI & Panels", "path": str(HOME / ".config/omarchy/shell.json"), "icon": "", "type": "json"},
    {"id": "keyboard", "category": "region", "name": "Keyboard Layouts", "path": str(HOME / ".local/state/omarchy/toggles/hypr/keyboard-layout.lua"), "icon": "󰌌", "type": "lua"},
    {"id": "mime", "category": "defaults", "name": "Default Apps (MIME)", "path": str(HOME / ".config/mimeapps.list"), "icon": "󰈔", "type": "ini"},
    {"id": "theme", "category": "appearance", "name": "Active Theme", "path": str(HOME / ".local/state/omarchy/current/theme.name"), "icon": "󰉼", "type": "txt"},
]

def to_display_path(p: Path) -> str:
    s = str(p)
    home_str = str(HOME)
    if s.startswith(home_str):
        return "~" + s[len(home_str):]
    return s

hunk_pattern = re.compile(r"^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@")

def parse_diff_lines(diff_text: str):
    parsed = []
    lines_added = 0
    lines_removed = 0
    old_line = 0
    new_line = 0
    in_hunk = False
    
    for line in diff_text.splitlines():
        if line.startswith("---") or line.startswith("+++"):
            continue
        elif line.startswith("\\"):
            # Ignore '\ No newline at end of file' indicator so it does not skew line numbering
            continue
        elif line.startswith("@@"):
            m = hunk_pattern.match(line)
            if m:
                old_line = int(m.group(1))
                new_line = int(m.group(3))
                in_hunk = True
            parsed.append({
                "type": "header",
                "text": line,
                "rawText": line,
                "oldLine": "",
                "newLine": ""
            })
        elif line.startswith("+"):
            lines_added += 1
            parsed.append({
                "type": "add",
                "text": line[1:] if len(line) > 1 else "",
                "rawText": line,
                "oldLine": "",
                "newLine": str(new_line) if (in_hunk and new_line > 0) else ""
            })
            if in_hunk and new_line > 0:
                new_line += 1
        elif line.startswith("-"):
            lines_removed += 1
            parsed.append({
                "type": "del",
                "text": line[1:] if len(line) > 1 else "",
                "rawText": line,
                "oldLine": str(old_line) if (in_hunk and old_line > 0) else "",
                "newLine": ""
            })
            if in_hunk and old_line > 0:
                old_line += 1
        else:
            text = line[1:] if (line.startswith(" ") and len(line) > 1) else (line if not line.startswith(" ") else "")
            parsed.append({
                "type": "context",
                "text": text,
                "rawText": line,
                "oldLine": str(old_line) if (in_hunk and old_line > 0) else "",
                "newLine": str(new_line) if (in_hunk and new_line > 0) else ""
            })
            if in_hunk:
                if old_line > 0:
                    old_line += 1
                if new_line > 0:
                    new_line += 1
                
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

    b_lines = [l + "\n" for l in before_text.splitlines()]
    a_lines = [l + "\n" for l in after_text.splitlines()]
    diff_lines = list(difflib.unified_diff(
        b_lines,
        a_lines,
        fromfile=to_display_path(target),
        tofile=to_display_path(target),
        n=3
    ))
    diff_text = "".join(diff_lines)
    parsed_lines, lines_added, lines_removed = parse_diff_lines(diff_text)
    
    # Store before and after text if size is reasonable (< 250KB) to allow instant revert
    keep_before = before_text if len(before_text) < 250000 else None
    keep_after = after_text if len(after_text) < 250000 else None

    entry = {
        "id": int(time.time() * 1000),
        "timestamp": time.strftime("%H:%M:%S"),
        "category": category,
        "title": title,
        "file": str(target),
        "displayFile": to_display_path(target),
        "hasDiff": True,
        "changeType": "file",
        "isReversible": (keep_before is not None),
        "beforeText": keep_before if keep_before is not None else "",
        "afterText": keep_after if keep_after is not None else "",
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
        "isReversible": False,
        "command": cmd_str,
        "note": note_str,
        "diff": f"Action: {title}\nCommand: {cmd_str}" + (f"\nNote: {note_str}" if note_str else ""),
        "lines": [
            {"type": "header", "text": f"Runtime Command: {title}", "rawText": f"Runtime Command: {title}", "oldLine": "", "newLine": ""},
            {"type": "add", "text": f"$ {cmd_str}", "rawText": f"$ {cmd_str}", "oldLine": "", "newLine": "1"}
        ] + ([{"type": "context", "text": f"Note: {note_str}", "rawText": f"Note: {note_str}", "oldLine": "", "newLine": "2"}] if note_str else []),
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

def cmd_revert(entry_id_arg: str = ""):
    history = []
    if HISTORY_FILE.exists():
        try:
            history = json.loads(HISTORY_FILE.read_text())
        except Exception:
            pass

    target_entry = None
    if entry_id_arg and entry_id_arg != "latest":
        try:
            target_id = int(entry_id_arg)
            for h in history:
                if h.get("id") == target_id:
                    target_entry = h
                    break
        except Exception:
            pass
        if not target_entry:
            print(json.dumps({"success": False, "message": f"Entry ID {entry_id_arg} not found in history"}))
            return
    else:
        if LATEST_FILE.exists():
            try:
                target_entry = json.loads(LATEST_FILE.read_text())
            except Exception:
                pass
        if not target_entry and history:
            target_entry = history[0]

    if not target_entry:
        print(json.dumps({"success": False, "message": "No modification found to revert"}))
        return

    if target_entry.get("changeType") == "command":
        print(json.dumps({"success": False, "message": "Runtime CLI commands cannot be automatically reverted"}))
        return

    before_text = target_entry.get("beforeText")
    target_path_str = target_entry.get("file")
    if before_text is None or not target_path_str:
        print(json.dumps({"success": False, "message": "No snapshot content available to revert"}))
        return

    target = Path(target_path_str).expanduser()
    current_text = target.read_text(errors="replace") if target.exists() else ""
    
    if current_text == before_text:
        print(json.dumps({"success": False, "message": "File is already in the original state"}))
        return

    # Write back previous text
    try:
        target.write_text(before_text)
    except Exception as e:
        print(json.dumps({"success": False, "message": f"Failed writing to {target}: {e}"}))
        return

    # Trigger appropriate reload hooks
    target_str = str(target)
    if "hypr" in target_str or target.suffix == ".lua":
        try:
            subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
    elif "shell.json" in target_str:
        try:
            subprocess.run(["omarchy", "restart", "shell"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    # Record revert diff
    c_lines = [l + "\n" for l in current_text.splitlines()]
    b_lines = [l + "\n" for l in before_text.splitlines()]
    diff_lines = list(difflib.unified_diff(
        c_lines,
        b_lines,
        fromfile=to_display_path(target),
        tofile=to_display_path(target),
        n=3
    ))
    diff_text = "".join(diff_lines)
    parsed_lines, lines_added, lines_removed = parse_diff_lines(diff_text)
    
    revert_entry = {
        "id": int(time.time() * 1000),
        "timestamp": time.strftime("%H:%M:%S"),
        "category": target_entry.get("category", "system"),
        "title": "Reverted: " + target_entry.get("title", "Setting"),
        "file": str(target),
        "displayFile": to_display_path(target),
        "hasDiff": True,
        "changeType": "file",
        "isReversible": True,
        "beforeText": current_text,
        "afterText": before_text,
        "diff": diff_text,
        "lines": parsed_lines,
        "linesAdded": lines_added,
        "linesRemoved": lines_removed
    }
    
    LATEST_FILE.write_text(json.dumps(revert_entry, indent=2))
    history.insert(0, revert_entry)
    history = history[:50]
    HISTORY_FILE.write_text(json.dumps(history, indent=2))
    
    print(json.dumps({"success": True, "title": revert_entry["title"], "entry": revert_entry}))

def cmd_copy(text: str):
    try:
        proc = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
        proc.communicate(input=text.encode("utf-8"), timeout=2)
        print(json.dumps({"success": True}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def cmd_re_run(cmd_str: str):
    try:
        res = subprocess.run(["bash", "-c", cmd_str], capture_output=True, text=True, timeout=10)
        print(json.dumps({"success": res.returncode == 0, "stdout": res.stdout, "stderr": res.stderr}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def cmd_get_all_configs():
    result = []
    for cfg in CONFIG_REGISTRY:
        p = Path(cfg["path"]).expanduser()
        exists = p.exists()
        line_count = 0
        if exists:
            try:
                line_count = len(p.read_text(errors="replace").splitlines())
            except Exception:
                pass
        result.append({
            "id": cfg["id"],
            "category": cfg["category"],
            "name": cfg["name"],
            "file": str(p),
            "displayFile": to_display_path(p),
            "icon": cfg["icon"],
            "type": cfg["type"],
            "exists": exists,
            "lineCount": line_count
        })
    print(json.dumps(result))

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
            content = "\n".join(lines[:400])
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
            content = "\n".join(lines[:400])
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
    if shutil.which("code"):
        subprocess.Popen(["code", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"success": True, "editor": "code"}))
        return
    term_bin = None
    for t in ["ghostty", "kitty", "alacritty", "foot"]:
        if shutil.which(t):
            term_bin = t
            break
    if shutil.which("nvim") and term_bin:
        subprocess.Popen([term_bin, "-e", "nvim", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"success": True, "editor": f"{term_bin}+nvim"}))
        return
    subprocess.Popen(["xdg-open", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(json.dumps({"success": True, "editor": "xdg-open"}))

def cmd_clear_history():
    if HISTORY_FILE.exists():
        HISTORY_FILE.unlink()
    if LATEST_FILE.exists():
        LATEST_FILE.unlink()
    print(json.dumps({"success": True}))

def main():
    if len(sys.argv) < 2:
        print("Usage: config-tracker.sh <snapshot|record|record-command|revert|copy|re-run|get-all-configs|get-latest|get-history|get-category-file|get-file-content|open-editor|clear-history> [args...]")
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
    elif cmd == "revert":
        entry_id = sys.argv[2] if len(sys.argv) > 2 else "latest"
        cmd_revert(entry_id)
    elif cmd == "copy":
        if len(sys.argv) < 3:
            print("Missing text to copy")
            sys.exit(1)
        cmd_copy(sys.argv[2])
    elif cmd == "re-run":
        if len(sys.argv) < 3:
            print("Missing command to re-run")
            sys.exit(1)
        cmd_re_run(sys.argv[2])
    elif cmd == "get-all-configs":
        cmd_get_all_configs()
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
