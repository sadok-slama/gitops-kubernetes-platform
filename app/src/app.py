"""Sample web application used by the GitOps Kubernetes Platform project.

Endpoints:
    /         HTML homepage identifying the application and the project
    /health   Liveness/readiness endpoint (JSON), used by Kubernetes probes
    /version  Version information (JSON): app version, git commit, environment
    /metrics  Prometheus metrics (text exposition format)
"""
import os
import time
from html import escape

from flask import Flask, Response, g, jsonify, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Histogram,
    generate_latest,
)

PROJECT_NAME = "GitOps Kubernetes Platform"
APP_NAME = "sample-app"


def create_app() -> Flask:
    """Application factory: builds a fresh Flask app and its own metrics registry."""
    app = Flask(__name__)

    # Configuration comes from environment variables (set by the Helm chart).
    app.config["APP_VERSION"] = os.getenv("APP_VERSION", "dev")
    app.config["GIT_SHA"] = os.getenv("GIT_SHA", "unknown")
    app.config["APP_ENVIRONMENT"] = os.getenv("APP_ENVIRONMENT", "local")
    app.config["APP_MESSAGE"] = os.getenv("APP_MESSAGE", "Deployed with GitOps")

    # A dedicated registry keeps tests independent from each other.
    registry = CollectorRegistry()
    requests_total = Counter(
        "sample_app_http_requests_total",
        "Total HTTP requests handled by the application.",
        ["method", "path", "status"],
        registry=registry,
    )
    request_duration = Histogram(
        "sample_app_http_request_duration_seconds",
        "HTTP request latency in seconds.",
        ["path"],
        registry=registry,
    )

    # Only known paths are used as label values to avoid unbounded cardinality.
    known_paths = {"/", "/health", "/version", "/metrics"}

    @app.before_request
    def start_timer() -> None:
        g.start_time = time.perf_counter()

    @app.after_request
    def record_metrics(response: Response) -> Response:
        path = request.path if request.path in known_paths else "other"
        elapsed = time.perf_counter() - g.get("start_time", time.perf_counter())
        requests_total.labels(request.method, path, str(response.status_code)).inc()
        request_duration.labels(path).observe(elapsed)
        return response

    @app.get("/")
    def index() -> str:
        cfg = app.config
        return f"""<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>{escape(PROJECT_NAME)}</title></head>
<body style="font-family: sans-serif; max-width: 40rem; margin: 3rem auto;">
  <h1>{escape(PROJECT_NAME)}</h1>
  <p>Application: <strong>{escape(APP_NAME)}</strong></p>
  <p>{escape(cfg["APP_MESSAGE"])}</p>
  <ul>
    <li>Environment: {escape(cfg["APP_ENVIRONMENT"])}</li>
    <li>Version: {escape(cfg["APP_VERSION"])}</li>
    <li>Commit: {escape(cfg["GIT_SHA"])}</li>
  </ul>
  <p>Try <a href="/health">/health</a>, <a href="/version">/version</a>
     and <a href="/metrics">/metrics</a>.</p>
</body>
</html>"""

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/version")
    def version():
        cfg = app.config
        return jsonify(
            application=APP_NAME,
            project=PROJECT_NAME,
            version=cfg["APP_VERSION"],
            commit=cfg["GIT_SHA"],
            environment=cfg["APP_ENVIRONMENT"],
        )

    @app.get("/metrics")
    def metrics() -> Response:
        return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)

    return app


# Module-level object used by gunicorn: `gunicorn app:app`
app = create_app()

if __name__ == "__main__":  # Local development only: python src/app.py
    app.run(host="127.0.0.1", port=int(os.getenv("PORT", "8080")))
