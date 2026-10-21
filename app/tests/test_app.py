"""Unit tests for the sample application (run with `pytest` from the app/ directory)."""
import pytest

from app import create_app


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("GIT_SHA", "abc1234")
    monkeypatch.setenv("APP_ENVIRONMENT", "test")
    return create_app().test_client()


def test_homepage_identifies_project_and_app(client):
    response = client.get("/")
    assert response.status_code == 200
    body = response.get_data(as_text=True)
    assert "GitOps Kubernetes Platform" in body
    assert "sample-app" in body


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_version_endpoint_uses_environment(client):
    data = client.get("/version").get_json()
    assert data["version"] == "1.2.3"
    assert data["commit"] == "abc1234"
    assert data["environment"] == "test"
    assert data["application"] == "sample-app"


def test_version_defaults_without_environment(monkeypatch):
    for name in ("APP_VERSION", "GIT_SHA", "APP_ENVIRONMENT"):
        monkeypatch.delenv(name, raising=False)
    data = create_app().test_client().get("/version").get_json()
    assert data["version"] == "dev"
    assert data["commit"] == "unknown"


def test_homepage_escapes_html_in_configuration(monkeypatch):
    monkeypatch.setenv("APP_MESSAGE", "<script>alert(1)</script>")
    body = create_app().test_client().get("/").get_data(as_text=True)
    assert "<script>alert(1)</script>" not in body
    assert "&lt;script&gt;" in body


def test_unknown_route_returns_404(client):
    assert client.get("/does-not-exist").status_code == 404


def test_metrics_endpoint_counts_requests(client):
    client.get("/health")
    client.get("/health")
    body = client.get("/metrics").get_data(as_text=True)
    assert 'sample_app_http_requests_total{method="GET",path="/health",status="200"} 2.0' in body
    assert "sample_app_http_request_duration_seconds_bucket" in body


def test_metrics_do_not_create_labels_for_unknown_paths(client):
    client.get("/random-path-1")
    client.get("/random-path-2")
    body = client.get("/metrics").get_data(as_text=True)
    assert 'path="other"' in body
    assert "random-path" not in body
