# README Expert - Knowledge Base Index

**Purpose:** Navigation map for the readme-expert skill knowledge base. This index helps Claude efficiently locate and load the right knowledge files when needed.

---

## 📁 Directory Structure

```
knowledge/
├── INDEX.md (this file)
├── foundation/          # P0: Core anti-hallucination techniques
│   ├── codebase-scanner.md
│   └── validation-checklist.md
└── application/         # P1: Implementation guides
    ├── script-executor.md
    ├── template-library.md
    └── quality-standards.md
```

---

## 🎯 Priority Levels

**P0 (Critical - Foundation/)**: Must-read for core functionality
- Anti-hallucination validation techniques
- Codebase scanning strategies
- Verification checklists

**P1 (Important - Application/)**: Enhanced features and standards
- Script execution testing
- Template selection
- Quality metrics

**P2 (Optional)**: Will be added in future if needed
- Badge generation
- Example galleries
- Troubleshooting guides

---

## 📚 File Map

### Foundation Files (P0)

#### `foundation/codebase-scanner.md`
**Purpose:** Techniques for scanning and extracting accurate codebase information
**Use When:** Starting README generation, need to gather project facts
**Key Content:**
- File system scanning strategies (Glob patterns)
- Content extraction (Grep for functions, classes, imports)
- Package metadata parsing (package.json, pyproject.toml, etc)
- Dependency analysis
- Project type detection

**Token Budget:** ~280 tokens | **Lines:** 110-130

---

#### `foundation/validation-checklist.md`
**Purpose:** Step-by-step anti-hallucination verification checklist
**Use When:** Validating generated README content for accuracy
**Key Content:**
- 5-layer verification process
- File existence checking
- Link/path validation
- Citation tracking
- Quote extraction techniques
- Confidence scoring for claims

**Token Budget:** ~250 tokens | **Lines:** 100-120

---

### Application Files (P1)

#### `application/script-executor.md`
**Purpose:** Execute and test code examples and commands in README
**Use When:** Verifying installation instructions, usage examples, CLI commands
**Key Content:**
- Code block extraction from markdown
- Safe execution environment setup
- Exit code verification
- Output validation patterns
- Multi-step command testing
- Error handling and reporting

**Token Budget:** ~300 tokens | **Lines:** 120-140

---

#### `application/template-library.md`
**Purpose:** Project-specific README templates and structure guidelines
**Use When:** Selecting appropriate README structure for project type
**Key Content:**
- Standard-readme specification
- Templates by language (Python, JavaScript, Go, Rust, etc)
- Templates by type (Library, CLI, Web App, API, etc)
- Required sections per template
- Optional sections per context

**Token Budget:** ~280 tokens | **Lines:** 100-120

---

#### `application/quality-standards.md`
**Purpose:** Quality metrics and README best practices
**Use When:** Final validation, quality scoring, compliance checking
**Key Content:**
- Standard-readme compliance checklist
- Google style guide principles
- Readability metrics (Flesch-Kincaid, etc)
- Completeness scoring
- Common anti-patterns to avoid
- Accessibility guidelines

**Token Budget:** ~250 tokens | **Lines:** 90-110

---

## 🔍 Quick Reference Guide

### For Codebase Analysis
→ Load: `foundation/codebase-scanner.md`

### For Validation & Anti-Hallucination
→ Load: `foundation/validation-checklist.md`

### For Testing Scripts/Commands
→ Load: `application/script-executor.md`

### For Template Selection
→ Load: `application/template-library.md`

### For Quality Assessment
→ Load: `application/quality-standards.md`

---

## 📖 Usage Patterns

### Pattern 1: Full README Creation
**Load order:**
1. `codebase-scanner.md` - Gather facts
2. `template-library.md` - Choose structure
3. `validation-checklist.md` - Verify accuracy
4. `script-executor.md` - Test examples
5. `quality-standards.md` - Final assessment

### Pattern 2: Validation Only
**Load order:**
1. `validation-checklist.md` - Core checks
2. `script-executor.md` - Test scripts
3. `quality-standards.md` - Quality score

### Pattern 3: Quick Generation
**Load order:**
1. `codebase-scanner.md` - Quick scan
2. `template-library.md` - Use template
3. `validation-checklist.md` - Basic validation

---

## 🎓 Design Philosophy

**Token Efficiency:** Each file is self-contained with minimal redundancy
**On-Demand Loading:** Load only what's needed for the current task
**Progressive Disclosure:** P0 → P1 → P2 as complexity increases
**Citation-First:** All techniques emphasize grounding in codebase reality

---

## 📊 Knowledge Base Statistics

- **Total Files:** 5 (P0: 2, P1: 3, P2: 0)
- **Total Tokens:** ~1,360 tokens (P0: 530, P1: 830)
- **Total Lines:** ~520-620 lines
- **Update Frequency:** Stable (v1.0)

---

## 🚀 Next Steps After Reading INDEX

1. **For skill development:** Start with P0 files
2. **For skill usage:** Refer to SKILL.md frontmatter for triggers
3. **For enhancement:** Add P2 files when needed

---

**Last Updated:** 2025-11-13
**Version:** 1.0
**Maintained by:** readme-expert skill framework
