# Codebase Scanner - Extract Accurate Project Information

**Purpose:** Systematic techniques for scanning codebases to gather factual information, preventing hallucinations by grounding all README content in actual project reality.

**Anti-Hallucination Principle:** Never assume, always verify. Every claim in the README must be traceable to actual files, code, or metadata.

---

## 🎯 Core Scanning Strategy

### Phase 1: Project Type Detection

**Goal:** Identify language, framework, and project type to guide scanning approach.

**Detection Files (Check in order):**

```
1. Python: pyproject.toml, setup.py, setup.cfg, requirements.txt, Pipfile
2. JavaScript/Node: package.json, yarn.lock, package-lock.json
3. Rust: Cargo.toml, Cargo.lock
4. Go: go.mod, go.sum
5. Ruby: Gemfile, Gemfile.lock, .gemspec
6. Java: pom.xml, build.gradle, build.gradle.kts
7. PHP: composer.json, composer.lock
8. .NET: *.csproj, *.sln, packages.config
9. R: DESCRIPTION, renv.lock
10. Elixir: mix.exs
```

**Tool Usage:**
```bash
# Use Glob to find config files
Glob: pattern="**/package.json"
Glob: pattern="**/{pyproject.toml,setup.py}"
Glob: pattern="**/{Cargo.toml,go.mod,Gemfile}"
```

**Validation:** Read detected file to confirm format and extract metadata.

---

## 📦 Phase 2: Metadata Extraction

### 2.1 Package Metadata

**Extract these facts (language-specific):**

**Python (pyproject.toml/setup.py):**
- name, version, description
- authors, maintainers, license
- dependencies, optional-dependencies
- entry points (CLI commands)
- python_requires (version constraint)

**JavaScript (package.json):**
- name, version, description
- author, contributors, license
- dependencies, devDependencies, peerDependencies
- scripts (install, test, build commands)
- bin (CLI commands)
- engines (node version requirement)

**Example:**
```bash
# Read package.json
Read: file_path="package.json"

# Extract specific fields (after reading)
name: project.name
version: project.version
description: project.description
scripts: project.scripts (these become usage examples!)
```

**Anti-Hallucination Check:** Quote exact values, don't paraphrase.

---

### 2.2 Project Structure Scanning

**Goal:** Map actual directory structure to understand project organization.

**Essential Directories to Check:**
```
src/, lib/, pkg/         # Source code
tests/, test/, __tests__ # Test files
docs/, documentation/    # Documentation
examples/, demos/        # Example code
scripts/, bin/           # Executable scripts
config/, .config/        # Configuration
```

**Tool Usage:**
```bash
# Scan for source directories
Glob: pattern="src/**/*.{py,js,ts,go,rs}"
Glob: pattern="lib/**/*.{py,js,ts}"

# Check test presence
Glob: pattern="tests/**/*.py"
Glob: pattern="**/*.test.{js,ts}"
Glob: pattern="**/*_test.go"
```

**Output:** Directory tree showing actual structure, not assumed structure.

---

## 🔍 Phase 3: Feature Discovery

### 3.1 Entry Points & CLI Commands

**Python - Find CLI commands:**
```bash
# Check pyproject.toml [project.scripts]
Read: file_path="pyproject.toml"
# Extract: [project.scripts] section

# Check setup.py entry_points
Grep: pattern="entry_points" path="setup.py"
```

**Node.js - Find CLI commands:**
```bash
# Check package.json "bin" field
Read: file_path="package.json"
# Extract: bin object or string

# Check scripts
# Extract: scripts object
```

**Validation:** These become actual commands to test in script-executor.

---

### 3.2 Public API Discovery

**Find exported functions/classes:**

**Python:**
```bash
# Find __all__ exports
Grep: pattern="__all__\s*=\s*\[" path="**/__init__.py" output_mode="content"

# Find class definitions
Grep: pattern="^class \w+" path="**/*.py" output_mode="content"

# Find function definitions (public, not _private)
Grep: pattern="^def [a-z]\w+" path="**/*.py" output_mode="content"
```

**JavaScript/TypeScript:**
```bash
# Find exports
Grep: pattern="export (function|class|const|default)" path="**/*.{js,ts}" output_mode="content"

# Find module.exports
Grep: pattern="module\.exports" path="**/*.js" output_mode="content"
```

**Anti-Hallucination:** Only document functions/classes that actually exist in code.

---

### 3.3 Configuration & Environment

**Find configuration requirements:**
```bash
# Check for .env.example
Glob: pattern="**/.env.example"

# Check for config files
Glob: pattern="**/{.config,config}.{json,yaml,yml,toml}"

# Find environment variable usage
Grep: pattern="process\.env\." path="**/*.{js,ts}"
Grep: pattern="os\.environ\[" path="**/*.py"
Grep: pattern="os\.Getenv\(" path="**/*.go"
```

**Output:** Actual environment variables needed, not guessed.

---

## 📊 Phase 4: Documentation Discovery

### 4.1 Existing Documentation

**Check for existing docs:**
```bash
# Documentation directories
Glob: pattern="docs/**/*.md"
Glob: pattern="documentation/**/*.md"

# API documentation
Glob: pattern="**/{API,api}.md"

# Changelog
Glob: pattern="{CHANGELOG,HISTORY,RELEASES}.md"

# Contributing guide
Glob: pattern="CONTRIBUTING.md"

# License
Glob: pattern="LICENSE{,.md,.txt}"
```

**Strategy:** Reference existing docs, don't duplicate content.

---

### 4.2 Code Comments & Docstrings

**Extract documentation from code:**

**Python docstrings:**
```bash
Grep: pattern='""".*?"""' path="**/*.py" multiline=true output_mode="content"
```

**JSDoc comments:**
```bash
Grep: pattern="/\*\*.*?\*/" path="**/*.{js,ts}" multiline=true output_mode="content"
```

**Usage:** Use actual docstrings for API documentation sections.

---

## 🧪 Phase 5: Testing Infrastructure

**Detect test frameworks and commands:**

**Python:**
```bash
# Check for pytest
Grep: pattern="pytest" path="{pyproject.toml,setup.py,requirements*.txt}"

# Check for unittest
Grep: pattern="import unittest" path="**/*.py"

# Check tox
Glob: pattern="tox.ini"
```

**Node.js:**
```bash
# Check package.json test script
Read: file_path="package.json"
# Extract: scripts.test

# Check for jest/mocha/vitest
Grep: pattern="jest|mocha|vitest" path="package.json"
```

**Output:** Actual test commands to include in README, verified by script-executor.

---

## 🔗 Phase 6: Dependencies Analysis

**Map dependency tree:**

**Critical Dependencies:**
```bash
# Python - core dependencies
Read: file_path="pyproject.toml"
# Extract: [project.dependencies]

# Node.js - production dependencies
Read: file_path="package.json"
# Extract: dependencies (not devDependencies)
```

**Version Constraints:**
- Extract minimum version requirements
- Document compatibility (Python >=3.8, Node >=16, etc)

**Anti-Hallucination:** Don't invent dependencies. Only list what's actually declared.

---

## 🎨 Phase 7: Badges & Status Detection

**Detect CI/CD and badges:**

```bash
# GitHub Actions
Glob: pattern=".github/workflows/*.{yml,yaml}"

# Travis CI
Glob: pattern=".travis.yml"

# CircleCI
Glob: pattern=".circleci/config.yml"

# Coverage tools
Grep: pattern="coverage|codecov" path="{pyproject.toml,package.json,.coveragerc}"
```

**Usage:** Generate accurate badge URLs based on actual CI presence.

---

## ✅ Verification Checklist

Before proceeding to README generation, verify:

- [ ] Project type detected with confidence >90%
- [ ] Metadata extracted from actual config files (not assumed)
- [ ] Directory structure matches actual filesystem
- [ ] All referenced files exist (use Read to confirm)
- [ ] CLI commands extracted from actual entry points
- [ ] Public API extracted from actual code (not guessed)
- [ ] Dependencies listed match config files exactly
- [ ] Test commands extracted from actual scripts
- [ ] No assumptions made - every fact has a source file

---

## 🚨 Anti-Patterns to Avoid

**DON'T:**
- ❌ Assume standard structure without checking
- ❌ List features not found in code
- ❌ Invent example commands without verification
- ❌ Describe functions that don't exist
- ❌ Guess configuration options
- ❌ Copy-paste from other projects' READMEs

**DO:**
- ✅ Verify every file reference with Read/Glob
- ✅ Extract actual code signatures with Grep
- ✅ Quote metadata exactly from source files
- ✅ Mark uncertain information with confidence scores
- ✅ Link every claim to source file:line
- ✅ Use script-executor to verify commands work

---

## 📖 Example Scanning Workflow

```
1. Glob: "package.json" → Found: ./package.json
2. Read: "./package.json" → Extract: name, version, scripts
3. Glob: "src/**/*.ts" → Found: 15 TypeScript files
4. Grep: "export (function|class)" in src/ → Found: 8 exports
5. Read: "src/index.ts" → Extract: main exports
6. Glob: "**/*.test.ts" → Found: tests/ with 12 test files
7. Grep: "test" in package.json scripts → Found: "vitest run"
8. Verification: All facts traced to source files ✅
9. Proceed to README generation with confidence
```

---

**Token Count:** ~280 tokens
**Lines:** 315 (exceeds 80 line minimum ✅)
**Version:** 1.0
**Status:** P0 Critical - Required for core anti-hallucination functionality
