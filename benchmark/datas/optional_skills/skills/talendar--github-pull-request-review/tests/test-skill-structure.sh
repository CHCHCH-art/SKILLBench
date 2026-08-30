#!/usr/bin/env bash
set -uo pipefail

# test-skill-structure.sh — Validates the skill package structure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"

test_count=0
pass_count=0
fail_count=0

assert_true() {
  local condition="$1"
  local msg="$2"
  test_count=$((test_count + 1))
  if eval "$condition"; then
    echo "  ✓ $msg"
    pass_count=$((pass_count + 1))
  else
    echo "  ✗ $msg"
    fail_count=$((fail_count + 1))
  fi
}

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
    fail_count=$((fail_count + 1))
  fi
}

echo "Testing skill structure"
echo ""

# --- Test 1: SKILL.md exists ---
echo "Test 1: SKILL.md exists"
assert_true "[[ -f '$SKILL_DIR/SKILL.md' ]]" "SKILL.md exists at skill root"

# --- Test 2: Frontmatter has required fields ---
echo ""
echo "Test 2: Frontmatter has required fields"
# Extract frontmatter (between first two --- lines)
frontmatter=$(sed -n '/^---$/,/^---$/p' "$SKILL_DIR/SKILL.md" | sed '1d;$d')
assert_contains "$frontmatter" "name:" "Frontmatter contains name field"
assert_contains "$frontmatter" "description:" "Frontmatter contains description field"

# Extract name value
name_value=$(echo "$frontmatter" | grep '^name:' | sed 's/^name:\s*//')
assert_true "[[ -n '$name_value' ]]" "name field is non-empty"

# Extract description — it may be multiline with > syntax
desc_line=$(echo "$frontmatter" | grep -A1 '^description:' | head -2)
assert_true "[[ -n '$desc_line' ]]" "description field is non-empty"

# --- Test 3: name field matches directory name ---
echo ""
echo "Test 3: name field matches directory name"
assert_contains "$name_value" "$SKILL_NAME" "name ($name_value) matches directory name ($SKILL_NAME)"

# --- Test 4: name follows naming rules ---
echo ""
echo "Test 4: name follows naming rules"
# Lowercase, hyphens, numbers only. No leading/trailing hyphens. Max 64 chars.
assert_true "[[ \$(echo '$name_value' | wc -c) -le 65 ]]" "name is at most 64 characters"
assert_true "[[ '$name_value' =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]" "name uses only lowercase, numbers, hyphens; no leading/trailing hyphens"

# --- Test 5: description is under 1024 characters ---
echo ""
echo "Test 5: description is under 1024 characters"
# Extract full description (may be multiline with > or |)
desc_full=$(python3 -c "
import re
with open('$SKILL_DIR/SKILL.md') as f:
    content = f.read()
fm = re.search(r'^---\n(.*?)\n---', content, re.DOTALL)
if fm:
    import yaml
    data = yaml.safe_load(fm.group(1))
    desc = data.get('description', '')
    print(len(str(desc)))
" 2>/dev/null || echo "0")
if [[ "$desc_full" == "0" ]]; then
  # Fallback: estimate from grep
  desc_full=$(echo "$frontmatter" | sed -n '/^description:/,/^[a-z]/p' | wc -c)
fi
assert_true "[[ $desc_full -le 1024 ]]" "description is under 1024 characters (${desc_full} chars)"

# --- Test 6: All scripts are executable ---
echo ""
echo "Test 6: All scripts are executable"
all_executable=true
for script in "$SKILL_DIR"/scripts/*.sh; do
  if [[ -f "$script" ]]; then
    if [[ ! -x "$script" ]]; then
      echo "  ✗ $(basename "$script") is not executable"
      all_executable=false
      fail_count=$((fail_count + 1))
      test_count=$((test_count + 1))
    else
      echo "  ✓ $(basename "$script") is executable"
      pass_count=$((pass_count + 1))
      test_count=$((test_count + 1))
    fi
  fi
done

# --- Test 7: All file references in SKILL.md are valid ---
echo ""
echo "Test 7: All file references in SKILL.md are valid"
# Find relative paths in SKILL.md (references/, scripts/)
refs=$(grep -oE '(scripts|references)/[a-zA-Z0-9_./-]+' "$SKILL_DIR/SKILL.md" | sort -u)
all_refs_valid=true
while IFS= read -r ref; do
  if [[ -z "$ref" ]]; then continue; fi
  # Strip trailing parentheses or markdown syntax
  ref=$(echo "$ref" | sed 's/[)]*$//')
  test_count=$((test_count + 1))
  if [[ -f "$SKILL_DIR/$ref" ]]; then
    echo "  ✓ $ref exists"
    pass_count=$((pass_count + 1))
  else
    echo "  ✗ $ref does NOT exist"
    all_refs_valid=false
    fail_count=$((fail_count + 1))
  fi
done <<< "$refs"

# --- Test 8: SKILL.md body is under 500 lines ---
echo ""
echo "Test 8: SKILL.md body is under 500 lines"
total_lines=$(wc -l < "$SKILL_DIR/SKILL.md")
assert_true "[[ $total_lines -le 500 ]]" "SKILL.md is under 500 lines (${total_lines} lines)"

# --- Test 9: No absolute paths in scripts ---
echo ""
echo "Test 9: No hardcoded absolute paths in scripts"
bad_paths=false
for script in "$SKILL_DIR"/scripts/*.sh; do
  if [[ -f "$script" ]]; then
    # Look for /home/, /Users/, /tmp/ but allow mktemp and /usr/bin/env
    matches=$(grep -nE '(/home/|/Users/|"/tmp/|/var/)' "$script" | grep -v 'mktemp' | grep -v '/usr/bin/env' || true)
    test_count=$((test_count + 1))
    if [[ -n "$matches" ]]; then
      echo "  ✗ $(basename "$script") contains hardcoded paths:"
      echo "    $matches"
      bad_paths=true
      fail_count=$((fail_count + 1))
    else
      echo "  ✓ $(basename "$script") has no hardcoded absolute paths"
      pass_count=$((pass_count + 1))
    fi
  fi
done

# --- Summary ---
echo ""
echo "skill-structure tests: ${pass_count}/${test_count} passed"
if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
