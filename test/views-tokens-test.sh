#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command python3

# 1. Verify all 16 categories in ControlPanel.qml map to existing view files
python3 - "$ROOT" <<'PY'
import sys, re
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
cp_qml = root / "ControlPanel.qml"
views_dir = root / "views"

content = cp_qml.read_text()
# Find category view mappings in categories array
view_refs = re.findall(r'view:\s*"(views/[A-Za-z0-9_-]+\.qml)"', content)

if not view_refs:
    print("Failed to find any category view mappings in ControlPanel.qml", file=sys.stderr)
    sys.exit(1)

for v in view_refs:
    p = root / v
    if not p.exists():
        print(f"Referenced view not found: {v}", file=sys.stderr)
        sys.exit(1)

print(f"Verified {len(view_refs)} category views exist")
PY

pass "all categories in ControlPanel.qml map to existing view files"

# 2. Check all QML files for balanced braces and parentheses
python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
qml_files = list(root.glob("*.qml")) + list((root / "views").glob("*.qml"))

if len(qml_files) < 18:
    print(f"Expected at least 18 QML files, found {len(qml_files)}", file=sys.stderr)
    sys.exit(1)

for q in qml_files:
    text = q.read_text(errors="replace")
    
    # Strip comments and string literals to check bracket balance
    clean = []
    i = 0
    in_line_comment = False
    in_block_comment = False
    in_str = None
    in_regex = False
    prev_char = ""
    
    while i < len(text):
        c = text[i]
        nxt = text[i+1] if i + 1 < len(text) else ""
        
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1
            continue
        if in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == "\\" and i + 1 < len(text):
                i += 2
                continue
            if c == in_str:
                in_str = None
            i += 1
            continue
        if in_regex:
            if c == "\\" and i + 1 < len(text):
                i += 2
                continue
            if c == "/":
                in_regex = False
            i += 1
            continue
            
        if c == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
        if c == "/" and prev_char in "=(,:[!&|?{;":
            in_regex = True
            i += 1
            continue
            
        if c in ("\"", "'", "`"):
            in_str = c
            i += 1
            continue
            
        if c in "{}[]()":
            clean.append(c)
        if not c.isspace():
            prev_char = c
        i += 1
        
    stack = []
    pairs = {"}": "{", "]": "[", ")": "("}
    for char in clean:
        if char in "{[(":
            stack.append(char)
        elif char in "}])":
            if not stack or stack[-1] != pairs[char]:
                print(f"Bracket mismatch in {q.name}: unexpected {char}", file=sys.stderr)
                sys.exit(1)
            stack.pop()
            
    if stack:
        print(f"Unclosed brackets in {q.name}: {stack}", file=sys.stderr)
        sys.exit(1)

print(f"Verified syntax and balanced brackets in {len(qml_files)} QML files")
PY

pass "all 18 QML files have valid balanced bracket structure"

# 3. Check Design Token Compliance & Ban prohibited pickAlpha
found_pickalpha=$(grep -rn "pickAlpha" "$ROOT"/ControlPanel.qml "$VIEWS_DIR"/*.qml || true)
[[ -z "$found_pickalpha" ]] || fail "no prohibited pickAlpha usage found in QML files" "$found_pickalpha"
pass "design token compliance: no prohibited pickAlpha calls found"

# 4. Check DiffInspector feature presence
diff_qml="$VIEWS_DIR/DiffInspector.qml"
[[ -f "$diff_qml" ]] || fail "DiffInspector.qml exists"

grep -q "oldLine" "$diff_qml" || fail "DiffInspector implements oldLine gutter column"
grep -q "newLine" "$diff_qml" || fail "DiffInspector implements newLine gutter column"
grep -q "revertChange" "$diff_qml" || fail "DiffInspector implements revertChange method"
grep -q "diffInspectorExpanded" "$ROOT/ControlPanel.qml" || fail "ControlPanel implements diffInspectorExpanded property"
pass "DiffInspector features (gutter numbers, revertChange, expand mode) are verified in source"
