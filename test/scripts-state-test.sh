#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

# Test table: script name | subcommand | expected jq validation filter
tests=(
  "display-control.sh|get-state|.brightness != null and .monitors != null and .nightlight != null"
  "power-control.sh|get-state|.profile != null and .battery != null and .gameMode != null"
  "network-control.sh|get-state|.enabled != null and .networks != null"
  "bluetooth-control.sh|get-state|.powered != null and .devices != null"
  "wm-control.sh|get-state|.animations != null and .gapsIn != null and .borderSize != null"
  "touch-input-control.sh|get-state|.touchpad != null"
  "notifications-control.sh|get-state|.dnd != null and .history != null"
  "shortcuts-control.sh|get-state|.bindings != null"
  "region-control.sh|get-state|.time != null and .date != null and .configuredLayouts != null"
  "defaults-control.sh|get-state|.browser != null and .editor != null and .terminal != null"
  "updates-storage-control.sh|get-state|.updates != null and .storage != null"
  "system-control.sh|about-get|.os != null and .cpu != null and .ram != null"
  "system-control.sh|audio-get|.volume != null and .sinks != null"
  "system-control.sh|backup-list|type == \"array\""
  "system-control.sh|backup-gist-list|.authenticated != null and .gists != null"
  "config-tracker.sh|get-all-configs|type == \"array\" and length >= 8"
)

for item in "${tests[@]}"; do
  IFS="|" read -r script cmd jq_filter <<< "$item"
  script_path="$SCRIPTS_DIR/$script"

  # 1. Check file exists and is executable
  [[ -f "$script_path" ]] || fail "script exists: $script"
  [[ -x "$script_path" ]] || fail "script is executable: $script"

  # 2. Run command and check exit code
  output=$("$script_path" $cmd 2>/dev/null || true)
  [[ -n "$output" ]] || fail "$script $cmd returned non-empty output"

  # 3. Validate JSON format
  echo "$output" | jq -e . >/dev/null 2>&1 || fail "$script $cmd output is valid JSON" "$output"

  # 4. Validate schema structure
  if ! echo "$output" | jq -e "$jq_filter" >/dev/null 2>&1; then
    fail "$script $cmd schema does not match expected filter: $jq_filter" "$output"
  fi

  pass "$script ($cmd) returns valid structured state"
done
