#!/usr/bin/env bash
#
# One-time GitHub configuration for the demo-contract-provider repo on a
# PERSONAL account (no org, no GitHub App approval needed).
#
# Prerequisites:
#   - gh CLI installed and authenticated as your personal user (`gh auth login`)
#   - A fine-grained PAT with access to BOTH demo repos, with permissions:
#       Contents: Read | Commit statuses: Read/Write | Pull requests: Read/Write | Metadata: Read
#     Export it before running:  export DISPATCH_PAT=github_pat_xxx
#
# Usage:
#   export DISPATCH_PAT=github_pat_xxx
#   ./scripts/setup-demo.sh            # infers owner from `gh api user`
#   ./scripts/setup-demo.sh <owner>    # or pass your username explicitly
set -euo pipefail

SELF_REPO="demo-contract-provider"
PARTNER_REPO_NAME="demo-contract-consumer"
# This repo's PR is blocked by the UPSTREAM (consumer) check when it acts as a
# provider; the single aggregated context we publish is 'contract-verification'.
REQUIRED_CONTEXT="contract-verification"

OWNER="${1:-$(gh api user --jq .login)}"
echo "Configuring ${OWNER}/${SELF_REPO} (partner: ${OWNER}/${PARTNER_REPO_NAME})"

if [[ -z "${DISPATCH_PAT:-}" ]]; then
  echo "ERROR: export DISPATCH_PAT=<fine-grained-pat> first." >&2
  exit 1
fi

# 1) Deterministic partner for discovery + reporting target.
gh variable set PARTNER_REPO -R "${OWNER}/${SELF_REPO}" --body "${OWNER}/${PARTNER_REPO_NAME}"

# 2) Demo credential the workflows fall back to when APP_ID is unset.
printf '%s' "${DISPATCH_PAT}" | gh secret set DISPATCH_PAT -R "${OWNER}/${SELF_REPO}"

# 3) Require the verification status check before merge (this is what BLOCKS merging).
gh api -X PUT "repos/${OWNER}/${SELF_REPO}/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=${REQUIRED_CONTEXT}" \
  -F "enforce_admins=true" \
  -f "required_pull_request_reviews[required_approving_review_count]=0" \
  -F "restrictions="

echo "Done. ${OWNER}/${SELF_REPO}: PARTNER_REPO + DISPATCH_PAT set, '${REQUIRED_CONTEXT}' required on main."
