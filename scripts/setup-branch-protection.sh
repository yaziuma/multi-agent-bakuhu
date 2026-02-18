#!/bin/bash
# GitHub Branch Protection Setup Script
# Usage: ./setup-branch-protection.sh [REPO]
#   REPO: owner/repo format (default: yaziuma/multi-agent-bakuhu)

set -euo pipefail

REPO="${1:-yaziuma/multi-agent-bakuhu}"
BRANCH="main"

echo "Setting up branch protection for $REPO on branch $BRANCH..."

# Branch protection configuration
# Requires:
# - Pull request reviews (1 approval)
# - CODEOWNERS review
# - Dismiss stale reviews on new commits
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  -f required_pull_request_reviews[required_approving_review_count]=1 \
  -F required_pull_request_reviews[dismiss_stale_reviews]=true \
  -F required_pull_request_reviews[require_code_owner_reviews]=true \
  -F enforce_admins=false \
  -F required_linear_history=false \
  -F allow_force_pushes=false \
  -F allow_deletions=false \
  -f restrictions=null \
  -f required_status_checks=null

echo "✅ Branch protection configured successfully"
echo ""
echo "Protection rules applied:"
echo "  - Requires 1 approving review"
echo "  - Requires CODEOWNERS approval"
echo "  - Dismisses stale reviews on new commits"
echo "  - Blocks force pushes"
echo "  - Blocks branch deletion"
