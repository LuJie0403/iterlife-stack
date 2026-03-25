#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_TARGETS_FILE="${DEPLOY_TARGETS_FILE:-$ROOT_DIR/config/deploy-targets.json}"
DEPLOY_TARGET_SERVICE="${DEPLOY_TARGET_SERVICE:-}"
RELEASE_IMAGE_REF="${RELEASE_IMAGE_REF:-}"

GHCR_REGISTRY="${GHCR_REGISTRY:-ghcr.io}"
GHCR_USERNAME="${GHCR_USERNAME:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"
GHCR_RETRY_COUNT="${GHCR_RETRY_COUNT:-4}"
GHCR_RETRY_WAIT_SECONDS="${GHCR_RETRY_WAIT_SECONDS:-8}"
GHCR_LOGIN_TIMEOUT_SECONDS="${GHCR_LOGIN_TIMEOUT_SECONDS:-60}"
GHCR_PULL_TIMEOUT_SECONDS="${GHCR_PULL_TIMEOUT_SECONDS:-600}"
COMPOSE_UP_TIMEOUT_SECONDS="${COMPOSE_UP_TIMEOUT_SECONDS:-300}"
HEALTH_RETRIES_DEFAULT="${HEALTH_RETRIES_DEFAULT:-30}"
HEALTH_WAIT_SECONDS_DEFAULT="${HEALTH_WAIT_SECONDS_DEFAULT:-2}"

log() {
  echo "[deploy-service-from-ghcr] $*"
}

die() {
  echo "[deploy-service-from-ghcr][error] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

check_file() {
  [ -f "$1" ] || die "Required file not found: $1"
}

retry_cmd() {
  local attempts="$1"
  local wait_seconds="$2"
  shift 2

  local try_num=1
  while true; do
    if "$@"; then
      return 0
    fi

    if [ "$try_num" -ge "$attempts" ]; then
      return 1
    fi

    log "Command failed (attempt ${try_num}/${attempts}): $*"
    sleep "$wait_seconds"
    try_num=$((try_num + 1))
  done
}

wait_for_http_ok() {
  local url="$1"
  local retries="$2"
  local sleep_seconds="$3"
  local i
  for i in $(seq 1 "$retries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
  done
  return 1
}

parse_image_metadata() {
  local image_ref="$1"
  local image_without_digest="${image_ref%%@*}"
  local image_path="$image_without_digest"
  local image_tag=""

  if [[ "$image_without_digest" == *:* ]]; then
    image_tag="${image_without_digest##*:}"
    image_path="${image_without_digest%:*}"
  fi

  local path_after_registry="$image_path"
  if [[ "$image_path" == */* ]]; then
    path_after_registry="${image_path#*/}"
  fi

  local image_owner=""
  local image_name="$path_after_registry"
  if [[ "$path_after_registry" == */* ]]; then
    image_owner="${path_after_registry%%/*}"
    image_name="${path_after_registry##*/}"
  fi

  RELEASE_IMAGE_PATH="$image_path"
  RELEASE_IMAGE_TAG="$image_tag"
  RELEASE_IMAGE_OWNER="$image_owner"
  RELEASE_IMAGE_NAME="$image_name"
}

print_container_details() {
  local container_id="$1"
  local container_running_for
  local inspect_output

  container_running_for="$(docker ps --filter "id=${container_id}" --format '{{.RunningFor}}' | head -n 1)"
  inspect_output="$(
    docker inspect --format '{{.Id}}|{{.Name}}|{{.Config.Image}}|{{.Image}}|{{.Created}}|{{.State.Status}}|{{.State.StartedAt}}|{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}' \
      "$container_id"
  )"

  IFS='|' read -r inspected_id inspected_name configured_image image_id created_at status started_at compose_project compose_service <<<"$inspect_output"
  inspected_name="${inspected_name#/}"

  echo "release_registry=${GHCR_REGISTRY}"
  echo "release_owner=${RELEASE_IMAGE_OWNER}"
  echo "release_image_name=${RELEASE_IMAGE_NAME}"
  echo "release_image_tag=${RELEASE_IMAGE_TAG}"
  echo "container_id=${inspected_id}"
  echo "container_name=${inspected_name}"
  echo "container_configured_image=${configured_image}"
  echo "container_image_id=${image_id}"
  echo "container_created_at=${created_at}"
  echo "container_started_at=${started_at}"
  echo "container_running_for=${container_running_for}"
  echo "container_status=${status}"
  echo "compose_project=${compose_project}"
  echo "compose_service=${compose_service}"
}

require_cmd docker
require_cmd curl
require_cmd python3
require_cmd timeout

check_file "$DEPLOY_TARGETS_FILE"
[ -n "$DEPLOY_TARGET_SERVICE" ] || die "DEPLOY_TARGET_SERVICE is required"
[ -n "$RELEASE_IMAGE_REF" ] || die "RELEASE_IMAGE_REF is required"
parse_image_metadata "$RELEASE_IMAGE_REF"

eval "$(
  python3 - "$DEPLOY_TARGETS_FILE" "$DEPLOY_TARGET_SERVICE" <<'PY'
import json
import shlex
import sys

targets_path = sys.argv[1]
service = sys.argv[2]

with open(targets_path, "r", encoding="utf-8") as fp:
    data = json.load(fp)

target = data.get(service)
if not isinstance(target, dict):
    raise SystemExit(f"unknown deploy target: {service}")

required_fields = [
    "repo_dir",
    "compose_file",
    "compose_project_directory",
    "compose_service",
    "release_image_env",
    "local_image_env",
    "local_image_name",
    "healthcheck_url",
]

for field_name in required_fields:
    value = target.get(field_name, "")
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"missing required field '{field_name}' for {service}")

compose_no_deps = target.get("compose_no_deps", False)
if not isinstance(compose_no_deps, bool):
    raise SystemExit(f"compose_no_deps must be boolean for {service}")

values = {
    "TARGET_REPO_DIR": target["repo_dir"].strip(),
    "TARGET_COMPOSE_FILE": target["compose_file"].strip(),
    "TARGET_COMPOSE_PROJECT_DIRECTORY": target["compose_project_directory"].strip(),
    "TARGET_COMPOSE_SERVICE": target["compose_service"].strip(),
    "TARGET_RELEASE_IMAGE_ENV": target["release_image_env"].strip(),
    "TARGET_LOCAL_IMAGE_ENV": target["local_image_env"].strip(),
    "TARGET_LOCAL_IMAGE_NAME": target["local_image_name"].strip(),
    "TARGET_HEALTHCHECK_URL": target["healthcheck_url"].strip(),
    "TARGET_COMPOSE_NO_DEPS": "1" if compose_no_deps else "0",
}

for key, value in values.items():
    print(f"{key}={shlex.quote(value)}")
PY
)"

check_file "$TARGET_COMPOSE_FILE"

if [ -n "$GHCR_USERNAME" ] && [ -n "$GHCR_TOKEN" ]; then
  log "Logging into ${GHCR_REGISTRY} as ${GHCR_USERNAME}"
  if ! retry_cmd "$GHCR_RETRY_COUNT" "$GHCR_RETRY_WAIT_SECONDS" \
      timeout --signal=TERM --kill-after=10s "${GHCR_LOGIN_TIMEOUT_SECONDS}s" \
      sh -c "printf '%s' \"\$GHCR_TOKEN\" | docker login \"$GHCR_REGISTRY\" -u \"$GHCR_USERNAME\" --password-stdin >/dev/null"; then
    die "GHCR login failed after ${GHCR_RETRY_COUNT} attempts"
  fi
else
  log "GHCR credentials not provided by env; assuming server already logged in."
fi

log "Pulling image for ${DEPLOY_TARGET_SERVICE}: ${RELEASE_IMAGE_REF}"
if ! retry_cmd "$GHCR_RETRY_COUNT" "$GHCR_RETRY_WAIT_SECONDS" \
    timeout --signal=TERM --kill-after=10s "${GHCR_PULL_TIMEOUT_SECONDS}s" docker pull "$RELEASE_IMAGE_REF"; then
  die "Failed to pull image after ${GHCR_RETRY_COUNT} attempts: ${RELEASE_IMAGE_REF}"
fi

log "Tagging ${RELEASE_IMAGE_REF} as ${TARGET_LOCAL_IMAGE_NAME}"
docker tag "$RELEASE_IMAGE_REF" "$TARGET_LOCAL_IMAGE_NAME"

export "${TARGET_RELEASE_IMAGE_ENV}=${RELEASE_IMAGE_REF}"
export "${TARGET_LOCAL_IMAGE_ENV}=${TARGET_LOCAL_IMAGE_NAME}"

compose_args=(
  --project-directory "$TARGET_COMPOSE_PROJECT_DIRECTORY"
  -f "$TARGET_COMPOSE_FILE"
  up -d --no-build
)
if [ "$TARGET_COMPOSE_NO_DEPS" = "1" ]; then
  compose_args+=(--no-deps)
fi
compose_args+=("$TARGET_COMPOSE_SERVICE")

log "Starting service via docker compose: ${TARGET_COMPOSE_SERVICE}"
timeout --signal=TERM --kill-after=10s "${COMPOSE_UP_TIMEOUT_SECONDS}s" \
  docker compose "${compose_args[@]}"

if ! wait_for_http_ok "$TARGET_HEALTHCHECK_URL" "$HEALTH_RETRIES_DEFAULT" "$HEALTH_WAIT_SECONDS_DEFAULT"; then
  docker compose --project-directory "$TARGET_COMPOSE_PROJECT_DIRECTORY" \
    -f "$TARGET_COMPOSE_FILE" logs --tail=200 "$TARGET_COMPOSE_SERVICE" || true
  die "Health check failed: ${TARGET_HEALTHCHECK_URL}"
fi

container_id="$(docker compose --project-directory "$TARGET_COMPOSE_PROJECT_DIRECTORY" -f "$TARGET_COMPOSE_FILE" ps -q "$TARGET_COMPOSE_SERVICE" | head -n 1)"
[ -n "$container_id" ] || die "Unable to resolve container id for ${TARGET_COMPOSE_SERVICE}"

log "Deployment completed for ${DEPLOY_TARGET_SERVICE}"
echo "service=${DEPLOY_TARGET_SERVICE}"
echo "image_ref=${RELEASE_IMAGE_REF}"
echo "local_image_name=${TARGET_LOCAL_IMAGE_NAME}"
echo "healthcheck_url=${TARGET_HEALTHCHECK_URL}"
print_container_details "$container_id"
