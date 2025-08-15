#!/bin/bash
BRANCH_NAME="backup-$(date +"%Y%m%d")"

# Create a new branch from main
git checkout main
git pull origin main
git checkout -b $BRANCH_NAME

# Push to GitHub
git push origin HEAD

# Switch back to main
git checkout main

echo "✅ Daily backup created: $BRANCH_NAME"

