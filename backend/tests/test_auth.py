import time

import jwt
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.auth import AuthenticatedPrincipal, verify_access_token


def make_app():
    app = FastAPI()

    @app.get("/protected")
    def protected(
        principal: AuthenticatedPrincipal = Depends(verify_access_token),
    ):
        return {"issuer": principal.issuer, "subject": principal.subject}

    return app


def token(secret="test-secret", issuer="https://issuer.example", subject="user-a"):
    now = int(time.time())
    return jwt.encode(
        {"sub": subject, "iss": issuer, "iat": now, "exp": now + 60},
        secret,
        algorithm="HS256",
    )


def test_missing_token_is_rejected(monkeypatch):
    monkeypatch.setenv("NIKO_AUTH_JWT_SECRET", "test-secret")
    monkeypatch.setenv("NIKO_AUTH_ISSUER", "https://issuer.example")
    response = TestClient(make_app()).get("/protected")
    assert response.status_code == 401


def test_invalid_signature_is_rejected(monkeypatch):
    monkeypatch.setenv("NIKO_AUTH_JWT_SECRET", "test-secret")
    monkeypatch.setenv("NIKO_AUTH_ISSUER", "https://issuer.example")
    response = TestClient(make_app()).get(
        "/protected",
        headers={"Authorization": f"Bearer {token(secret='other-secret')}"},
    )
    assert response.status_code == 401


def test_valid_token_identity_is_derived_from_verified_claims(monkeypatch):
    monkeypatch.setenv("NIKO_AUTH_JWT_SECRET", "test-secret")
    monkeypatch.setenv("NIKO_AUTH_ISSUER", "https://issuer.example")
    response = TestClient(make_app()).get(
        "/protected",
        headers={"Authorization": f"Bearer {token(subject='user-a')}"},
    )
    assert response.status_code == 200
    assert response.json() == {"issuer": "https://issuer.example", "subject": "user-a"}


def test_unconfigured_server_fails_closed():
    response = TestClient(make_app()).get(
        "/protected",
        headers={"Authorization": f"Bearer {token()}"},
    )
    assert response.status_code == 503
