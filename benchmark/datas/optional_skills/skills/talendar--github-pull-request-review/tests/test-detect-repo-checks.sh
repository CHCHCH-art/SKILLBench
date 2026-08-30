#!/usr/bin/env bash
set -uo pipefail

# test-detect-repo-checks.sh — Tests for detect-repo-checks.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
SCRIPT_UNDER_TEST="$SKILL_DIR/scripts/detect-repo-checks.sh"

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
    echo "    Actual output: $actual"
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
    echo "    Actual output: $actual"
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

echo "Testing detect-repo-checks.sh"
echo ""

# --- Test 1: Detects npm scripts ---
echo "Test 1: Detects npm scripts from package.json"
TMPDIR_NPM=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM"' EXIT
cp "$FIXTURES_DIR/package-json-with-scripts.json" "$TMPDIR_NPM/package.json"

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_NPM")
assert_contains "$result" "lint" "Detects lint script"
assert_contains "$result" "test" "Detects test script"
assert_contains "$result" "typecheck" "Detects typecheck script"
assert_not_contains "$result" "deploy" "Does not include deploy"
assert_not_contains "$result" "migrate" "Does not include migrate"

# --- Test 2: Detects Makefile targets ---
echo ""
echo "Test 2: Detects Makefile targets"
TMPDIR_MAKE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE"' EXIT
cp "$FIXTURES_DIR/makefile-sample" "$TMPDIR_MAKE/Makefile"

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_MAKE")
assert_contains "$result" "make lint" "Detects make lint"
assert_contains "$result" "make test" "Detects make test"
assert_not_contains "$result" "make deploy" "Does not include make deploy"

# --- Test 3: Detects pyproject.toml tools ---
echo ""
echo "Test 3: Detects pyproject.toml tools"
TMPDIR_PY=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY"' EXIT
cp "$FIXTURES_DIR/pyproject-sample.toml" "$TMPDIR_PY/pyproject.toml"

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_PY")
assert_contains "$result" "ruff" "Detects ruff (lint)"
assert_contains "$result" "mypy" "Detects mypy (typecheck)"
assert_contains "$result" "pytest" "Detects pytest (test)"

# --- Test 4: Handles empty directory gracefully ---
echo ""
echo "Test 4: Handles empty directory (no config files)"
TMPDIR_EMPTY=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY" "$TMPDIR_EMPTY"' EXIT

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_EMPTY")
ec=$?
assert_exit_code "$ec" 0 "Exits with code 0"
assert_contains "$result" "No lint, test, or typecheck commands detected" "Reports no checks found"

# --- Test 5: Does not detect dangerous commands ---
echo ""
echo "Test 5: Does not include dangerous scripts from package.json"
# Already tested in Test 1, but let's be explicit with a focused check
TMPDIR_DANGER=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY" "$TMPDIR_EMPTY" "$TMPDIR_DANGER"' EXIT
cp "$FIXTURES_DIR/package-json-with-scripts.json" "$TMPDIR_DANGER/package.json"

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_DANGER")
assert_not_contains "$result" "deploy" "deploy is excluded"
assert_not_contains "$result" "migrate" "migrate is excluded"

# --- Test 6: Handles minimal package.json (no scripts) ---
echo ""
echo "Test 6: Handles minimal package.json with no scripts"
TMPDIR_MIN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY" "$TMPDIR_EMPTY" "$TMPDIR_DANGER" "$TMPDIR_MIN"' EXIT
cp "$FIXTURES_DIR/package-json-minimal.json" "$TMPDIR_MIN/package.json"

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_MIN")
assert_contains "$result" "No lint, test, or typecheck commands detected" "Reports no checks for minimal package.json"

# --- Test 7: Skips scripts with dangerous command bodies ---
echo ""
echo "Test 7: Skips scripts with dangerous command bodies"
TMPDIR_UNSAFE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY" "$TMPDIR_EMPTY" "$TMPDIR_DANGER" "$TMPDIR_MIN" "$TMPDIR_UNSAFE"' EXIT
cat > "$TMPDIR_UNSAFE/package.json" << 'EOFJSON'
{
  "scripts": {
    "lint": "eslint . && npm run deploy",
    "test": "vitest"
  }
}
EOFJSON

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_UNSAFE")
assert_not_contains "$result" "npm run lint" "Unsafe lint script is excluded"
assert_contains "$result" "npm run test" "Safe test script is still included"

# --- Test 8: Detects make targets with dots and hyphens ---
echo ""
echo "Test 8: Detects dotted/hyphenated Makefile target names"
TMPDIR_MAKE_EXT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY" "$TMPDIR_EMPTY" "$TMPDIR_DANGER" "$TMPDIR_MIN" "$TMPDIR_UNSAFE" "$TMPDIR_MAKE_EXT"' EXIT
cat > "$TMPDIR_MAKE_EXT/Makefile" << 'EOFMK'
lint-v2:
	echo lint
test.1:
	echo test
EOFMK

result=$(bash "$SCRIPT_UNDER_TEST" "$TMPDIR_MAKE_EXT")
assert_contains "$result" "make lint-v2" "Detects lint-v2 make target"
assert_contains "$result" "make test.1" "Detects test.1 make target"

# --- Test 9: Warns when package parsers are unavailable/failing ---
echo ""
echo "Test 9: Warns when package.json parsers are unavailable"
TMPDIR_NO_PARSER=$(mktemp -d)
trap 'rm -rf "$TMPDIR_NPM" "$TMPDIR_MAKE" "$TMPDIR_PY" "$TMPDIR_EMPTY" "$TMPDIR_DANGER" "$TMPDIR_MIN" "$TMPDIR_UNSAFE" "$TMPDIR_MAKE_EXT" "$TMPDIR_NO_PARSER"' EXIT
mkdir -p "$TMPDIR_NO_PARSER/mockbin"
cat > "$TMPDIR_NO_PARSER/mockbin/python3" << 'EOFPY'
#!/usr/bin/env bash
exit 127
EOFPY
cat > "$TMPDIR_NO_PARSER/mockbin/node" << 'EOFNODE'
#!/usr/bin/env bash
exit 127
EOFNODE
chmod +x "$TMPDIR_NO_PARSER/mockbin/python3" "$TMPDIR_NO_PARSER/mockbin/node"
cat > "$TMPDIR_NO_PARSER/package.json" << 'EOFJSON2'
{"scripts":{"lint":"eslint ."}}
EOFJSON2

result=$(PATH="$TMPDIR_NO_PARSER/mockbin:/usr/bin:/bin" bash "$SCRIPT_UNDER_TEST" "$TMPDIR_NO_PARSER" 2>&1)
assert_contains "$result" "Failed to parse package.json with python3" "Warns about python3 parser failure"
assert_contains "$result" "Failed to parse package.json with node" "Warns about node parser failure"
assert_contains "$result" "Skipping package.json checks because no working parser was available" "Warns about skipped package.json detection"

# --- Summary ---
echo ""
echo "detect-repo-checks tests: ${pass_count}/${test_count} passed"
if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
