"""Video provider contracts and a no-network fake provider for lifecycle tests."""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Protocol


class VideoCapability(str, Enum):
    TEXT_TO_VIDEO = "text_to_video"
    IMAGE_TO_VIDEO = "image_to_video"


@dataclass(frozen=True)
class VideoJobRequest:
    prompt: str
    capability: VideoCapability
    aspect_ratio: str = "16:9"


@dataclass(frozen=True)
class VideoJob:
    id: str
    provider: str
    status: str
    output_url: str | None = None


class VideoProvider(Protocol):
    name: str
    configured: bool
    capabilities: frozenset[VideoCapability]

    async def create_job(self, request: VideoJobRequest) -> VideoJob: ...


class VideoProviderRouter:
    def __init__(self, providers: list[VideoProvider]) -> None:
        self.providers = providers

    def select(self, capability: VideoCapability) -> VideoProvider:
        for provider in self.providers:
            if provider.configured and capability in provider.capabilities:
                return provider
        raise RuntimeError(f"No configured video provider supports {capability.value}.")


class FakeVideoProvider:
    """Test-only adapter; it never calls an external service or claims a real MP4."""

    name = "fake"
    configured = True
    capabilities = frozenset({VideoCapability.TEXT_TO_VIDEO, VideoCapability.IMAGE_TO_VIDEO})

    async def create_job(self, request: VideoJobRequest) -> VideoJob:
        return VideoJob(id="fake-job", provider=self.name, status="queued")
