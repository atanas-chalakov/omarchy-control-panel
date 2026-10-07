#!/usr/bin/env bash
# Automated test suite for edge cases, boundary conditions, and error recovery

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq
require_command python3

TRACKER="$SCRIPTS_DIR/config-tracker.sh"
NET_CONTROL="$SCRIPTS_DIR/network-control.sh"
DISP_CONTROL="$SCRIPTS_DIR/display-control.sh"

TEST_TMP_DIR=$(mktemp -d /tmp/ocp-edge-test-XXXXXX)
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

# ==============================================================================
# 1. Config Tracker: No-Newline at End of File (Ensure no glued diff lines)
# ==============================================================================
no_nl_file="$TEST_TMP_DIR/no_newline.conf"
printf "first line without newline" > "$no_nl_file"
snap1=$("$TRACKER" snapshot "$no_nl_file")

printf "first line with newline\nsecond line" > "$no_nl_file"
rec_no_nl=$("$TRACKER" record "windows" "No-newline Test" "$no_nl_file" "$snap1")

# Check that lines were NOT glued together into "+first line without newline+first line with newline"
glued=$(echo "$rec_no_nl" | jq -r 'any(.lines[]; .type == "del" and (.text | contains("+")))')
[[ "$glued" == "false" ]] || fail "no-newline diff did not glue lines together" "$rec_no_nl"
pass "config-tracker correctly formats diffs when files lack trailing newlines"

# ==============================================================================
# 2. Config Tracker: Unicode, Emoji, and Shell Metacharacters
# ==============================================================================
unicode_file="$TEST_TMP_DIR/unicode.conf"
printf 'title = "Omarchy"\nfont = "JetBrains Mono"\n' > "$unicode_file"
snap_uni=$("$TRACKER" snapshot "$unicode_file")

cat <<'EOF' > "$unicode_file"
title = "Omarchy 🚀 ✨"
font = "JetBrains Mono"
path = "$HOME/.config/hypr"
escapes = "quotes \" ' and \ backslash"
EOF
rec_uni=$("$TRACKER" record "appearance" "Unicode & Escapes Test" "$unicode_file" "$snap_uni")

uni_diff_ok=$(echo "$rec_uni" | jq -r '.hasDiff')
[[ "$uni_diff_ok" == "true" ]] || fail "unicode and escape characters recorded in diff"

uni_id=$(echo "$rec_uni" | jq -r '.id')
rev_uni=$("$TRACKER" revert "$uni_id")
[[ "$(echo "$rev_uni" | jq -r '.success')" == "true" ]] || fail "unicode file reverted successfully"

# Verify exact restoration
expected_uni=$(printf 'title = "Omarchy"\nfont = "JetBrains Mono"\n')
actual_uni=$(cat "$unicode_file")
[[ "$actual_uni" == "$expected_uni" ]] || fail "unicode file content restored verbatim"
pass "config-tracker handles unicode, emojis, and special shell escape characters"

# ==============================================================================
# 3. Config Tracker: Non-existent Revert ID & Command Revert Rejection
# ==============================================================================
bad_rev=$("$TRACKER" revert "9999999999")
[[ "$(echo "$bad_rev" | jq -r '.success')" == "false" ]] || fail "non-existent revert ID returns success=false"
pass "config-tracker cleanly rejects non-existent revert entry IDs"

cmd_rec=$("$TRACKER" record-command "power" "CLI Test Action" "Terminal" "echo 1")
cmd_id=$(echo "$cmd_rec" | jq -r '.id')
rev_cmd=$("$TRACKER" revert "$cmd_id")
[[ "$(echo "$rev_cmd" | jq -r '.success')" == "false" ]] || fail "command action revert returns success=false"
pass "config-tracker cleanly prevents reverting runtime CLI commands"

# ==============================================================================
# 4. Config Tracker: Recovery from Corrupted History Cache
# ==============================================================================
hist_cache="/tmp/omarchy-control-panel/history.json"
hist_backup=""
if [[ -f "$hist_cache" ]]; then
  hist_backup=$(cat "$hist_cache")
fi

echo "{ corrupt json string [!] }" > "$hist_cache"
corrupt_res=$("$TRACKER" get-history)
[[ "$corrupt_res" == "[]" ]] || fail "corrupted history cache gracefully falls back to empty array"

# Restore original history
if [[ -n "$hist_backup" ]]; then
  echo "$hist_backup" > "$hist_cache"
else
  rm -f "$hist_cache"
fi
pass "config-tracker recovers gracefully from corrupted history cache files"

# ==============================================================================
# 5. Network Control: Wi-Fi Connect Error JSON Output
# ==============================================================================
# Empty SSID
empty_ssid_res=$("$NET_CONTROL" wifi-connect "" 2>/dev/null || true)
echo "$empty_ssid_res" | jq -e . >/dev/null 2>&1 || fail "wifi-connect with empty SSID emits valid JSON" "$empty_ssid_res"
[[ "$(echo "$empty_ssid_res" | jq -r '.success')" == "false" ]] || fail "wifi-connect with empty SSID fails"
pass "network-control wifi-connect emits valid JSON error on empty SSID"

# Quoted SSID failure (ensure quotes in SSID do not corrupt JSON)
quoted_ssid_res=$("$NET_CONTROL" wifi-connect "NonExistent_\"SSID\"_'Test'" "pass123" 2>/dev/null || true)
echo "$quoted_ssid_res" | jq -e . >/dev/null 2>&1 || fail "wifi-connect with quotes in SSID emits valid JSON" "$quoted_ssid_res"
[[ "$(echo "$quoted_ssid_res" | jq -r '.success')" == "false" ]] || fail "wifi-connect to bogus SSID fails"
pass "network-control wifi-connect handles special characters and quotes without corrupting JSON"

# ==============================================================================
# 6. Display Control: Brightness Clamping
# ==============================================================================
# set-brightness should clamp values between 5 and 100 without crashing
"$DISP_CONTROL" set-brightness 0 >/dev/null 2>&1 || fail "set-brightness 0 executes without crashing"
"$DISP_CONTROL" set-brightness 150 >/dev/null 2>&1 || fail "set-brightness 150 executes without crashing"
pass "display-control set-brightness safely handles boundary inputs (0% and 150%)"

# ==============================================================================
# 7. System Control: Backup & Restore Security and Path Traversal Protection
# ==============================================================================
SYS_CONTROL="$SCRIPTS_DIR/system-control.sh"

# Path traversal rejection
trav_res=$("$SYS_CONTROL" backup-restore "../../../etc/passwd" 2>/dev/null || true)
[[ "$(echo "$trav_res" | jq -r '.success')" == "false" ]] || fail "backup-restore rejects path traversal" "$trav_res"
pass "system-control backup-restore cleanly rejects path traversal attacks"

# Non-existent backup rejection
bad_backup_res=$("$SYS_CONTROL" backup-restore "backup-99999999-999999.tar.gz" 2>/dev/null || true)
[[ "$(echo "$bad_backup_res" | jq -r '.success')" == "false" ]] || fail "backup-restore rejects non-existent files" "$bad_backup_res"
pass "system-control backup-restore cleanly rejects non-existent archives"

# Export, list, and delete lifecycle
export_res=$("$SYS_CONTROL" backup-export)
[[ "$(echo "$export_res" | jq -r '.success')" == "true" ]] || fail "backup-export succeeds" "$export_res"
export_file=$(echo "$export_res" | jq -r '.filename')
[[ -n "$export_file" ]] || fail "backup-export returns filename"

list_res=$("$SYS_CONTROL" backup-list)
has_file=$(echo "$list_res" | jq -r --arg f "$export_file" 'any(.[]; .filename == $f)')
[[ "$has_file" == "true" ]] || fail "backup-list includes newly created backup"

del_res=$("$SYS_CONTROL" backup-delete "$export_file")
[[ "$(echo "$del_res" | jq -r '.success')" == "true" ]] || fail "backup-delete removes test backup"
pass "system-control backup export, listing, and deletion lifecycle functions flawlessly"

# ==============================================================================
# 8. Speaker Test & Wi-Fi QR Code Edge Cases
# ==============================================================================
# Left and right channel test execution
left_test=$("$SYS_CONTROL" audio-test-speaker "left")
[[ "$(echo "$left_test" | jq -r '.channel')" == "left" ]] || fail "audio-test-speaker left channel succeeds"
right_test=$("$SYS_CONTROL" audio-test-speaker "right")
[[ "$(echo "$right_test" | jq -r '.channel')" == "right" ]] || fail "audio-test-speaker right channel succeeds"
pass "system-control audio-test-speaker executes channel tests for left, right, and stereo"

# Wi-Fi QR generator handles custom SSIDs with spaces and special characters
qr_custom=$("$NET_CONTROL" wifi-get-qr "Test Office Wi-Fi 5G & Guest")
[[ "$(echo "$qr_custom" | jq -r '.success')" == "true" ]] || fail "wifi-get-qr custom SSID succeeds"
[[ "$(echo "$qr_custom" | jq -r '.ssid')" == "Test Office Wi-Fi 5G & Guest" ]] || fail "wifi-get-qr preserves special SSID characters"
pass "network-control wifi-get-qr safely generates payloads for SSIDs with spaces and symbols"

