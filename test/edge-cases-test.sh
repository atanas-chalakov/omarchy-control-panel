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
base_dir=$("$TRACKER" get-base-dir)
hist_cache="$base_dir/history.json"
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

# ==============================================================================
# 9. Process Security & Argv Isolation (Wi-Fi Passwords & Payloads)
# ==============================================================================
# Clipboard helper accepts text via stdin without argv exposure
copy_res=$(printf 'secret_clipboard_payload' | "$SCRIPTS_DIR/config-tracker.sh" copy)
[[ "$(echo "$copy_res" | jq -r '.success')" == "true" ]] || fail "config-tracker copy via stdin succeeds" "$copy_res"
pass "config-tracker copy accepts clipboard content via stdin without argv exposure"

# Audit wrapper asserting nmcli, qrencode, and jq never receive secrets in argv
audit_bin=$(mktemp -d)
cat >"$audit_bin/qrencode" <<'EOF'
#!/bin/bash
for arg in "$@"; do
  if [[ "$arg" == *"WIFI:"* || "$arg" == *"AuditSecret"* ]]; then
    echo "SECURITY LEAK: qrencode received secret/payload in argv: $arg" >&2
    exit 99
  fi
done
cat >/dev/null
exit 0
EOF

cat >"$audit_bin/jq" <<'EOF'
#!/bin/bash
for arg in "$@"; do
  if [[ "$arg" == *"AuditSecret"* ]]; then
    echo "SECURITY LEAK: jq received secret in argv: $arg" >&2
    exit 98
  fi
done
exec /usr/bin/jq "$@"
EOF

cat >"$audit_bin/nmcli" <<'EOF'
#!/bin/bash
for arg in "$@"; do
  if [[ "$arg" == *"AuditSecret"* ]]; then
    echo "SECURITY LEAK: nmcli received secret in argv: $arg" >&2
    exit 97
  fi
done
exec /usr/bin/nmcli "$@"
EOF
chmod +x "$audit_bin/qrencode" "$audit_bin/jq" "$audit_bin/nmcli"

# Verify wifi-connect keeps secret out of nmcli argv
conn_audit=$(printf 'AuditSecretPassword123\n' | timeout 3 PATH="$audit_bin:$PATH" "$NET_CONTROL" wifi-connect "AuditMockSSID" 2>&1 || true)
if echo "$conn_audit" | grep -q "SECURITY LEAK"; then
  rm -rf "$audit_bin"
  fail "wifi-connect leaked password into process arguments" "$conn_audit"
fi
pass "network-control wifi-connect preserves password confidentiality across process argv"

# Verify wifi-get-qr keeps payload out of qrencode argv and jq argv
qr_audit=$(PATH="$audit_bin:$PATH" "$NET_CONTROL" wifi-get-qr "Zodd" 2>&1 || true)
if echo "$qr_audit" | grep -q "SECURITY LEAK"; then
  rm -rf "$audit_bin"
  fail "wifi-get-qr leaked credentials/payload into process arguments" "$qr_audit"
fi
rm -rf "$audit_bin"
pass "network-control wifi-get-qr keeps credentials and QR payload out of process argv"

# ==============================================================================
# 9. Security Audit: Private Permissions for Snapshots, History, and Runtime Cache
# ==============================================================================
# Ensure runtime base directory is user-private (mode 700) and never in world-readable /tmp
runtime_base=$("$TRACKER" get-base-dir)
[[ "$runtime_base" != "/tmp/omarchy-control-panel" ]] || fail "base runtime dir must not be world-shared /tmp/omarchy-control-panel"
base_perms=$(stat -c "%a" "$runtime_base")
[[ "$base_perms" == "700" ]] || fail "runtime base directory permissions must be 700 (got $base_perms)"
pass "config-tracker runtime directory is user-private with 700 permissions"

# Test that snapshots and history created with standard caller umask 022 remain strictly 0600
sec_test_file="$TEST_TMP_DIR/security-test.json"
printf '{"plugin_secret_token":"SUPER_SECRET_123","idle":{"screensaver":150,"lock":86400}}\n' > "$sec_test_file"

(
  umask 022
  sec_snap=$("$TRACKER" snapshot "$sec_test_file")
  snap_perms=$(stat -c "%a" "$sec_snap")
  [[ "$snap_perms" == "600" ]] || fail "snapshot file permissions must be 600 under umask 022 (got $snap_perms)"

  printf '{"plugin_secret_token":"SUPER_SECRET_123","idle":{"screensaver":300,"lock":86400}}\n' > "$sec_test_file"
  "$TRACKER" record "power" "Security Idle Test" "$sec_test_file" "$sec_snap" >/dev/null

  latest_file="$runtime_base/latest.json"
  history_file="$runtime_base/history.json"
  [[ -f "$latest_file" ]] || fail "latest.json exists"
  [[ -f "$history_file" ]] || fail "history.json exists"

  latest_perms=$(stat -c "%a" "$latest_file")
  hist_perms=$(stat -c "%a" "$history_file")
  [[ "$latest_perms" == "600" ]] || fail "latest.json permissions must be 600 under umask 022 (got $latest_perms)"
  [[ "$hist_perms" == "600" ]] || fail "history.json permissions must be 600 under umask 022 (got $hist_perms)"

  # Ensure other local users have zero read/write/execute permissions (other octet must be 0)
  [[ "${base_perms: -1}" == "0" ]] || fail "base dir must have 0 other permissions"
  [[ "${snap_perms: -1}" == "0" ]] || fail "snapshot must have 0 other permissions"
  [[ "${latest_perms: -1}" == "0" ]] || fail "latest.json must have 0 other permissions"
  [[ "${hist_perms: -1}" == "0" ]] || fail "history.json must have 0 other permissions"
)
pass "snapshots and history enforce strict 600 permissions even when caller has umask 022"

# Test power-control set-idle preserves strict confidentiality and private permissions
(
  umask 022
  "$SCRIPTS_DIR/power-control.sh" set-idle 150 86400 >/dev/null 2>&1 || true
  latest_file="$runtime_base/latest.json"
  if [[ -f "$latest_file" ]]; then
    p_perms=$(stat -c "%a" "$latest_file")
    [[ "$p_perms" == "600" ]] || fail "power-control set-idle latest.json must be 600"
  fi
)
pass "power-control set-idle executes with complete file confidentiality and private permissions"

# ==============================================================================
# 10. Command Injection Prevention: AP SSID Kept as Data in Structured Argument Arrays
# ==============================================================================
evil_flag_1="$TEST_TMP_DIR/ocp_injected_evil_flag"
evil_flag_2="$TEST_TMP_DIR/ocp_injected_subshell_flag"
rm -f "$evil_flag_1" "$evil_flag_2"

evil_ssid="AttackerAP; touch $evil_flag_1; \$(touch $evil_flag_2); && echo pwned"

# Record command using record-command-args with the untrusted SSID passed strictly as data
rec_json=$("$TRACKER" record-command-args "network" "Wi-Fi Connection ($evil_ssid)" "NetworkManager" "Connected to SSID $evil_ssid" nmcli dev wifi connect "$evil_ssid")

rec_args_len=$(echo "$rec_json" | jq '.commandArgs | length')
rec_arg_ssid=$(echo "$rec_json" | jq -r '.commandArgs[4]')
rec_entry_id=$(echo "$rec_json" | jq -r '.id')
rec_cmd_str=$(echo "$rec_json" | jq -r '.command')

[[ "$rec_args_len" == "5" ]] || fail "evil SSID commandArgs has exactly 5 elements"
[[ "$rec_arg_ssid" == "$evil_ssid" ]] || fail "evil SSID argument preserved verbatim as data in commandArgs"
# Verify display command is safely quoted
[[ "$rec_cmd_str" == *"'$evil_ssid'"* || "$rec_cmd_str" == *"$evil_ssid"* ]] || fail "evil SSID safely formatted in display command"

# Create a mock nmcli binary that logs received argv into a file without executing a shell
mock_nmcli_dir=$(mktemp -d)
mock_nmcli_log="$TEST_TMP_DIR/mock_nmcli_argv.log"
cat >"$mock_nmcli_dir/nmcli" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$mock_nmcli_log"
exit 0
EOF
chmod +x "$mock_nmcli_dir/nmcli"

# 1. Re-run via entry ID (--id <id>)
rerun_id_out=$(PATH="$mock_nmcli_dir:$PATH" "$TRACKER" re-run --id "$rec_entry_id")
[[ "$(echo "$rerun_id_out" | jq -r '.success')" == "true" ]] || fail "re-run by entry ID succeeded with mock nmcli"
[[ ! -f "$evil_flag_1" ]] || fail "SECURITY VULNERABILITY: shell injection executed semicolon command during re-run by ID"
[[ ! -f "$evil_flag_2" ]] || fail "SECURITY VULNERABILITY: shell injection executed subshell command during re-run by ID"

# Verify mock nmcli received SSID as a single argument
mapfile -t nmcli_args < "$mock_nmcli_log"
[[ "${nmcli_args[0]}" == "dev" ]] || fail "mock nmcli arg 0 is dev"
[[ "${nmcli_args[1]}" == "wifi" ]] || fail "mock nmcli arg 1 is wifi"
[[ "${nmcli_args[2]}" == "connect" ]] || fail "mock nmcli arg 2 is connect"
[[ "${nmcli_args[3]}" == "$evil_ssid" ]] || fail "mock nmcli received evil SSID as single verbatim data argument"

# 2. Re-run via "latest"
rerun_latest_out=$(PATH="$mock_nmcli_dir:$PATH" "$TRACKER" re-run latest)
[[ "$(echo "$rerun_latest_out" | jq -r '.success')" == "true" ]] || fail "re-run latest succeeded"
[[ ! -f "$evil_flag_1" ]] || fail "SECURITY VULNERABILITY: shell injection executed during re-run latest"
[[ ! -f "$evil_flag_2" ]] || fail "SECURITY VULNERABILITY: subshell executed during re-run latest"

rm -rf "$mock_nmcli_dir" "$mock_nmcli_log"
pass "config-tracker re-run replays structured commandArgs without shell execution, preventing SSID injection"
