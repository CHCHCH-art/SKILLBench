#!/bin/bash

# Runbook Generator Script
# Usage: ./create-runbook.sh <runbook-path>
# Example: ./create-runbook.sh runbooks/user-login-flow

set -e

# Check if path argument is provided
if [ -z "$1" ]; then
    echo "Error: Runbook path is required"
    echo "Usage: $0 <runbook-path>"
    echo "Example: $0 runbooks/user-login-flow"
    exit 1
fi

RUNBOOK_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_PATH="$SCRIPT_DIR/../assets/runbook-template.md"

# Ensure the template exists
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Error: Template not found at $TEMPLATE_PATH"
    exit 1
fi

# Create the runbook directory
mkdir -p "$RUNBOOK_PATH"

# Copy the template to STEPS.md
cp "$TEMPLATE_PATH" "$RUNBOOK_PATH/STEPS.md"

echo "✓ Runbook created at: $RUNBOOK_PATH/STEPS.md"
echo ""
echo "Next steps:"
echo "1. Edit $RUNBOOK_PATH/STEPS.md"
echo "2. Fill in the overview, requirements, steps, and validations"
echo "3. Test the runbook to ensure it's reproducible"
