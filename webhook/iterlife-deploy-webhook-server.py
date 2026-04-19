#!/usr/local/bin/python3.11
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


ROOT_DIR = Path(__file__).resolve().parents[1]
BIND_HOST = os.getenv("WEBHOOK_BIND_HOST", "127.0.0.1")
BIND_PORT = int(os.getenv("WEBHOOK_BIND_PORT", "19091"))
WEBHOOK_PATH = os.getenv("WEBHOOK_PATH", "/hooks/app-deploy")
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "")
DEPLOY_TIMEOUT_SECONDS = int(os.getenv("DEPLOY_TIMEOUT_SECONDS", "1800"))
DEFAULT_DEPLOY_TARGETS_FILE = ROOT_DIR / "config" / "deploy-targets.json"
DEFAULT_DEPLOY_EXECUTOR_SCRIPT = ROOT_DIR / "scripts" / "deploy-service-from-ghcr.sh"
DEPLOY_TARGETS_FILE = Path(
    os.getenv("DEPLOY_TARGETS_FILE", DEFAULT_DEPLOY_TARGETS_FILE.as_posix())
).expanduser()
DEPLOY_EXECUTOR_SCRIPT = Path(
    os.getenv("DEPLOY_EXECUTOR_SCRIPT", DEFAULT_DEPLOY_EXECUTOR_SCRIPT.as_posix())
).expanduser()
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


def load_deploy_targets() -> Dict[str, Dict[str, str]]:
    try:
        raw_payload = DEPLOY_TARGETS_FILE.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(
            f"DEPLOY_TARGETS_FILE cannot be read: {DEPLOY_TARGETS_FILE} ({exc})"
        ) from exc

    try:
        data = json.loads(raw_payload)
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"DEPLOY_TARGETS_FILE is invalid JSON: {DEPLOY_TARGETS_FILE} ({exc})"
        ) from exc

    if not isinstance(data, dict) or not data:
        raise SystemExit("DEPLOY_TARGETS_FILE must contain a non-empty object")

    normalized: Dict[str, Dict[str, str]] = {}
    for service_name, config in data.items():
        if not isinstance(service_name, str) or not service_name.strip():
            raise SystemExit("DEPLOY_TARGETS_FILE contains invalid service name")
        if not isinstance(config, dict):
            raise SystemExit(f"Service config must be object: {service_name}")

        required_fields = [
            "compose_file",
            "compose_project_directory",
            "compose_service",
            "release_image_env",
            "runtime_image_env",
            "runtime_image_name",
            "deployment_state_file",
            "healthcheck_url",
        ]
        normalized_entry: Dict[str, str] = {}
        for field_name in required_fields:
            value = str(config.get(field_name, "")).strip()
            if not value:
                raise SystemExit(
                    f"{field_name} is required for service: {service_name}"
                )
            normalized_entry[field_name] = value

        compose_no_deps = config.get("compose_no_deps", False)
        if not isinstance(compose_no_deps, bool):
            raise SystemExit(
                f"compose_no_deps must be boolean for service: {service_name}"
            )
        normalized_entry["compose_no_deps"] = "true" if compose_no_deps else "false"
        normalized[service_name.strip()] = normalized_entry
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
    return service if service in DEPLOY_TARGETS else ""


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

    image_ref = (payload.get("image_ref") or "").strip()

    dry_run = bool(payload.get("dry_run", False))
    release_commit_sha = (payload.get("commit_sha") or "").strip()
    release_digest = (payload.get("image_digest") or "").strip()

    if dry_run:
        return 0, f"[dry-run] accepted service={service} image_ref={image_ref}"

    env = os.environ.copy()
    env[target["release_image_env"]] = image_ref
    env[target["runtime_image_env"]] = target["runtime_image_name"]
    env["DEPLOY_TARGET_SERVICE"] = resolved_service
    env["DEPLOY_REQUEST_SERVICE"] = request_service
    env["RELEASE_IMAGE_REF"] = image_ref
    env["DEPLOY_TARGETS_FILE"] = DEPLOY_TARGETS_FILE.as_posix()
    repository = (payload.get("repository") or "").strip()
    if repository:
        env["RELEASE_REPOSITORY"] = repository
    if release_commit_sha:
        env["RELEASE_COMMIT_SHA"] = release_commit_sha
    if release_digest:
        env["RELEASE_IMAGE_DIGEST"] = release_digest

    if not DEPLOY_EXECUTOR_SCRIPT.exists():
        return 1, f"deploy executor not found: {DEPLOY_EXECUTOR_SCRIPT}"

    start = time.time()
    proc = subprocess.run(
        [DEPLOY_EXECUTOR_SCRIPT.as_posix()],
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
        f"service={service} request_service={request_service} "
        f"executor={DEPLOY_EXECUTOR_SCRIPT} "
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
    if not DEPLOY_EXECUTOR_SCRIPT.exists():
        raise SystemExit(f"deploy executor not found: {DEPLOY_EXECUTOR_SCRIPT}")
    if not os.access(DEPLOY_EXECUTOR_SCRIPT, os.X_OK):
        raise SystemExit(
            f"deploy executor is not executable: {DEPLOY_EXECUTOR_SCRIPT}"
        )

    httpd = ThreadingHTTPServer((BIND_HOST, BIND_PORT), DeployWebhookHandler)
    services = ",".join(sorted(DEPLOY_TARGETS.keys()))
    write_log(
        "start webhook server at http://%s:%s%s services=%s log_file=%s deploy_targets_file=%s executor=%s"
        % (
            BIND_HOST,
            BIND_PORT,
            WEBHOOK_PATH,
            services,
            startup_log_file,
            DEPLOY_TARGETS_FILE,
            DEPLOY_EXECUTOR_SCRIPT,
        )
    )
    httpd.serve_forever()


if __name__ == "__main__":
    main()
