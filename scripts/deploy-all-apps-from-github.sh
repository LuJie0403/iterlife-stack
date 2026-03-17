#!/usr/bin/env bash
# One-click standard deployment for all IterLife applications on a single server.
# Executes per-app "deploy-*-from-github.sh" scripts, each using git pull --ff-only.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REUNION_REPO_DIR="${REUNION_REPO_DIR:-$(cd "$ROOT_DIR/.." && pwd)/iterlife-reunion}"
EXPENSES_REPO_DIR="${EXPENSES_REPO_DIR:-$(cd "$ROOT_DIR/.." && pwd)/iterlife-expenses}"

REUNION_BRANCH="${REUNION_BRANCH:-main}"
EXPENSES_BRANCH="${EXPENSES_BRANCH:-main}"

DEPLOY_REUNION="${DEPLOY_REUNION:-true}"
DEPLOY_EXPENSES="${DEPLOY_EXPENSES:-true}"

ALLOW_DIRTY="${ALLOW_DIRTY:-false}"
SKIP_CODE_BACKUP="${SKIP_CODE_BACKUP:-false}"

log() {
  echo "[deploy-all] $*"
}

die() {
  echo "[deploy-all][error] $*" >&2
  exit 1
}

check_script() {
  local script_file="$1"
  [ -f "$script_file" ] || die "Missing script: $script_file"
}

if [ "$DEPLOY_REUNION" = "true" ]; then
  check_script "$REUNION_REPO_DIR/deploy/scripts/deploy-reunion-from-github.sh"
  log "Deploying reunion stack from branch: $REUNION_BRANCH"
  DEPLOY_BRANCH="$REUNION_BRANCH" \
  ALLOW_DIRTY="$ALLOW_DIRTY" \
  SKIP_CODE_BACKUP="$SKIP_CODE_BACKUP" \
  bash "$REUNION_REPO_DIR/deploy/scripts/deploy-reunion-from-github.sh"
fi

if [ "$DEPLOY_EXPENSES" = "true" ]; then
  check_script "$EXPENSES_REPO_DIR/deploy-expenses-from-github.sh"
  log "Deploying expenses stack from branch: $EXPENSES_BRANCH"
  DEPLOY_BRANCH="$EXPENSES_BRANCH" \
  ALLOW_DIRTY="$ALLOW_DIRTY" \
  SKIP_CODE_BACKUP="$SKIP_CODE_BACKUP" \
  bash "$EXPENSES_REPO_DIR/deploy-expenses-from-github.sh"
fi

log "All requested deployments completed."
