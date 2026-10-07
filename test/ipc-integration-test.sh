#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

require_compositor "live shell IPC integration"

if ! command -v omarchy-shell >/dev/null 2>&1; then
  skip "omarchy-shell not installed; skipping live shell IPC"
  exit 0
fi

# 1. Shell responds to ping
ping_out=$(omarchy-shell shell ping 2>/dev/null || true)
[[ "$ping_out" == "ok" ]] || fail "shell responds to ping IPC"
pass "shell responds to ping IPC"

# 2. Control panel plugin is registered and enabled
plugins_json=$(omarchy-shell shell listPlugins 2>/dev/null || true)
has_plugin=$(echo "$plugins_json" | jq -r 'any(.[]; .id == "ac.control-panel" and .enabled == true)')
[[ "$has_plugin" == "true" ]] || fail "ac.control-panel is listed and enabled in shell"
pass "ac.control-panel is registered and enabled in live shell"

# 3. Test summon IPC with search category
summon_search=$(omarchy-shell shell summon ac.control-panel '{"category":"search"}' 2>/dev/null || true)
[[ "$summon_search" == "ok" ]] || fail "summoning ac.control-panel with search payload succeeds"
pass "summoning ac.control-panel with search payload succeeded"

# 4. Test summon IPC with diff inspector opened
summon_diff=$(omarchy-shell shell summon ac.control-panel '{"diff":true,"category":"windows"}' 2>/dev/null || true)
[[ "$summon_diff" == "ok" ]] || fail "summoning ac.control-panel with diff payload succeeds"
pass "summoning ac.control-panel with diff payload succeeded"

# 5. Clean up: hide panel
omarchy-shell -q shell hide ac.control-panel || true
pass "panel hide IPC completed cleanly"
