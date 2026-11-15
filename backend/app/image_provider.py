"""OpenAI Images API adapter for high-quality NIKO image generation and edits.

The provider is opt-in. No API key means no image generation. The key is read only
from the backend environment and must never be shipped to Flutter or committed.
"""
from __future__ import annotations

import base64
import os
from dataclasses import dataclass

import httpx


@dataclass(frozen=True)
class ImageResult:
    content: bytes
    revised_prompt: str | None
    model: str
    mime_type: str = "image/png"


class ImageProviderError(RuntimeError):
    pass


class OpenAIImageProvider:
    def __init__(
        self,
        *,
        api_key: str | None = None,
        model: str | None = None,
        base_url: str | None = None,
        timeout: float = 180.0,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.api_key = (api_key if api_key is not None else os.getenv("NIKO_IMAGE_API_KEY", "")).strip()
        self.model = (model or os.getenv("NIKO_IMAGE_MODEL", "gpt-image-1")).strip()
        self.base_url = (base_url or os.getenv("NIKO_IMAGE_API_BASE_URL", "https://api.openai.com/v1")).rstrip("/")
        self.timeout = timeout
        self.transport = transport

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    async def _request(self, *, endpoint: str, data: dict, files=None) -> ImageResult:
        if not self.configured:
            raise ImageProviderError("Image generation is not configured. Set NIKO_IMAGE_API_KEY on the backend.")
        headers = {"Authorization": f"Bearer {self.api_key}"}
        try:
            async with httpx.AsyncClient(timeout=self.timeout, transport=self.transport) as client:
                response = await client.post(
                    f"{self.base_url}{endpoint}",
                    headers=headers,
                    data=data if files else None,
                    json=data if not files else None,
                    files=files,
                )
            response.raise_for_status()
            payload = response.json()
            item = payload["data"][0]
            encoded = item.get("b64_json")
            if not encoded:
                raise ImageProviderError("The image provider returned no base64 image data.")
            return ImageResult(
                content=base64.b64decode(encoded, validate=True),
                revised_prompt=item.get("revised_prompt"),
                model=self.model,
            )
        except ImageProviderError:
            raise
        except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError) as exc:
            status = getattr(getattr(exc, "response", None), "status_code", None)
            if status in (401, 403):
                message = "The image provider rejected its credentials or permissions."
            elif status == 429:
                message = "The image provider rate limit or account quota was reached."
            else:
                message = "The image provider request failed. Check provider availability and backend logs."
            raise ImageProviderError(message) from exc

    async def generate(
        self, *, prompt: str, size: str = "1024x1024", quality: str = "high"
    ) -> ImageResult:
        return await self._request(
            endpoint="/images/generations",
            data={
                "model": self.model,
                "prompt": prompt,
                "size": size,
                "quality": quality,
                "n": "1",
                "response_format": "b64_json",
            },
        )

    async def edit(
        self,
        *,
        prompt: str,
        image_bytes: bytes,
        filename: str = "source.png",
        mime_type: str = "image/png",
        size: str = "1024x1024",
        quality: str = "high",
    ) -> ImageResult:
        return await self._request(
            endpoint="/images/edits",
            data={
                "model": self.model,
                "prompt": prompt,
                "size": size,
                "quality": quality,
                "n": "1",
                "response_format": "b64_json",
            },
            files={"image": (filename, image_bytes, mime_type)},
        )
