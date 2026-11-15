"""Image provider contracts and an opt-in OpenAI adapter.

Provider selection is deliberately separate from provider execution so NIKO can
route requests without exposing paid credentials to clients.
"""
from __future__ import annotations

import base64
import os
from dataclasses import dataclass
from enum import Enum
from typing import Protocol

import httpx


class ImageCapability(str, Enum):
    GENERATE = "generate"
    EDIT = "edit"


@dataclass(frozen=True)
class ImageResult:
    content: bytes
    revised_prompt: str | None
    model: str
    mime_type: str = "image/png"


@dataclass(frozen=True)
class ImageProviderDescriptor:
    name: str
    model: str
    capabilities: frozenset[ImageCapability]
    configured: bool
    estimated_cost: str | None = None


class ImageProvider(Protocol):
    @property
    def descriptor(self) -> ImageProviderDescriptor: ...

    async def generate(self, *, prompt: str, size: str, quality: str) -> ImageResult: ...
    async def edit(self, *, prompt: str, image_bytes: bytes, filename: str,
                   mime_type: str, size: str, quality: str) -> ImageResult: ...


class ImageProviderError(RuntimeError):
    pass


class OpenAIImageProvider:
    def __init__(self, *, api_key: str | None = None, model: str | None = None,
                 base_url: str | None = None, timeout: float = 180.0,
                 transport: httpx.AsyncBaseTransport | None = None) -> None:
        self.api_key = (api_key if api_key is not None else os.getenv("NIKO_IMAGE_API_KEY", "")).strip()
        self.model = (model or os.getenv("NIKO_IMAGE_MODEL", "gpt-image-1")).strip()
        self.base_url = (base_url or os.getenv("NIKO_IMAGE_API_BASE_URL", "https://api.openai.com/v1")).rstrip("/")
        self.timeout, self.transport = timeout, transport

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    @property
    def descriptor(self) -> ImageProviderDescriptor:
        return ImageProviderDescriptor(
            name="openai", model=self.model,
            capabilities=frozenset({ImageCapability.GENERATE, ImageCapability.EDIT}),
            configured=self.configured,
        )

    async def _request(self, *, endpoint: str, data: dict, files=None) -> ImageResult:
        if not self.configured:
            raise ImageProviderError("Image generation is not configured. Set NIKO_IMAGE_API_KEY on the backend.")
        headers = {"Authorization": f"Bearer {self.api_key}"}
        try:
            async with httpx.AsyncClient(timeout=self.timeout, transport=self.transport) as client:
                response = await client.post(f"{self.base_url}{endpoint}", headers=headers,
                                             data=data if files else None,
                                             json=data if not files else None, files=files)
            response.raise_for_status()
            item = response.json()["data"][0]
            encoded = item.get("b64_json")
            if not encoded:
                raise ImageProviderError("The image provider returned no base64 image data.")
            return ImageResult(base64.b64decode(encoded, validate=True),
                               item.get("revised_prompt"), self.model)
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

    async def generate(self, *, prompt: str, size: str = "1024x1024", quality: str = "high") -> ImageResult:
        return await self._request(endpoint="/images/generations",
            data={"model": self.model, "prompt": prompt, "size": size, "quality": quality, "n": "1"})

    async def edit(self, *, prompt: str, image_bytes: bytes, filename: str = "source.png",
                   mime_type: str = "image/png", size: str = "1024x1024",
                   quality: str = "high") -> ImageResult:
        return await self._request(endpoint="/images/edits",
            data={"model": self.model, "prompt": prompt, "size": size, "quality": quality, "n": "1"},
            files={"image": (filename, image_bytes, mime_type)})


class ImageProviderRouter:
    """Fail-closed provider discovery; only configured providers are selectable."""

    def __init__(self, providers: list[ImageProvider] | None = None) -> None:
        self.providers = providers or [OpenAIImageProvider()]

    def select(self, capability: ImageCapability) -> ImageProvider:
        for provider in self.providers:
            descriptor = provider.descriptor
            if descriptor.configured and capability in descriptor.capabilities:
                return provider
        raise ImageProviderError(f"No configured image provider supports {capability.value}.")
