# Runbook: [Task Name]

## Overview

[Brief description of what this runbook accomplishes and when to use it]

## Technical Requirements

### Environment

- **Target Environment**: [local | dev | staging | production]
- **Required Access**: [List credentials, VPN, permissions needed]

### Prerequisites

- **Git State**:
  ```bash
  git checkout [branch-name or commit-hash]
  ```

- **Database State**:
  - [Describe required database state]
  - [Any records that need to exist or be deleted]
  ```sql
  -- Example cleanup or setup queries
  DELETE FROM table_name WHERE condition;
  ```

- **Configuration**:
  - [Environment variables needed]
  - [Configuration files to check/modify]
  - [Feature flags to enable/disable]

- **Services**:
  - [List of services that must be running]
  - [External dependencies that must be available]

## HTTP Scripts (if applicable)

If this runbook contains HTTP requests, create scripts in the `scripts/` directory.

> **Important**: All scripts must be executed under supervision. Review each script before execution and verify the target endpoints are correct for your environment.

```
./scripts/
├── activation.sh              # Environment setup and script-http alias
├── .env                       # Secrets (git-ignored)
├── .env.example               # Example configuration
├── [endpoint-name].httpie.sh
└── responses/
    └── [timestamp]-[endpoint-name].httpie.http
```

### Activation Script

Before running HTTP scripts, activate the environment:

```bash
source ./scripts/activation.sh
```

This loads `.env` secrets and provides the `script-http` function.

### Example Script

```bash
#!/bin/bash
# Usage: source ./activation.sh && ./endpoint.httpie.sh

set -e

BASE_URL="${API_BASE_URL:-https://api.example.com}"

script-http POST "$BASE_URL/endpoint" \
    key=value
```

## Steps to Reproduce

### Step 1: Activate Environment (if using HTTP scripts)

**Action**: Load environment variables and aliases

**Command**:
```bash
source ./scripts/activation.sh
```

---

### Step 2: [Action Name]

**Action**: [Describe what to do]

**Command/Interaction**:
```bash
# Using httpie script (recommended)
./scripts/[endpoint-name].httpie.sh
```

**Expected Result**: [What should happen]

---

### Step 2: [Action Name]

**Action**: [Describe what to do]

**UI Interaction**:
- Navigate to [URL or page]
- Click on [specific element]
- Enter [specific data] in [field name]
- Click [button name]

**Expected Result**: [What should happen]

---

### Step 3: [Action Name]

**Action**: [Describe what to do]

**Command/Interaction**:
```bash
# Example command
```

**Expected Result**: [What should happen]

---

[Add more steps as needed]

## Validations

### Database Validation

Check the database state:
```sql
SELECT * FROM table_name WHERE condition;
```

**Expected Result**: [Describe what the query should return]

---

### API Validation

Verify the API response:
```bash
curl -X GET https://api.example.com/status
```

**Expected Result**: [Describe expected response]

---

### UI Validation

Check the user interface:
- Navigate to [URL]
- Verify [specific element] displays [expected state]
- Confirm [specific message or data] is visible

**Expected Result**: [Describe what should be visible]

---

### Success Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Notes

[Any additional context, known issues, or important considerations]

## Troubleshooting

**Issue**: [Common problem]
**Solution**: [How to resolve]

---

**Issue**: [Common problem]
**Solution**: [How to resolve]
