#!/usr/bin/env bash
set -uo pipefail

# test-fetch-pr-context.sh — Tests for fetch-pr-context.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
SCRIPT_UNDER_TEST="$SKILL_DIR/scripts/fetch-pr-context.sh"

test_count=0
pass_count=0
fail_count=0

assert_contains() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  test_count=$((test_count + 1))
  if echo "$actual" | grep -qF "$expected"; then
    echo "  ✓ $msg"
    pass_count=$((pass_count + 1))
  else
    echo "  ✗ $msg"
    echo "    Expected to contain: $expected"
    echo "    Actual: $actual"
    fail_count=$((fail_count + 1))
  fi
}

assert_not_contains() {
  local actual="$1"
  local unexpected="$2"
  local msg="$3"
  test_count=$((test_count + 1))
  if ! echo "$actual" | grep -qF "$unexpected"; then
    echo "  ✓ $msg"
    pass_count=$((pass_count + 1))
  else
    echo "  ✗ $msg"
    echo "    Expected NOT to contain: $unexpected"
    echo "    Actual: $actual"
    fail_count=$((fail_count + 1))
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  test_count=$((test_count + 1))
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  ✓ $msg"
    pass_count=$((pass_count + 1))
  else
    echo "  ✗ $msg"
    echo "    Expected exit code: $expected, got: $actual"
    fail_count=$((fail_count + 1))
  fi
}

# We test the extract_issues function by sourcing just that function.
# The script uses set -euo pipefail and runs main logic at top level,
# so we extract the function and test it independently.

# Extract the extract_issues function from the script
extract_issues_func=$(sed -n '/^extract_issues()/,/^}/p' "$SCRIPT_UNDER_TEST")

# Create a temporary script that only defines extract_issues
TEMP_SCRIPT=$(mktemp)
trap 'rm -f "$TEMP_SCRIPT"' EXIT

cat > "$TEMP_SCRIPT" << 'EOFWRAPPER'
#!/usr/bin/env bash
set -uo pipefail
EOFWRAPPER
echo "$extract_issues_func" >> "$TEMP_SCRIPT"
echo 'extract_issues "$1"' >> "$TEMP_SCRIPT"
chmod +x "$TEMP_SCRIPT"

echo "Testing fetch-pr-context.sh"
echo ""

# --- Test 1: Extracts linked issue numbers from PR body with various formats ---
echo "Test 1: Extracts linked issues from body with multiple formats"
body=$(cat "$FIXTURES_DIR/pr-body-with-issues.txt")
result=$(bash "$TEMP_SCRIPT" "$body")
assert_contains "$result" "42" "Contains issue 42 (Fixes #42)"
assert_contains "$result" "99" "Contains issue 99 (Closes #99)"
assert_contains "$result" "101" "Contains issue 101 (Resolves #101)"
assert_contains "$result" "55" "Contains issue 55 (Related to #55)"
assert_contains "$result" "200" "Contains issue 200 (bare #200)"

# --- Test 2: Handles PR body with no issue references ---
echo ""
echo "Test 2: Handles PR body with no issue references"
body=$(cat "$FIXTURES_DIR/pr-body-no-issues.txt")
result=$(bash "$TEMP_SCRIPT" "$body")
assert_contains "$result" "No linked issues found" "Reports no linked issues"

# --- Test 3: Multiple issue reference formats ---
echo ""
echo "Test 3: Parses all keyword formats"
result=$(bash "$TEMP_SCRIPT" "Fixes #1, Closes #2, Resolves #3, Related to #4, see #5")
assert_contains "$result" "1" "Parses Fixes #1"
assert_contains "$result" "2" "Parses Closes #2"
assert_contains "$result" "3" "Parses Resolves #3"
assert_contains "$result" "4" "Parses Related to #4"
assert_contains "$result" "5" "Parses bare #5"

# --- Test 4: Prints usage and exits non-zero with no arguments ---
echo ""
echo "Test 4: Prints usage with no arguments"
output=$(bash "$SCRIPT_UNDER_TEST" 2>&1)
exit_code=$?
assert_exit_code "$exit_code" 1 "Exits with code 1 when no args are provided"
assert_contains "$output" "Usage:" "Prints usage message"

# --- Test 5: Auto-detects owner/repo from git remote ---
echo ""
echo "Test 5: Auto-detects owner/repo"
# Extract detect_repo function and test it
detect_repo_func=$(sed -n '/^detect_repo()/,/^}/p' "$SCRIPT_UNDER_TEST")
TEMP_DETECT=$(mktemp)
trap 'rm -f "$TEMP_SCRIPT" "$TEMP_DETECT"' EXIT

cat > "$TEMP_DETECT" << 'EOFWRAPPER2'
#!/usr/bin/env bash
set -uo pipefail
# Mock git to return a known URL
git() {
  if [[ "$1" == "remote" ]]; then
    echo "https://github.com/octocat/my-repo.git"
    return 0
  fi
}
EOFWRAPPER2
echo "$detect_repo_func" >> "$TEMP_DETECT"
echo 'detect_repo' >> "$TEMP_DETECT"
chmod +x "$TEMP_DETECT"

result=$(bash "$TEMP_DETECT")
assert_contains "$result" "octocat/my-repo" "Parses HTTPS remote URL"

# Test SSH URL
cat > "$TEMP_DETECT" << 'EOFWRAPPER3'
#!/usr/bin/env bash
set -uo pipefail
git() {
  if [[ "$1" == "remote" ]]; then
    echo "git@github.com:octocat/ssh-repo.git"
    return 0
  fi
}
EOFWRAPPER3
echo "$detect_repo_func" >> "$TEMP_DETECT"
echo 'detect_repo' >> "$TEMP_DETECT"

result=$(bash "$TEMP_DETECT")
assert_contains "$result" "octocat/ssh-repo" "Parses SSH remote URL"

# --- Test 6: Rejects non-numeric PR number ---
echo ""
echo "Test 6: Rejects non-numeric PR number"
output=$(bash "$SCRIPT_UNDER_TEST" abc 2>&1)
exit_code=$?
assert_exit_code "$exit_code" 1 "Exits with code 1 for non-numeric PR"
assert_contains "$output" "must be numeric" "Prints numeric PR validation error"

# --- Summary ---
echo ""
echo "fetch-pr-context tests: ${pass_count}/${test_count} passed"
if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
