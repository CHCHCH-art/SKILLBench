#!/usr/bin/env bash
set -uo pipefail

# test-post-review-comment.sh — Tests for post-review-comment.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_UNDER_TEST="$SKILL_DIR/scripts/post-review-comment.sh"

test_count=0
pass_count=0
fail_count=0

assert_contains() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  test_count=$((test_count + 1))
  if echo "$actual" | grep -qF -- "$expected"; then
    echo "  ✓ $msg"
    pass_count=$((pass_count + 1))
  else
    echo "  ✗ $msg"
    echo "    Expected to contain: $expected"
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

echo "Testing post-review-comment.sh"
echo ""

# Setup: create a mock gh and git that captures commands
MOCK_DIR=$(mktemp -d)
GH_LOG="$MOCK_DIR/gh_calls.log"
trap 'rm -rf "$MOCK_DIR"' EXIT

cat > "$MOCK_DIR/gh" << 'MOCKGH'
#!/usr/bin/env bash
echo "$@" >> "$(dirname "$0")/gh_calls.log"
echo "Mock gh called with: $@"
exit 0
MOCKGH
chmod +x "$MOCK_DIR/gh"

cat > "$MOCK_DIR/git" << 'MOCKGIT'
#!/usr/bin/env bash
if [[ "$1" == "remote" ]]; then
  echo "https://github.com/test-owner/test-repo.git"
  exit 0
fi
MOCKGIT
chmod +x "$MOCK_DIR/git"

# Create a test body file
BODY_FILE="$MOCK_DIR/review-body.md"
cat > "$BODY_FILE" << 'EOF'
## PR Review: #42 — Test PR
### Verdict: ✅ APPROVE
Looks good!
EOF

# --- Test 1: Constructs correct gh command for approve ---
echo "Test 1: Constructs correct gh command for approve verdict"
> "$GH_LOG"  # Clear log
result=$(echo "y" | PATH="$MOCK_DIR:$PATH" bash "$SCRIPT_UNDER_TEST" 42 approve "$BODY_FILE" "test-owner/test-repo" 2>&1)
gh_call=$(cat "$GH_LOG" 2>/dev/null || echo "")
assert_contains "$gh_call" "--approve" "Uses --approve flag"
assert_contains "$gh_call" "42" "Includes PR number"

# --- Test 2: Constructs correct gh command for request-changes ---
echo ""
echo "Test 2: Constructs correct gh command for request-changes verdict"
> "$GH_LOG"
result=$(echo "y" | PATH="$MOCK_DIR:$PATH" bash "$SCRIPT_UNDER_TEST" 42 request-changes "$BODY_FILE" "test-owner/test-repo" 2>&1)
gh_call=$(cat "$GH_LOG" 2>/dev/null || echo "")
assert_contains "$gh_call" "--request-changes" "Uses --request-changes flag"

# --- Test 3: Constructs correct gh command for comment ---
echo ""
echo "Test 3: Constructs correct gh command for comment verdict"
> "$GH_LOG"
result=$(echo "y" | PATH="$MOCK_DIR:$PATH" bash "$SCRIPT_UNDER_TEST" 42 comment "$BODY_FILE" "test-owner/test-repo" 2>&1)
gh_call=$(cat "$GH_LOG" 2>/dev/null || echo "")
assert_contains "$gh_call" "--comment" "Uses --comment flag"

# --- Test 4: Reads body from file ---
echo ""
echo "Test 4: Reads body from file"
> "$GH_LOG"
result=$(echo "y" | PATH="$MOCK_DIR:$PATH" bash "$SCRIPT_UNDER_TEST" 42 approve "$BODY_FILE" "test-owner/test-repo" 2>&1)
# The script should display the body content before confirming
assert_contains "$result" "Looks good!" "Displays body content from file"

# --- Test 5: Prints usage with missing arguments ---
echo ""
echo "Test 5: Prints usage with no arguments"
result=$(bash "$SCRIPT_UNDER_TEST" 2>&1)
ec=$?
assert_exit_code "$ec" 1 "Exits non-zero with no args"
assert_contains "$result" "Usage:" "Prints usage message"

result=$(bash "$SCRIPT_UNDER_TEST" 42 2>&1)
ec=$?
assert_exit_code "$ec" 1 "Exits non-zero with only PR arg"
assert_contains "$result" "Usage:" "Prints usage with only 1 arg"

result=$(bash "$SCRIPT_UNDER_TEST" 42 approve 2>&1)
ec=$?
assert_exit_code "$ec" 1 "Exits non-zero with missing body file arg"
assert_contains "$result" "Usage:" "Prints usage with only 2 args"

# --- Test 6: Exits non-zero if body file doesn't exist ---
echo ""
echo "Test 6: Exits non-zero if body file doesn't exist"
result=$(PATH="$MOCK_DIR:$PATH" bash "$SCRIPT_UNDER_TEST" 42 approve "/nonexistent/file.md" "test-owner/test-repo" 2>&1)
ec=$?
assert_exit_code "$ec" 1 "Exits non-zero for missing body file"
assert_contains "$result" "does not exist" "Reports missing body file"

# --- Test 7: Rejects invalid verdict ---
echo ""
echo "Test 7: Rejects invalid verdict"
result=$(PATH="$MOCK_DIR:$PATH" bash "$SCRIPT_UNDER_TEST" 42 invalid-verdict "$BODY_FILE" "test-owner/test-repo" 2>&1)
ec=$?
assert_exit_code "$ec" 1 "Exits non-zero for invalid verdict"
assert_contains "$result" "Invalid verdict" "Reports invalid verdict"

# --- Summary ---
echo ""
echo "post-review-comment tests: ${pass_count}/${test_count} passed"
if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
