#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq
require_command python3

TRACKER="$SCRIPTS_DIR/config-tracker.sh"
[[ -x "$TRACKER" ]] || fail "config-tracker.sh is executable"

TEST_TMP_DIR=$(mktemp -d /tmp/ocp-test-tracker-XXXXXX)
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

TEST_FILE="$TEST_TMP_DIR/test-config.lua"

# 1. Test get-all-configs registry
all_configs=$("$TRACKER" get-all-configs)
count=$(echo "$all_configs" | jq 'length')
(( count >= 8 )) || fail "get-all-configs returned at least 8 items (got $count)"
pass "get-all-configs returns complete config registry ($count targets)"

# 2. Test get-category-file
cat_file=$("$TRACKER" get-category-file windows | jq -r '.file // ""')
[[ -n "$cat_file" ]] || fail "get-category-file windows returns valid path"
pass "get-category-file resolves targets correctly"

# 3. Test Snapshot & Diff recording
printf "line_one = 1\nline_two = 2\nline_three = 3\n" > "$TEST_FILE"
snap_path=$("$TRACKER" snapshot "$TEST_FILE")
[[ -f "$snap_path" ]] || fail "snapshot creates snapshot file ($snap_path)"
pass "config-tracker snapshot created successfully"

# Modify test file: replace line_two with modified lines
printf "line_one = 1\nline_two_modified = 20\nline_two_extra = 21\nline_three = 3\n" > "$TEST_FILE"

record_json=$("$TRACKER" record "windows" "Test Window Gaps" "$TEST_FILE" "$snap_path")
has_diff=$(echo "$record_json" | jq -r '.hasDiff')
[[ "$has_diff" == "true" ]] || fail "diff recording detected changes"

change_type=$(echo "$record_json" | jq -r '.changeType')
[[ "$change_type" == "file" ]] || fail "changeType is 'file'"

is_reversible=$(echo "$record_json" | jq -r '.isReversible')
[[ "$is_reversible" == "true" ]] || fail "isReversible is true"

lines_added=$(echo "$record_json" | jq -r '.linesAdded')
lines_removed=$(echo "$record_json" | jq -r '.linesRemoved')
[[ "$lines_added" == "2" ]] || fail "linesAdded equals 2 (got $lines_added)"
[[ "$lines_removed" == "1" ]] || fail "linesRemoved equals 1 (got $lines_removed)"

entry_id=$(echo "$record_json" | jq -r '.id')
pass "config-tracker record generated accurate diff, line counts, and reversible snapshot"

# 4. Verify Gutter Line Numbering in parsed lines
has_gutter_lines=$(echo "$record_json" | jq -r '
  [.lines[] | select(.type == "add" or .type == "del")]
  | all(has("oldLine") and has("newLine"))
')
[[ "$has_gutter_lines" == "true" ]] || fail "parsed diff lines include oldLine and newLine numbers"
pass "diff parser provides two-column gutter line numbers (oldLine & newLine)"

# 5. Verify Latest and History persistence
latest_id=$("$TRACKER" get-latest | jq -r '.id')
[[ "$latest_id" == "$entry_id" ]] || fail "get-latest returns recorded entry id"

history_has_entry=$("$TRACKER" get-history | jq -r --arg id "$entry_id" 'any(.[]; .id == ($id | tonumber))')
[[ "$history_has_entry" == "true" ]] || fail "get-history contains recorded entry"
pass "latest state and audit history persist recorded entry"

# 6. Test Revert / Rollback
revert_res=$("$TRACKER" revert "$entry_id")
revert_success=$(echo "$revert_res" | jq -r '.success')
[[ "$revert_success" == "true" ]] || fail "revert command returned success" "$revert_res"

# Verify actual file contents restored
current_content=$(cat "$TEST_FILE")
expected_content=$(printf "line_one = 1\nline_two = 2\nline_three = 3\n")
[[ "$current_content" == "$expected_content" ]] || fail "target file content restored to pre-modification state" "Got: $current_content"
pass "config-tracker revert successfully restored original file content"

# 7. Test record-command
cmd_record=$("$TRACKER" record-command "power" "Toggle DND" "Shell IPC" "omarchy-shell toggle dnd" "User initiated")
cmd_type=$(echo "$cmd_record" | jq -r '.changeType')
cmd_reversible=$(echo "$cmd_record" | jq -r '.isReversible')
cmd_args_len=$(echo "$cmd_record" | jq '.commandArgs | length')
[[ "$cmd_type" == "command" ]] || fail "command changeType is 'command'"
[[ "$cmd_reversible" == "false" ]] || fail "command changeType is not reversible"
[[ "$cmd_args_len" == "3" ]] || fail "commandArgs parsed correctly from string"
pass "config-tracker record-command creates non-reversible command action entry"

# 8. Test record-command-args
cmd_record_args=$("$TRACKER" record-command-args "network" "Connect Wi-Fi" "NetworkManager" "User connected" echo "Network with spaces and 'quotes'")
args_len=$(echo "$cmd_record_args" | jq '.commandArgs | length')
arg_val=$(echo "$cmd_record_args" | jq -r '.commandArgs[1]')
entry_id=$(echo "$cmd_record_args" | jq -r '.id')
[[ "$args_len" == "2" ]] || fail "record-command-args length is 2"
[[ "$arg_val" == "Network with spaces and 'quotes'" ]] || fail "record-command-args preserved literal argument data"
pass "config-tracker record-command-args stores structured argument array"

# 9. Test re-run (both direct string and structured by ID)
rerun_res=$("$TRACKER" re-run "echo test_execution_123")
rerun_ok=$(echo "$rerun_res" | jq -r '.success')
rerun_stdout=$(echo "$rerun_res" | jq -r '.stdout')
[[ "$rerun_ok" == "true" ]] || fail "re-run execution succeeded"
[[ "$rerun_stdout" == *"test_execution_123"* ]] || fail "re-run stdout captured output"

rerun_id_res=$("$TRACKER" re-run --id "$entry_id")
rerun_id_ok=$(echo "$rerun_id_res" | jq -r '.success')
rerun_id_stdout=$(echo "$rerun_id_res" | jq -r '.stdout')
[[ "$rerun_id_ok" == "true" ]] || fail "re-run by ID succeeded"
[[ "$rerun_id_stdout" == *"Network with spaces and 'quotes'"* ]] || fail "re-run by ID preserved literal argument data"
pass "config-tracker re-run successfully executes and returns command output"

# 9. Test clear-history
clear_res=$("$TRACKER" clear-history)
[[ "$(echo "$clear_res" | jq -r '.success')" == "true" ]] || fail "clear-history returned success"
history_after_clear=$("$TRACKER" get-history | jq 'length')
[[ "$history_after_clear" == "0" ]] || fail "history is empty after clear-history"
pass "config-tracker clear-history resets session audit trail"
