from types import SimpleNamespace

from fastapi.testclient import TestClient

import app.main as main


class _FakeOllamaResponse:
    def raise_for_status(self):
        return None

    def json(self):
        return {"message": {"content": "NIKO test reply"}}


class _FakeAsyncClient:
    def __init__(self, *args, **kwargs):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def post(self, *args, **kwargs):
        return _FakeOllamaResponse()


def _image_result(content=b"fake-image"):
    return SimpleNamespace(
        content=content,
        mime_type="image/png",
        model="test-image-model",
    )


class _FakeImageProvider:
    def __init__(self, *args, **kwargs):
        pass

    async def generate(self, **kwargs):
        return _image_result()

    async def edit(self, **kwargs):
        return _image_result(b"edited-image")


def test_chat_currently_accepts_request_without_authentication(monkeypatch):
    monkeypatch.setattr(main.httpx, "AsyncClient", _FakeAsyncClient)
    response = TestClient(main.app).post(
        "/v1/chat",
        json={"message": "Hello NIKO", "language": "english"},
    )
    assert response.status_code == 200
    assert response.json()["reply"] == "NIKO test reply"


def test_document_generation_currently_accepts_request_without_authentication(monkeypatch):
    monkeypatch.setattr(
        main,
        "generate_document",
        lambda **kwargs: (b"fake-document", "text/plain", "niko.txt"),
    )
    response = TestClient(main.app).post(
        "/v1/documents",
        json={"format": "txt", "title": "Test document", "content": "private draft"},
    )
    assert response.status_code == 200
    assert response.content == b"fake-document"


def test_image_generation_currently_accepts_request_without_authentication(monkeypatch):
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    response = TestClient(main.app).post(
        "/v1/images/generations",
        data={"prompt": "A simple test image", "size": "1024x1024", "quality": "low"},
    )
    assert response.status_code == 200
    assert response.content == b"fake-image"


def test_image_edit_currently_accepts_request_without_authentication(monkeypatch):
    monkeypatch.setattr(main, "OpenAIImageProvider", _FakeImageProvider)
    response = TestClient(main.app).post(
        "/v1/images/edits",
        data={"prompt": "Edit this test image", "size": "1024x1024", "quality": "low"},
        files={"image": ("source.png", b"source-image", "image/png")},
    )
    assert response.status_code == 200
    assert response.content == b"edited-image"


def test_session_endpoint_rejects_request_without_authentication():
    response = TestClient(main.app).get("/v1/session")
    assert response.status_code == 401
