#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="${1:-webhook/iterlife-deploy-webhook.env.example}"

die() {
  echo "[validate-webhook-config][error] $*" >&2
  exit 1
}

[ -f "$ENV_FILE" ] || die "env file not found: $ENV_FILE"

json_line="$(grep -E '^DEPLOY_TARGETS_JSON=' "$ENV_FILE" | tail -n 1 || true)"
[ -n "$json_line" ] || die "DEPLOY_TARGETS_JSON is missing in $ENV_FILE"
json_payload="${json_line#DEPLOY_TARGETS_JSON=}"

python3 - "$json_payload" <<'PY'
import json
import sys

raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception as exc:
    raise SystemExit(f"DEPLOY_TARGETS_JSON invalid JSON: {exc}")

if not isinstance(data, dict) or not data:
    raise SystemExit("DEPLOY_TARGETS_JSON must be a non-empty object")

required_keys = {
    "iterlife-reunion",
    "iterlife-reunion-ui",
    "iterlife-expenses",
    "iterlife-expenses-ui",
}

for key, value in data.items():
    if not isinstance(key, str) or not key.strip():
        raise SystemExit("service key must be non-empty string")
    if not isinstance(value, dict):
        raise SystemExit(f"service '{key}' must map to object config")

    deploy_script = str(value.get("deploy_script", "")).strip()
    image_env = str(value.get("image_env", "")).strip()
    if not deploy_script:
        raise SystemExit(f"service '{key}' missing deploy_script")
    if not deploy_script.startswith("/apps/"):
        raise SystemExit(
            f"service '{key}' deploy_script must be absolute /apps path: {deploy_script}"
        )
    if not image_env:
        raise SystemExit(f"service '{key}' missing image_env")

missing = sorted(required_keys - set(data.keys()))
if missing:
    raise SystemExit(f"missing standard service keys: {', '.join(missing)}")

print(
    "ok: DEPLOY_TARGETS_JSON parsed with services="
    + ",".join(sorted(data.keys()))
)
PY

echo "[validate-webhook-config] success: $ENV_FILE"
