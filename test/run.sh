#!/usr/bin/env bash
# Automated test runner for omarchy-control-panel

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT/test"

shopt -s nullglob
tests=()
for test_file in "$TEST_DIR"/*-test.sh; do
  [[ "$(basename "$test_file")" == "base-test.sh" ]] && continue
  tests+=("$test_file")
done
shopt -u nullglob

if (( ${#tests[@]} == 0 )); then
  echo "No test files found in $TEST_DIR" >&2
  exit 1
fi

echo "============================================================"
echo " Running Omarchy Control Panel Automated Test Suite"
echo "============================================================"
echo "Found ${#tests[@]} test suites."
echo ""

output=$(mktemp)
trap 'rm -f "$output"' EXIT

failed=()
skipped=()
total_assertions=0

for test_file in "${tests[@]}"; do
  test_name="$(basename "$test_file")"
  printf "==> Running %s ...\n" "$test_name"
  
  if bash "$test_file" | tee "$output"; then
    test_ok=true
  else
    test_ok=false
    failed+=("$test_name")
  fi

  if grep -q '^ok - .* # SKIP$' "$output"; then
    skipped+=("$test_name")
  fi
  
  assertions_in_suite=$(grep -c '^ok - \|^not ok - ' "$output" || true)
  total_assertions=$((total_assertions + assertions_in_suite))
  echo ""
done

echo "============================================================"
echo " Test Summary"
echo "============================================================"
echo "Total Test Suites: ${#tests[@]}"
echo "Total Assertions:  $total_assertions"

if (( ${#skipped[@]} > 0 )); then
  echo ""
  echo "Suites with skipped checks (${#skipped[@]}):"
  for s in "${skipped[@]}"; do
    echo "  - $s"
  done
fi

if (( ${#failed[@]} > 0 )); then
  echo ""
  echo "FAILED Suites (${#failed[@]}):"
  for f in "${failed[@]}"; do
    echo "  - $f"
  done
  echo "============================================================"
  exit 1
fi

echo ""
echo "STATUS: ALL TESTS PASSED SUCCESSFULLY! ✓"
echo "============================================================"
exit 0
