#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="${1:-webhook/iterlife-deploy-webhook.env.example}"
TARGETS_FILE_OVERRIDE="${2:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
  echo "[validate-webhook-config][error] $*" >&2
  exit 1
}

[ -f "$ENV_FILE" ] || die "env file not found: $ENV_FILE"

targets_line="$(grep -E '^DEPLOY_TARGETS_FILE=' "$ENV_FILE" | tail -n 1 || true)"
[ -n "$targets_line" ] || die "DEPLOY_TARGETS_FILE is missing in $ENV_FILE"
targets_path="${targets_line#DEPLOY_TARGETS_FILE=}"
[ -n "$targets_path" ] || die "DEPLOY_TARGETS_FILE cannot be empty in $ENV_FILE"

if [ -n "$TARGETS_FILE_OVERRIDE" ]; then
  targets_path="$TARGETS_FILE_OVERRIDE"
fi

if [ ! -f "$targets_path" ] && [[ "$targets_path" == /apps/iterlife-stack/* ]]; then
  local_candidate="$ROOT_DIR/${targets_path#/apps/iterlife-stack/}"
  if [ -f "$local_candidate" ]; then
    targets_path="$local_candidate"
  fi
fi

if [ ! -f "$targets_path" ] && [[ "$targets_path" == /apps/iterlife-reunion-stack/* ]]; then
  local_candidate="$ROOT_DIR/${targets_path#/apps/iterlife-reunion-stack/}"
  if [ -f "$local_candidate" ]; then
    targets_path="$local_candidate"
  fi
fi

[ -f "$targets_path" ] || die "deploy targets file not found: $targets_path"

python3 - "$targets_path" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fp:
    try:
        data = json.load(fp)
    except Exception as exc:
        raise SystemExit(f"DEPLOY_TARGETS_FILE invalid JSON: {exc}")

if not isinstance(data, dict) or not data:
    raise SystemExit("DEPLOY_TARGETS_FILE must be a non-empty object")

required_keys = {
    "iterlife-reunion-api",
    "iterlife-reunion-ui",
    "iterlife-expenses-api",
    "iterlife-expenses-ui",
    "iterlife-idaas-api",
    "iterlife-idaas-ui",
}

required_fields = {
    "compose_file",
    "compose_project_directory",
    "compose_service",
    "release_image_env",
    "runtime_image_env",
    "runtime_image_name",
    "deployment_state_file",
    "healthcheck_url",
}

for key, value in data.items():
    if not isinstance(key, str) or not key.strip():
        raise SystemExit("service key must be non-empty string")
    if not isinstance(value, dict):
        raise SystemExit(f"service '{key}' must map to object config")

    for field_name in required_fields:
        field_value = str(value.get(field_name, "")).strip()
        if not field_value:
            raise SystemExit(f"service '{key}' missing {field_name}")
        if field_name in {"compose_file", "compose_project_directory"} and not field_value.startswith("/apps/"):
            raise SystemExit(
                f"service '{key}' {field_name} must be absolute /apps path: {field_value}"
            )
    compose_no_deps = value.get("compose_no_deps", False)
    if not isinstance(compose_no_deps, bool):
        raise SystemExit(f"service '{key}' compose_no_deps must be boolean")

missing = sorted(required_keys - set(data.keys()))
if missing:
    raise SystemExit(f"missing standard service keys: {', '.join(missing)}")

print(
    "ok: DEPLOY_TARGETS_FILE parsed with services="
    + ",".join(sorted(data.keys()))
)
PY

echo "[validate-webhook-config] success: $ENV_FILE -> $targets_path"
