import base64
import json

import httpx
import pytest

from app.image_provider import ImageProviderError, OpenAIImageProvider


@pytest.mark.asyncio
async def test_generate_sends_high_quality_and_returns_image_bytes():
    png = b"\x89PNG\r\n\x1a\nexample"

    def handler(request):
        payload = json.loads(request.content)
        assert request.url.path.endswith("/images/generations")
        assert payload["quality"] == "high"
        assert payload["model"] == "gpt-image-1"
        return httpx.Response(200, json={"data": [{"b64_json": base64.b64encode(png).decode()}]})

    provider = OpenAIImageProvider(
        api_key="test-key",
        transport=httpx.MockTransport(handler),
    )
    result = await provider.generate(prompt="A cinematic Omani mountain landscape")
    assert result.content == png
    assert result.mime_type == "image/png"


@pytest.mark.asyncio
async def test_missing_api_key_fails_without_network_call():
    provider = OpenAIImageProvider(api_key="")
    with pytest.raises(ImageProviderError, match="NIKO_IMAGE_API_KEY"):
        await provider.generate(prompt="A test image")


@pytest.mark.asyncio
async def test_edit_sends_uploaded_image_as_multipart():
    source = b"source-image"
    output = b"edited-image"

    def handler(request):
        body = request.content
        assert request.url.path.endswith("/images/edits")
        assert b'name="image"; filename="source.png"' in body
        assert b"source-image" in body
        assert b"quality" in body and b"high" in body
        return httpx.Response(200, json={"data": [{"b64_json": base64.b64encode(output).decode()}]})

    provider = OpenAIImageProvider(api_key="test-key", transport=httpx.MockTransport(handler))
    result = await provider.edit(prompt="Remove background", image_bytes=source)
    assert result.content == output


@pytest.mark.asyncio
async def test_provider_rate_limit_has_clear_error():
    def handler(request):
        return httpx.Response(429, json={"error": {"message": "quota"}})

    provider = OpenAIImageProvider(api_key="test-key", transport=httpx.MockTransport(handler))
    with pytest.raises(ImageProviderError, match="quota"):
        await provider.generate(prompt="A test")
