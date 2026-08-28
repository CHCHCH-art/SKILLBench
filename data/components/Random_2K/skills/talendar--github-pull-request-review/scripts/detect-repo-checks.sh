#!/usr/bin/env bash
set -euo pipefail

# detect-repo-checks.sh — Scans a repo for available lint/test/typecheck commands.
# Usage: detect-repo-checks.sh [REPO_DIR]
# If REPO_DIR is omitted, uses the current directory.

usage() {
  echo "Usage: $0 [REPO_DIR]"
  echo ""
  echo "Scans a repository for available lint, test, and typecheck commands."
  echo "If REPO_DIR is omitted, uses the current directory."
  exit 1
}

# Commands that should never be suggested (state-modifying)
DANGEROUS_SCRIPTS="deploy|migrate|publish|release|push|seed|drop|destroy|eject"
DANGEROUS_COMMAND_REGEX="(^|[^a-zA-Z0-9_-])(${DANGEROUS_SCRIPTS})([^a-zA-Z0-9_-]|$)"

REPO_DIR="${1:-.}"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "Error: Directory '$REPO_DIR' does not exist." >&2
  exit 1
fi

found_any=false

is_dangerous_command() {
  local command_text="$1"
  if [[ -z "$command_text" ]]; then
    return 1
  fi
  echo "$command_text" | grep -qiE "$DANGEROUS_COMMAND_REGEX"
}

classify_check_type() {
  local name="$1"
  local cmd="$2"

  case "$name" in
    lint|lint:*|lint-*|lint.*|eslint|biome:check|ruff|format|format:*|prettier|fmt|fmt:*|check|check:*)
      echo "lint"
      return
      ;;
    test|test:*|test-*|test.*|tests|vitest|jest|mocha|pytest)
      echo "test"
      return
      ;;
    typecheck|type-check|typecheck:*|type-check:*|types|tsc|mypy|pyright)
      echo "typecheck"
      return
      ;;
  esac

  if echo "$cmd" | grep -qiE 'eslint|biome check|ruff check|pylint|rubocop|golangci-lint|prettier|stylelint'; then
    echo "lint"
  elif echo "$cmd" | grep -qiE 'vitest|jest|mocha|pytest|go test|rspec|cargo test'; then
    echo "test"
  elif echo "$cmd" | grep -qiE 'tsc|mypy|pyright|typecheck|type-check'; then
    echo "typecheck"
  fi
  return 0
}

parse_package_scripts() {
  local package_file="$1"

  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$package_file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(1)

scripts = data.get("scripts", {})
for name, command in scripts.items():
    print(f"{name}\t{command}")
PY
    then
      return 0
    fi
    echo "Warning: Failed to parse package.json with python3; trying node fallback." >&2
  fi

  if command -v node >/dev/null 2>&1; then
    if node -e '
const fs = require("fs");
const path = process.argv[1];
try {
  const data = JSON.parse(fs.readFileSync(path, "utf8"));
  const scripts = data.scripts || {};
  for (const [name, command] of Object.entries(scripts)) {
    console.log(`${name}\t${command}`);
  }
} catch (err) {
  process.exit(1);
}
' "$package_file"
    then
      return 0
    fi
    echo "Warning: Failed to parse package.json with node." >&2
  fi

  echo "Warning: Skipping package.json checks because no working parser was available." >&2
  return 1
}

extract_make_recipe() {
  local makefile_path="$1"
  local target_name="$2"
  awk -v target="$target_name" '
  BEGIN { in_target = 0 }
  /^[^[:space:]#][^:]*:/ {
    split($0, parts, ":")
    current = parts[1]
    gsub(/[[:space:]]+$/, "", current)
    in_target = (current == target)
    next
  }
  in_target && /^\t/ {
    sub(/^\t/, "", $0)
    print
    next
  }
  in_target && !/^\t/ {
    in_target = 0
  }' "$makefile_path"
}

# --- package.json (npm/yarn/pnpm/bun) ---
if [[ -f "$REPO_DIR/package.json" ]]; then
  scripts=$(parse_package_scripts "$REPO_DIR/package.json" || true)

  if [[ -n "$scripts" ]]; then
    while IFS=$'\t' read -r name cmd; do
      # Skip dangerous commands
      if echo "$name" | grep -qiE "^($DANGEROUS_SCRIPTS)$"; then
        continue
      fi

      # Skip scripts whose command body looks state-modifying.
      if is_dangerous_command "$cmd"; then
        echo "Warning: Skipping potentially unsafe npm script '$name'." >&2
        continue
      fi

      script_type="$(classify_check_type "$name" "$cmd")"

      if [[ -n "$script_type" ]]; then
        echo "[npm:$script_type] npm run $name  # $cmd"
        found_any=true
      fi
    done <<< "$scripts"
  fi
fi

# --- Makefile ---
if [[ -f "$REPO_DIR/Makefile" ]]; then
  targets=$(grep -E '^[a-zA-Z0-9_.-]+:' "$REPO_DIR/Makefile" | sed 's/:.*//' || true)
  if [[ -n "$targets" ]]; then
    while IFS= read -r target; do
      # Skip dangerous targets
      if echo "$target" | grep -qiE "^($DANGEROUS_SCRIPTS)$"; then
        continue
      fi

      target_recipe="$(extract_make_recipe "$REPO_DIR/Makefile" "$target" || true)"
      if is_dangerous_command "$target_recipe"; then
        echo "Warning: Skipping potentially unsafe Make target '$target'." >&2
        continue
      fi

      target_type="$(classify_check_type "$target" "$target_recipe")"

      if [[ -n "$target_type" ]]; then
        echo "[make:$target_type] make $target"
        found_any=true
      fi
    done <<< "$targets"
  fi
fi

# --- pyproject.toml ---
if [[ -f "$REPO_DIR/pyproject.toml" ]]; then
  # Detect tool sections
  tools=$(grep -E '^\[tool\.' "$REPO_DIR/pyproject.toml" | sed -E 's/^\[tool\.([a-zA-Z0-9_-]+).*/\1/' | sort -u || true)
  if [[ -n "$tools" ]]; then
    while IFS= read -r tool; do
      case "$tool" in
        ruff)
          echo "[pyproject:lint] ruff check ."
          found_any=true ;;
        pylint)
          echo "[pyproject:lint] pylint ."
          found_any=true ;;
        mypy)
          echo "[pyproject:typecheck] mypy ."
          found_any=true ;;
        pyright)
          echo "[pyproject:typecheck] pyright ."
          found_any=true ;;
        pytest)
          echo "[pyproject:test] pytest"
          found_any=true ;;
      esac
    done <<< "$tools"
  fi
fi

if [[ "$found_any" = false ]]; then
  echo "No lint, test, or typecheck commands detected."
fi
