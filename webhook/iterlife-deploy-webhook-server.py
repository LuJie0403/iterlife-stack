#!/usr/bin/env python3
"""Webhook receiver for IterLife multi-app production deployment.

This service accepts signed webhook callbacks and triggers image-based
deployment on Aliyun.
"""

import hashlib
import hmac
import json
import os
import subprocess
import threading
import time
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from pathlib import Path
try:
    # Python 3.7+
    from http.server import ThreadingHTTPServer  # type: ignore
except ImportError:
    # Python 3.6 fallback
    from http.server import HTTPServer
    from socketserver import ThreadingMixIn

    class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
        daemon_threads = True
from typing import Dict, Optional, Tuple


BIND_HOST = os.getenv("WEBHOOK_BIND_HOST", "127.0.0.1")
BIND_PORT = int(os.getenv("WEBHOOK_BIND_PORT", "19091"))
WEBHOOK_PATH = os.getenv("WEBHOOK_PATH", "/hooks/app-deploy")
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "")
DEPLOY_TIMEOUT_SECONDS = int(os.getenv("DEPLOY_TIMEOUT_SECONDS", "1800"))
LEGACY_LOG_FILE = os.getenv("WEBHOOK_LOG_FILE", "").strip()
LOG_DIR = Path(
    os.getenv(
        "WEBHOOK_LOG_DIR",
        Path(LEGACY_LOG_FILE).parent.as_posix()
        if LEGACY_LOG_FILE
        else "/apps/logs/webhook",
    )
)
LOG_FILE_PREFIX = os.getenv(
    "WEBHOOK_LOG_FILE_PREFIX",
    Path(LEGACY_LOG_FILE).stem if LEGACY_LOG_FILE else "iterlife-deploy-webhook",
).strip() or "iterlife-deploy-webhook"
LEGACY_DEPLOY_SCRIPT = os.getenv(
    "DEPLOY_SCRIPT",
    "/apps/iterlife-reunion/deploy/scripts/deploy-reunion-from-ghcr.sh",
)
DEPLOY_TARGETS_JSON = os.getenv("DEPLOY_TARGETS_JSON", "")


def load_deploy_targets() -> Dict[str, Dict[str, str]]:
    # Backward-compatible default route.
    # Service without suffix means API deployment.
    default_targets = {
        "iterlife-reunion": {
            "deploy_script": LEGACY_DEPLOY_SCRIPT,
            "image_env": "API_IMAGE_REF",
        }
    }
    if not DEPLOY_TARGETS_JSON.strip():
        return default_targets

    try:
        data = json.loads(DEPLOY_TARGETS_JSON)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"DEPLOY_TARGETS_JSON is invalid JSON: {exc}") from exc

    if not isinstance(data, dict) or not data:
        raise SystemExit("DEPLOY_TARGETS_JSON must be a non-empty object")

    normalized: Dict[str, Dict[str, str]] = {}
    for service_name, config in data.items():
        if not isinstance(service_name, str) or not service_name.strip():
            raise SystemExit("DEPLOY_TARGETS_JSON contains invalid service name")
        if not isinstance(config, dict):
            raise SystemExit(f"Service config must be object: {service_name}")

        deploy_script = str(config.get("deploy_script", "")).strip()
        image_env = str(config.get("image_env", "API_IMAGE_REF")).strip()
        if not deploy_script:
            raise SystemExit(f"deploy_script is required for service: {service_name}")
        if not image_env:
            raise SystemExit(f"image_env is required for service: {service_name}")

        normalized[service_name.strip()] = {
            "deploy_script": deploy_script,
            "image_env": image_env,
        }
    return normalized


DEPLOY_TARGETS = load_deploy_targets()
SERVICE_STATE_LOCK = threading.Lock()
SERVICE_STATE = {}  # type: Dict[str, Dict[str, object]]


def resolve_log_file_path(now: Optional[datetime] = None) -> Path:
    current = now or datetime.now().astimezone()
    return LOG_DIR / f"{LOG_FILE_PREFIX}-{current.strftime('%Y-%m-%d')}.log"


def ensure_log_destination(now: Optional[datetime] = None) -> Path:
    log_file = resolve_log_file_path(now)
    log_file.parent.mkdir(mode=0o2775, parents=True, exist_ok=True)
    if not log_file.exists():
        log_file.touch(mode=0o664)
    else:
        os.chmod(log_file, 0o664)
    return log_file


def write_log(message: str) -> None:
    current = datetime.now().astimezone()
    timestamp = current.isoformat(timespec="seconds")
    line = f"{timestamp} {message}\n"
    log_file = ensure_log_destination(current)
    with open(log_file, "a", encoding="utf-8") as fp:
        fp.write(line)


def verify_signature(payload: bytes, signature_header: str, secret: str) -> bool:
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    expected = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
    provided = signature_header.split("=", 1)[1].strip()
    return hmac.compare_digest(expected, provided)


def resolve_service_key(service: str) -> str:
    service = service.strip()
    if not service:
        return ""
    if service in DEPLOY_TARGETS:
        return service
    # Compatibility: payload may use "*-api", while route table key uses no suffix.
    if service.endswith("-api"):
        base = service[:-4]
        if base in DEPLOY_TARGETS:
            return base
    # Compatibility: route table key may use "*-api", while payload uses no suffix.
    api_key = service + "-api"
    if api_key in DEPLOY_TARGETS:
        return api_key
    return ""


def validate_payload(payload: dict) -> Tuple[bool, str, str]:
    service = (payload.get("service") or "").strip()
    image_ref = (payload.get("image_ref") or "").strip()
    if not service:
        return False, "payload.service is required", ""
    resolved_service = resolve_service_key(service)
    if not resolved_service:
        return False, f"unsupported service: {service}", ""
    if not image_ref:
        return False, "payload.image_ref is required", ""
    return True, "", resolved_service


def run_deploy(payload: dict, resolved_service: str) -> Tuple[int, str]:
    request_service = (payload.get("service") or "").strip()
    service = resolved_service
    target = DEPLOY_TARGETS.get(resolved_service)
    if target is None:
        return 1, f"unsupported service: {request_service}"

    deploy_script = target["deploy_script"]
    image_env_name = target["image_env"]

    image_ref = (payload.get("image_ref") or "").strip()

    dry_run = bool(payload.get("dry_run", False))
    release_commit_sha = (payload.get("commit_sha") or "").strip()
    release_digest = (payload.get("image_digest") or "").strip()

    if dry_run:
        return 0, f"[dry-run] accepted service={service} image_ref={image_ref}"

    env = os.environ.copy()
    env[image_env_name] = image_ref
    env["DEPLOY_TARGET_SERVICE"] = resolved_service
    env["DEPLOY_REQUEST_SERVICE"] = request_service
    if release_commit_sha:
        env["RELEASE_COMMIT_SHA"] = release_commit_sha
    if release_digest:
        env["RELEASE_IMAGE_DIGEST"] = release_digest

    if not os.path.exists(deploy_script):
        return 1, f"deploy script not found for service={service}: {deploy_script}"

    start = time.time()
    proc = subprocess.run(
        [deploy_script],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        timeout=DEPLOY_TIMEOUT_SECONDS,
        check=False,
    )
    cost_ms = int((time.time() - start) * 1000)
    output = (proc.stdout or "") + (proc.stderr or "")
    summary = (
        f"service={service} request_service={request_service} script={deploy_script} "
        f"exit={proc.returncode} cost_ms={cost_ms}\n{output}"
    )
    return proc.returncode, summary


def enqueue_latest_deploy(payload: dict, resolved_service: str) -> str:
    with SERVICE_STATE_LOCK:
        state = SERVICE_STATE.setdefault(
            resolved_service,
            {"running": False, "pending": None},
        )
        was_running = bool(state["running"])
        replaced_existing_pending = state["pending"] is not None
        state["pending"] = payload
        if not was_running:
            state["running"] = True
            worker = threading.Thread(
                target=deploy_worker,
                args=(resolved_service,),
                daemon=True,
            )
            worker.start()
            return "started"
    if replaced_existing_pending:
        return "queued_replaced"
    return "queued"


def deploy_worker(resolved_service: str) -> None:
    while True:
        with SERVICE_STATE_LOCK:
            state = SERVICE_STATE.setdefault(
                resolved_service,
                {"running": True, "pending": None},
            )
            payload = state["pending"]
            state["pending"] = None

        if payload is None:
            with SERVICE_STATE_LOCK:
                state = SERVICE_STATE.setdefault(
                    resolved_service,
                    {"running": True, "pending": None},
                )
                state["running"] = False
            return

        try:
            code, output = run_deploy(payload, resolved_service=resolved_service)
            service = payload.get("service", "")
            image_ref = payload.get("image_ref", "")
            if code == 0:
                write_log(
                    "deploy success: service=%s resolved_service=%s image_ref=%s"
                    % (service, resolved_service, image_ref)
                )
            else:
                write_log(
                    "deploy failed: service=%s resolved_service=%s detail=%s"
                    % (service, resolved_service, output[-2000:])
                )
        except Exception as exc:  # pragma: no cover
            write_log(
                "deploy exception: service=%s resolved_service=%s error=%s"
                % (payload.get("service", ""), resolved_service, str(exc))
            )


class DeployWebhookHandler(BaseHTTPRequestHandler):
    server_version = "IterLifeAppDeployWebhook/1.0"

    def _write_json(self, status: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802
        if self.path != WEBHOOK_PATH:
            self._write_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "not found"})
            return

        if not WEBHOOK_SECRET:
            self._write_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"ok": False, "error": "server secret not configured"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        payload = self.rfile.read(content_length)
        signature = self.headers.get("X-Hub-Signature-256") or self.headers.get("X-Signature-256") or ""

        if not verify_signature(payload, signature, WEBHOOK_SECRET):
            write_log("reject request: invalid signature")
            self._write_json(HTTPStatus.UNAUTHORIZED, {"ok": False, "error": "invalid signature"})
            return

        try:
            data = json.loads(payload.decode("utf-8"))
        except json.JSONDecodeError:
            self._write_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": "invalid json"})
            return

        ok, err, resolved_service = validate_payload(data)
        if not ok:
            self._write_json(HTTPStatus.BAD_REQUEST, {"ok": False, "error": err})
            return

        if bool(data.get("dry_run", False)):
            code, output = run_deploy(data, resolved_service=resolved_service)
            if code == 0:
                self._write_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "message": "dry-run accepted",
                        "service": data.get("service", ""),
                        "resolved_service": resolved_service,
                        "image_ref": data.get("image_ref", ""),
                    },
                )
                return
            self._write_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"ok": False, "error": "dry-run failed", "detail": output[-2000:]},
            )
            return

        queue_status = enqueue_latest_deploy(data, resolved_service=resolved_service)
        if queue_status == "started":
            self._write_json(
                HTTPStatus.ACCEPTED,
                {
                    "ok": True,
                    "message": "deploy accepted and started",
                    "service": data.get("service", ""),
                    "resolved_service": resolved_service,
                    "image_ref": data.get("image_ref", ""),
                },
            )
            return

        self._write_json(
            HTTPStatus.ACCEPTED,
            {
                "ok": True,
                "message": "deploy accepted and queued as latest",
                "queue_status": queue_status,
                "service": data.get("service", ""),
                "resolved_service": resolved_service,
                "image_ref": data.get("image_ref", ""),
            },
        )

    def log_message(self, fmt: str, *args) -> None:
        # Redirect default HTTP server logs into unified log file.
        write_log("http " + fmt % args)


def main() -> None:
    if not WEBHOOK_SECRET:
        raise SystemExit("WEBHOOK_SECRET is required")
    startup_log_file = ensure_log_destination()
    for service_name, target in DEPLOY_TARGETS.items():
        script = target["deploy_script"]
        if not os.path.exists(script):
            raise SystemExit(f"deploy script not found for {service_name}: {script}")
        if not os.access(script, os.X_OK):
            raise SystemExit(f"deploy script is not executable for {service_name}: {script}")

    httpd = ThreadingHTTPServer((BIND_HOST, BIND_PORT), DeployWebhookHandler)
    services = ",".join(sorted(DEPLOY_TARGETS.keys()))
    write_log(
        "start webhook server at http://%s:%s%s services=%s log_file=%s"
        % (BIND_HOST, BIND_PORT, WEBHOOK_PATH, services, startup_log_file)
    )
    httpd.serve_forever()


if __name__ == "__main__":
    main()
