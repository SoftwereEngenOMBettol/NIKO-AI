import time
from types import SimpleNamespace

import jwt
import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.provider_policy import ProviderPolicy, ProviderPolicyGuard


TEST_SECRET = "niko-test-secret-with-at-least-32-bytes"
TEST_ISSUER = "https://issuer.example"


class _FakeOllamaResponse:
    def raise_for_status(self):
        return None

    def json(self):
        return {"message": {"content": "NIKO test reply"}}


class _FakeAsyncClient:
    calls = 0

    def __init__(self, *args, **kwargs):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def post(self, *args, **kwargs):
        type(self).calls += 1
        return _FakeOllamaResponse()


def _auth_headers(monkeypatch, subject="user-a"):
    monkeypatch.setenv("NIKO_AUTH_JWT_SECRET", TEST_SECRET)
    monkeypatch.setenv("NIKO_AUTH_ISSUER", TEST_ISSUER)
    now = int(time.time())
    token = jwt.encode(
        {
            "sub": subject,
            "iss": TEST_ISSUER,
            "iat": now,
            "exp": now + 300,
        },
        TEST_SECRET,
        algorithm="HS256",
    )
    return {"Authorization": f"Bearer {token}"}


def _image_result(content=b"fake-image"):
    return SimpleNamespace(
        content=content,
        mime_type="image/png",
        model="test-image-model",
    )


class _FakeImageProvider:
    calls = 0

    def __init__(self, *args, **kwargs):
        pass

    async def generate(self, **kwargs):
        type(self).calls += 1
        return _image_result()

    async def edit(self, **kwargs):
        type(self).calls += 1
        return _image_result(b"edited-image")


def test_chat_rejects_missing_authentication_before_ollama(monkeypatch):
    _FakeAsyncClient.calls = 0
    monkeypatch.setattr(main.httpx, "AsyncClient", _FakeAsyncClient)
    response = TestClient(main.app).post(
        "/v1/chat",
        json={"message": "Hello NIKO", "language": "english"},
    )
    assert response.status_code == 401
    assert _FakeAsyncClient.calls == 0


def test_chat_accepts_valid_authentication(monkeypatch):
    monkeypatch.setattr(main.httpx, "AsyncClient", _FakeAsyncClient)
    response = TestClient(main.app).post(
        "/v1/chat",
        headers=_auth_headers(monkeypatch),
        json={"message": "Hello NIKO", "language": "english"},
    )
    assert response.status_code == 200
    assert response.json()["reply"] == "NIKO test reply"


def test_document_generation_rejects_missing_authentication_before_generation(monkeypatch):
    def unexpected_generation(**kwargs):
        pytest.fail("Document generation must not run without authentication.")

    monkeypatch.setattr(main, "generate_document", unexpected_generation)
    response = TestClient(main.app).post(
        "/v1/documents",
        json={"format": "txt", "title": "Test document", "content": "private draft"},
    )
    assert response.status_code == 401


def test_document_generation_accepts_valid_authentication(monkeypatch):
    monkeypatch.setattr(
        main,
        "generate_document",
        lambda **kwargs: (b"fake-document", "text/plain", "niko.txt"),
    )
    response = TestClient(main.app).post(
        "/v1/documents",
        headers=_auth_headers(monkeypatch),
        json={"format": "txt", "title": "Test document", "content": "private draft"},
    )
    assert response.status_code == 200
    assert response.content == b"fake-document"


def test_image_generation_rejects_missing_authentication_before_provider(monkeypatch):
    _FakeImageProvider.calls = 0
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    response = TestClient(main.app).post(
        "/v1/images/generations",
        data={"prompt": "A simple test image", "size": "1024x1024", "quality": "low"},
    )
    assert response.status_code == 401
    assert _FakeImageProvider.calls == 0


def test_image_generation_is_disabled_by_default_policy(monkeypatch):
    _FakeImageProvider.calls = 0
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    monkeypatch.setattr(
        main,
        "IMAGE_PROVIDER_GUARD",
        ProviderPolicyGuard({"openai_images": ProviderPolicy(enabled=False)}),
    )
    response = TestClient(main.app).post(
        "/v1/images/generations",
        headers=_auth_headers(monkeypatch),
        data={"prompt": "A simple test image", "size": "1024x1024", "quality": "low"},
    )
    assert response.status_code == 503
    assert _FakeImageProvider.calls == 0


def test_image_generation_accepts_valid_authentication(monkeypatch):
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    monkeypatch.setattr(
        main,
        "IMAGE_PROVIDER_GUARD",
        ProviderPolicyGuard({"openai_images": ProviderPolicy(enabled=True)}),
    )
    response = TestClient(main.app).post(
        "/v1/images/generations",
        headers=_auth_headers(monkeypatch),
        data={"prompt": "A simple test image", "size": "1024x1024", "quality": "low"},
    )
    assert response.status_code == 200
    assert response.content == b"fake-image"


def test_image_edit_rejects_missing_authentication_before_provider(monkeypatch):
    _FakeImageProvider.calls = 0
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    response = TestClient(main.app).post(
        "/v1/images/edits",
        data={"prompt": "Edit this test image", "size": "1024x1024", "quality": "low"},
        files={"image": ("source.png", b"source-image", "image/png")},
    )
    assert response.status_code == 401
    assert _FakeImageProvider.calls == 0


def test_image_edit_accepts_valid_authentication(monkeypatch):
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    monkeypatch.setattr(
        main,
        "IMAGE_PROVIDER_GUARD",
        ProviderPolicyGuard({"openai_images": ProviderPolicy(enabled=True)}),
    )
    response = TestClient(main.app).post(
        "/v1/images/edits",
        headers=_auth_headers(monkeypatch),
        data={"prompt": "Edit this test image", "size": "1024x1024", "quality": "low"},
        files={"image": ("source.png", b"source-image", "image/png")},
    )
    assert response.status_code == 200
    assert response.content == b"edited-image"


def test_session_endpoint_rejects_request_without_authentication():
    response = TestClient(main.app).get("/v1/session")
    assert response.status_code == 401
