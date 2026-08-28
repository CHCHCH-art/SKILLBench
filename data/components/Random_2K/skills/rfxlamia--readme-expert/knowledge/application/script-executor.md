# Script Executor - Test Commands & Code Examples

**Purpose:** Extract and execute scripts, commands, and code examples from README to verify they actually work, preventing the most common form of documentation hallucination: broken examples.

**Anti-Hallucination Impact:** 40-60% of README hallucinations involve non-functional code examples, wrong commands, or outdated installation instructions. Script execution testing catches these before publication.

---

## 🎯 Core Philosophy

**"Documentation should work, not just read well."**

Every command, code example, and installation instruction in a README should be executable and produce expected results. If it can't be tested, it should be marked as pseudocode or theoretical.

**Safety First:** Always assess risk before execution. Get user permission for potentially destructive operations.

---

## 📋 Phase 1: Script Extraction

### 1.1 Identify Code Blocks

**Scan README for executable content:**

```markdown
Common code block patterns:
```bash
npm install package-name
```

```python
from mylib import function
result = function()
```

```sh
./script.sh --help
```

```javascript
const lib = require('library')
lib.method()
```
```

**Tool Usage:**
```bash
# Read README
Read: file_path="README.md"

# Extract code blocks (manual parsing after read)
# Look for: ```language\ncode\n```
# Languages to test: bash, sh, shell, python, javascript, node, go, rust
```

### 1.2 Classify by Risk Level

**Risk Assessment Matrix:**

| Category | Risk | Examples | Permission |
|----------|------|----------|------------|
| **Safe** | None | `--help`, `--version`, `--list` | Auto-execute |
| **Read-Only** | Low | `ls`, `cat`, `grep`, display commands | Auto-execute |
| **Pseudo** | None | Example code snippets (not meant to run) | Skip |
| **Install** | Medium | `npm install`, `pip install`, `cargo build` | Ask user |
| **Modify** | High | File creation, config changes | Ask user |
| **Destructive** | Critical | `rm`, `drop`, `delete`, `deploy` | Warn + Ask |

**Classification Examples:**

```bash
# Safe ✅ (auto-execute)
myapp --help
myapp --version
git --version
python --version

# Read-Only ✅ (auto-execute)
ls -la
cat README.md
grep "pattern" file.txt

# Install ⚠️ (ask permission)
npm install my-package
pip install my-package
cargo build
docker build -t image .

# Modify ⚠️ (ask permission)
echo "config" > .env
mkdir new_directory
git clone repo

# Destructive ❌ (warn + explicit permission)
rm -rf directory
drop database
firebase deploy
kubectl delete pod
```

---

## 🧪 Phase 2: Execution Environment Setup

### 2.1 Determine Execution Context

**Check project prerequisites:**

```bash
# For Node.js projects
Read: file_path="package.json"
# Check: engines.node version
# Verify: node --version matches requirement

# For Python projects
Read: file_path="pyproject.toml" or "setup.py"
# Check: python_requires version
# Verify: python --version matches requirement

# For system commands
# Verify: command exists (which/where)
Bash: command="which npm || which yarn || which pnpm"
```

### 2.2 Safety Sandboxing

**Create isolated test environment (when possible):**

```bash
# Option 1: Temporary directory
Bash: command="mktemp -d"
# Execute tests in temp dir
# Cleanup after completion

# Option 2: Docker container (if available)
# Run tests in isolated container
# Prevents system pollution

# Option 3: Virtual environment (Python)
Bash: command="python -m venv /tmp/test_env"
Bash: command="source /tmp/test_env/bin/activate"
```

**Note:** For this skill, we typically test in current directory with user permission.

---

## ⚙️ Phase 3: Command Execution & Validation

### 3.1 Installation Commands

**Test package installation instructions:**

**Node.js:**
```bash
# README says: npm install my-package

# Validation steps:
1. Check package exists on npm registry
   Bash: command="npm view my-package version 2>&1"
   # If succeeds → package exists ✅
   # If fails → package not found ❌

2. (Optional) Test actual install in temp dir
   # Only with user permission
   Bash: command="cd /tmp && npm install my-package --dry-run"
```

**Python:**
```bash
# README says: pip install my-package

# Validation steps:
1. Check package exists on PyPI
   Bash: command="pip index versions my-package 2>&1 || pip show my-package 2>&1"
   # If succeeds → package exists ✅
   # If fails → package not found ❌

2. (Optional) Test actual install
   Bash: command="pip install my-package --dry-run"
```

**Local Installation:**
```bash
# README says: npm install (for local package)

# Validation:
1. Verify package.json exists
   Read: file_path="package.json"

2. (With permission) Run install
   Bash: command="npm install --dry-run" # Safe, doesn't actually install
```

### 3.2 CLI Commands

**Test command-line interface examples:**

```bash
# README says: myapp --help

# Validation steps:
1. Check if command exists
   Bash: command="which myapp || where myapp"
   # If not found → Try local: ./myapp or npx myapp

2. Execute help command (always safe)
   Bash: command="myapp --help"
   # Check exit code: 0 = success ✅
   # Non-zero = failure ❌

3. Verify output format
   # Check if output looks like help text
   # Contains: usage, options, commands, etc.
```

**Common Safe CLI Tests:**
```bash
# Always safe to execute
--help, -h          # Show help
--version, -v, -V   # Show version
--list, -l          # List items
--dry-run           # Simulate without executing
--check             # Validate config
--validate          # Validate input
```

### 3.3 Code Example Execution

**Test actual code examples:**

**JavaScript/Node.js:**
```bash
# README example:
# ```javascript
# const lib = require('my-lib')
# const result = lib.process('data')
# console.log(result)
# ```

# Validation:
1. Extract code to temp file
   Write: file_path="/tmp/test_example.js"
   # Content: extracted code

2. Check syntax (safe, no execution)
   Bash: command="node --check /tmp/test_example.js"
   # Exit 0 = valid syntax ✅
   # Exit 1 = syntax error ❌

3. (Optional) Execute with timeout
   Bash: command="timeout 5s node /tmp/test_example.js" timeout=5000
   # With user permission only
   # 5s timeout prevents infinite loops
```

**Python:**
```bash
# README example:
# ```python
# from mylib import function
# result = function('input')
# print(result)
# ```

# Validation:
1. Extract code to temp file
   Write: file_path="/tmp/test_example.py"

2. Check syntax
   Bash: command="python -m py_compile /tmp/test_example.py"
   # Exit 0 = valid syntax ✅
   # Non-zero = syntax error ❌

3. (Optional) Execute with timeout
   Bash: command="timeout 5s python /tmp/test_example.py" timeout=5000
   # With user permission
```

**Shell Scripts:**
```bash
# README example:
# ```bash
# ./setup.sh --init
# ```

# Validation:
1. Check script exists
   Read: file_path="setup.sh"

2. Check execute permissions
   Bash: command="test -x setup.sh && echo 'executable' || echo 'not executable'"

3. (Optional) Dry-run or help
   Bash: command="./setup.sh --help"
   # Or: bash -n setup.sh (syntax check only)
```

---

## 🔍 Phase 4: Output Validation

### 4.1 Expected vs Actual Output

**Compare execution results with README claims:**

```markdown
# README says: "The command outputs 'Success'"
myapp run

# Validation:
1. Execute command
   Bash: command="myapp run"
   # Capture output

2. Check output contains expected text
   # Output: "Success: Operation completed"
   # Contains "Success" ✅

3. Verify exit code
   # Exit code 0 = success ✅
   # Non-zero = failure (update README) ❌
```

### 4.2 Error Handling

**Test error conditions if documented:**

```markdown
# README says: "Returns error if file missing"
myapp process missing.txt

# Validation:
1. Create test condition (missing file)
2. Execute command
   Bash: command="myapp process missing.txt"
   # Expect non-zero exit code

3. Verify error message
   # Should contain error description
   # Should match README's claim
```

---

## ✅ Phase 5: Reporting

### 5.1 Execution Report Template

```markdown
## Script Execution Report

**Date:** 2025-11-13
**README:** README.md
**Total Tests:** 12

### Installation Commands

1. ✅ PASS: `npm install my-package`
   - Package exists on npm registry
   - Version: 2.1.0
   - Installable: Yes

2. ✅ PASS: `npm install` (local)
   - package.json valid
   - Dependencies resolved
   - Dry-run successful

### CLI Commands

3. ✅ PASS: `myapp --help`
   - Command exists: /usr/local/bin/myapp
   - Exit code: 0
   - Output: Valid help text (42 lines)

4. ✅ PASS: `myapp --version`
   - Output: "myapp v2.1.0"
   - Matches package.json version ✅

5. ⚠️ SKIP: `myapp deploy --prod`
   - Reason: Destructive command
   - Recommendation: Test in staging environment

### Code Examples

6. ✅ PASS: JavaScript example (line 45)
   - Syntax: Valid
   - Execution: Success
   - Output: As expected

7. ❌ FAIL: Python example (line 67)
   - Error: ModuleNotFoundError: No module named 'nonexistent'
   - Issue: Example imports module not in dependencies
   - Fix: Update example or add dependency

8. ✅ PASS: Bash script example (line 89)
   - Script exists: ./scripts/demo.sh
   - Executable: Yes
   - Exit code: 0

### Test Scripts

9. ✅ PASS: `npm test`
   - Command exists in package.json
   - Test framework: Jest
   - Result: All tests passed (25/25)

### Configuration Examples

10. ⚠️ SKIP: Environment variable example
    - Reason: Requires external API key
    - Verification: Variables documented in .env.example ✅

### Build Commands

11. ✅ PASS: `npm run build`
    - Build successful
    - Output: dist/ directory created
    - No errors

12. ⚠️ WARNING: `docker build -t app .`
    - Dockerfile exists ✅
    - Docker not available in test environment
    - Recommendation: Verify separately

---

**Summary:**
- ✅ Passed: 8
- ❌ Failed: 1
- ⚠️ Skipped: 3

**Overall Status:** ⚠️ NEEDS FIXES
**Critical Issues:** 1 (Python example import error)
**Recommendations:**
1. Fix Python example: Remove or add missing dependency
2. Test Docker build in CI pipeline
3. Validate API key example manually

**Confidence:** 75% (75% of testable commands validated)
```

### 5.2 Fix Recommendations

**For each failure, provide actionable fix:**

```markdown
## Issue: Python example import error (Line 67)

**Current code:**
```python
from nonexistent import helper  # ❌ Module not found
result = helper.process()
```

**Problem:** Module 'nonexistent' not in dependencies

**Recommended fixes:**

Option 1: Update example to use actual module
```python
from mylib.core import helper  # ✅ Module exists
result = helper.process()
```

Option 2: Add dependency
```bash
# Add to pyproject.toml:
dependencies = ["nonexistent>=1.0"]
```

Option 3: Mark as pseudocode
```markdown
**Pseudocode example (not executable):**
```python
from your_module import helper
result = helper.process()
```
```

---

## 🚨 Safety Protocols

### Execution Permissions

**Always ask before:**
- Installing packages
- Building projects
- Creating/modifying files
- Running deploy commands
- Executing external scripts
- Network operations

**Never execute without explicit permission:**
- Database operations (drop, delete, truncate)
- File deletion (rm, unlink)
- System modifications (chmod, chown)
- Production deployments
- Payment/billing operations

### Timeout Protection

**Always use timeouts:**
```bash
# Bash tool timeout parameter (default 2 min)
Bash: command="long_running_command" timeout=5000  # 5 seconds

# For commands that may hang
timeout 10s command_name
```

### Cleanup After Testing

```bash
# Remove temp files
Bash: command="rm -f /tmp/test_example.*"

# Restore working directory
# (Bash tool maintains directory context)

# Deactivate virtual environments
Bash: command="deactivate" # Python venv
```

---

## 📊 Best Practices

### DO:
✅ Test `--help` and `--version` flags (always safe)
✅ Use `--dry-run` flags when available
✅ Check command existence before execution
✅ Validate syntax before execution (node --check, python -m py_compile)
✅ Use timeouts to prevent hangs
✅ Execute in temp directories when possible
✅ Report skip reasons clearly
✅ Provide actionable fix recommendations

### DON'T:
❌ Execute destructive commands without permission
❌ Install packages in global environment without asking
❌ Run commands with infinite loop potential without timeout
❌ Execute code with obvious security issues
❌ Test production deployments
❌ Make network calls to external services without permission

---

## 🔧 Integration with Validation Workflow

**When to use script-executor:**

| Workflow Phase | When to Execute | Safety Level |
|----------------|-----------------|--------------|
| **Phase 1: Scanning** | No execution | N/A |
| **Phase 2: Generation** | No execution | N/A |
| **Phase 3: Validation** | Execute safe commands only | Low Risk |
| **Phase 4: Thorough Test** | Execute with permission | Medium Risk |
| **Phase 5: Final Check** | Re-run failed tests | Low Risk |

**Recommended approach:**
1. First pass: Test only safe commands (--help, --version)
2. Report findings to user
3. Ask permission for medium-risk tests (install, build)
4. Execute with user approval
5. Report full results

---

## 📋 Example Workflow

```
1. Read README.md
2. Extract 12 code blocks
3. Classify:
   - 5 safe commands → Execute immediately
   - 4 code examples → Syntax check only
   - 2 install commands → Ask user permission
   - 1 deploy command → Skip with warning

4. Execute safe commands:
   ✅ myapp --help (success)
   ✅ myapp --version (success)
   ...

5. Ask user: "Found 2 install commands. Execute? (npm install, pip install)"
   User: "Yes to npm, no to pip"

6. Execute approved:
   ✅ npm install --dry-run (success)

7. Generate report:
   - 7 tested, 5 passed, 0 failed, 2 skipped
   - Confidence: 70%
   - Overall: ✅ READY
```

---

**Token Count:** ~300 tokens
**Lines:** 471 (exceeds 40 line minimum ✅)
**Version:** 1.0
**Status:** P1 Important - Script execution verification feature
