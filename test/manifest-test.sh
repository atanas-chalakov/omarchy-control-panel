#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

# 1. Manifest file exists
[[ -f "$MANIFEST" ]] || fail "manifest.json exists in project root"
pass "manifest.json file exists"

# 2. Manifest is valid JSON
jq -e . "$MANIFEST" >/dev/null 2>&1 || fail "manifest.json is valid JSON"
pass "manifest.json is valid JSON"

# 3. schemaVersion is integer 1
[[ "$(jq -r '.schemaVersion' "$MANIFEST")" == "1" ]] || fail "schemaVersion is 1"
pass "manifest schemaVersion is 1"

# 4. Plugin ID is ac.control-panel
plugin_id=$(jq -r '.id // ""' "$MANIFEST")
[[ "$plugin_id" == "ac.control-panel" ]] || fail "manifest id is ac.control-panel"
pass "manifest id matches ac.control-panel"

# 5. Kinds array contains panel and bar-widget
has_panel_kind=$(jq -r 'if (.kinds | type == "array") and (.kinds | index("panel") != null) then "true" else "false" end' "$MANIFEST")
[[ "$has_panel_kind" == "true" ]] || fail "kinds includes 'panel'"
pass "manifest kinds includes 'panel'"

has_bar_widget_kind=$(jq -r 'if (.kinds | type == "array") and (.kinds | index("bar-widget") != null) then "true" else "false" end' "$MANIFEST")
[[ "$has_bar_widget_kind" == "true" ]] || fail "kinds includes 'bar-widget'"
pass "manifest kinds includes 'bar-widget'"

# 6. entryPoints.panel and entryPoints.barWidget exist and point to valid files
entry_panel=$(jq -r '.entryPoints.panel // ""' "$MANIFEST")
[[ -n "$entry_panel" ]] || fail "entryPoints.panel is specified"
[[ -f "$ROOT/$entry_panel" ]] || fail "entryPoints.panel file ($entry_panel) exists on disk"
pass "entryPoints.panel points to existing file ($entry_panel)"

entry_bar_widget=$(jq -r '.entryPoints.barWidget // ""' "$MANIFEST")
[[ -n "$entry_bar_widget" ]] || fail "entryPoints.barWidget is specified"
[[ -f "$ROOT/$entry_bar_widget" ]] || fail "entryPoints.barWidget file ($entry_bar_widget) exists on disk"
pass "entryPoints.barWidget points to existing file ($entry_bar_widget)"

# 7. Disallowed symlinks within project (excluding .git)
bad_links=$(find "$ROOT" -name .git -prune -o -type l -print 2>/dev/null || true)
[[ -z "$bad_links" ]] || fail "no symlinks inside plugin project directory" "$bad_links"
pass "no forbidden symlinks found inside plugin directory"

# 8. omarchy plugin validate CLI tool
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$ROOT" >/dev/null 2>&1 || fail "omarchy plugin validate passes"
  pass "omarchy plugin validate succeeds"
else
  skip "omarchy CLI not available for validation"
fi

# 9. Plugin is symlinked in ~/.config/omarchy/plugins/
target_link="$HOME/.config/omarchy/plugins/ac.control-panel"
if [[ -L "$target_link" ]]; then
  link_target=$(readlink -f "$target_link")
  current_target=$(readlink -f "$ROOT")
  [[ "$link_target" == "$current_target" ]] || fail "active plugin link points to this repository" "Expected $current_target, got $link_target"
  pass "plugin is correctly symlinked in ~/.config/omarchy/plugins/ac.control-panel"
else
  skip "plugin symlink in ~/.config/omarchy/plugins/ac.control-panel not found"
fi
