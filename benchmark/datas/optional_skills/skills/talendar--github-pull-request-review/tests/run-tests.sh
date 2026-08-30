#!/usr/bin/env bash
set -uo pipefail

# run-tests.sh — Runs all test-*.sh files and reports results.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
passed=0
failed=0
results=()

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  test_name="$(basename "$test_file")"
  if bash "$test_file"; then
    results+=("[PASS] $test_name")
    ((passed++))
  else
    results+=("[FAIL] $test_name")
    ((failed++))
  fi
  echo ""
done

echo "================================"
echo "Test Summary"
echo "================================"
for result in "${results[@]}"; do
  echo "$result"
done
echo ""
total=$((passed + failed))
echo "Results: ${passed}/${total} passed"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
exit 0
