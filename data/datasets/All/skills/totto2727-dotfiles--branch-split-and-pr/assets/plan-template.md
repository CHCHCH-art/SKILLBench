# Branch Split Plan

## Overview

A plan for splitting current changes into separate branches by unit.

**Rules**:

- New additions (tests, etc.) always get separate branches
- Existing modifications are included in the related new PR (but as separate commits)
- **Halt work immediately if conflicts or errors occur, and request instructions**

## File Dependency Analysis

### Changed Files and Dependencies

| Group | Target File         | Dependent Mocks/Assets (New/Changed) | Type              |
| ----- | ------------------- | ------------------------------------ | ----------------- |
| **A** | (e.g., xxx.test.js) | (list of dependent mocks)            | New               |
| **A** | (e.g., yyy.test.js) | (same as above)                      | Existing Modified |
| **B** | (e.g., zzz.test.js) | (same as above)                      | Existing Modified |

---

## Branch Split Plan

### Branches to Create

| #   | Branch Name    | New Target    | Existing Modifications          | Dependencies |
| --- | -------------- | ------------- | ------------------------------- | ------------ |
| 1   | `test/<name1>` | (target name) | (list of related modifications) | None         |
| 2   | `test/<name2>` | None          | (existing modifications only)   | None         |

---

## Git Workflow (Strictly Follow)

Follow this flow strictly when creating each branch.

**Note**: If conflicts or errors occur, halt work immediately and request instructions.

```bash
# 1. Stage all changes (required to include new files in stash)
git add .

# 2. Save to stash (with a message identifying the work)
git stash push -m "wip: changes for <branch-name>"

# 3. Switch to base branch & create new branch
git switch -f <base-branch>
git switch -c <branch-name>

# 4. Restore stash
git stash apply stash@{0}

# 5. Unstage all
git unstage

# 6. Add only the files to commit and commit
git add <file1> <file2> ...
git commit -m "<commit-message>"
```

---

## Detailed Workflow

### Branch 1: `test/<name1>`

**Purpose**: (purpose of this branch)

**Base Branch**: `develop` (change as needed)

#### Preparation

```bash
git add .
git stash push -m "wip: changes for test/<name1>"
git switch -f develop
git switch -c test/<name1>
git stash apply stash@{0}
git unstage
```

#### Commit 1: (description)

```bash
git add <path1>
git commit -m "<type>(scope): <message>"
```

#### Commit 2: (description)

```bash
git add <path2> <path3>
git commit -m "<type>(scope): <message>"
```

---

### Branch 2: `test/<name2>`

**Purpose**: (purpose of this branch)

**Base Branch**: `develop`

#### Preparation

```bash
git add .
git stash push -m "wip: changes for test/<name2>"
git switch -f develop
git switch -c test/<name2>
git stash apply stash@{0}
git unstage
```

#### Commit

```bash
git add <path>
git commit -m "<type>(scope): <message>"
```

**Note**: Deleted files must also be staged with `git add <deleted-file-path>`.

---

## Dependency Diagram

```txt
develop
├── test/<name1> (independent or dependency description)
├── test/<name2> (independent)
└── ...
```

---

## Execution Order (Recommended)

(Description of whether parallel execution is possible or sequential order is required, with numbered list)

---

## Excluded Files

The following files should not be included in any branch:

- (e.g., working notes, plan drafts, etc.)

---

## Error Handling

**If conflicts or errors occur**:

1. Halt work immediately
2. Report current state
3. Request instructions

Do not attempt to resolve on your own.
