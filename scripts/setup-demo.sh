#!/usr/bin/env bash
#
# One-time GitHub configuration for demo-contract-provider using a GitHub App
# (the realistic production identity — not tied to any individual developer).
#
# The App is created ONCE in the GitHub UI (see README "GitHub App setup"),
# installed on BOTH demo repos, and acts as its own bot actor. Developers do
# nothing except raise PRs.
#
# Prerequisites:
#   - gh CLI installed and authenticated as the repo owner (`gh auth login`).
#   - You have created a GitHub App and installed it on both demo repos.
#   - You have its App ID and a downloaded private-key .pem file.
#
# Env:
#   APP_ID                 numeric App ID            (required)
#   APP_PRIVATE_KEY_FILE   path to the App .pem file (required)
#   DISPATCH_PAT           optional demo-only PAT fallback (leave unset for App-only)
#
# Usage:
#   export APP_ID=123456
#   export APP_PRIVATE_KEY_FILE=~/Downloads/contract-verifier.private-key.pem
#   ./scripts/setup-demo.sh            # infers owner from `gh api user`
#   ./scripts/setup-demo.sh <owner>    # or pass your username explicitly
set -euo pipefail

SELF_REPO="demo-contract-provider"
PARTNER_REPO_NAME="demo-contract-consumer"
# Single aggregated status context published by cross-repo-verify.yml.
REQUIRED_CONTEXT="contract-verification"

OWNER="${1:-$(gh api user --jq .login)}"
echo "Configuring ${OWNER}/${SELF_REPO} (partner: ${OWNER}/${PARTNER_REPO_NAME})"

if [[ -z "${APP_ID:-}" || -z "${APP_PRIVATE_KEY_FILE:-}" ]]; then
  echo "ERROR: export APP_ID and APP_PRIVATE_KEY_FILE first (see README GitHub App setup)." >&2
  echo "       For the demo-only PAT fallback instead, set DISPATCH_PAT and skip APP_ID." >&2
  [[ -n "${DISPATCH_PAT:-}" ]] || exit 1
fi

# 1) Deterministic partner for discovery + reporting target.
gh variable set PARTNER_REPO -R "${OWNER}/${SELF_REPO}" --body "${OWNER}/${PARTNER_REPO_NAME}"

# 2) GitHub App identity (preferred). Workflows use it whenever APP_ID is set.
if [[ -n "${APP_ID:-}" ]]; then
  [[ -f "${APP_PRIVATE_KEY_FILE}" ]] || { echo "Private key file not found: ${APP_PRIVATE_KEY_FILE}" >&2; exit 1; }
  gh variable set APP_ID          -R "${OWNER}/${SELF_REPO}" --body "${APP_ID}"
  gh secret   set APP_PRIVATE_KEY -R "${OWNER}/${SELF_REPO}" < "${APP_PRIVATE_KEY_FILE}"
fi

# 3) Optional demo-only PAT fallback (used only when APP_ID is unset).
if [[ -n "${DISPATCH_PAT:-}" ]]; then
  printf '%s' "${DISPATCH_PAT}" | gh secret set DISPATCH_PAT -R "${OWNER}/${SELF_REPO}"
fi

# 4) Require the verification status check before merge (this BLOCKS merging).
gh api -X PUT "repos/${OWNER}/${SELF_REPO}/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=${REQUIRED_CONTEXT}" \
  -F "enforce_admins=true" \
  -f "required_pull_request_reviews[required_approving_review_count]=0" \
  -F "restrictions="

echo "Done. ${OWNER}/${SELF_REPO}: PARTNER_REPO + App identity set, '${REQUIRED_CONTEXT}' required on main."
