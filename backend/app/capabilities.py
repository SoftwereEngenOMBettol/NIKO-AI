"""Runtime capability declarations. A feature is available only when its implementation and provider are configured."""
from __future__ import annotations

import importlib.util
import os


def get_capabilities() -> dict:
    document_packages = {
        "docx": "docx",
        "xlsx": "openpyxl",
        "pptx": "pptx",
        "txt": None,
        "csv": None,
    }
    documents = {
        fmt: {
            "available": package is None or importlib.util.find_spec(package) is not None,
            "reason": None if package is None or importlib.util.find_spec(package) is not None
            else f"Install the optional package: {package}",
        }
        for fmt, package in document_packages.items()
    }
    image_provider = os.getenv("NIKO_IMAGE_PROVIDER", "").strip()
    video_provider = os.getenv("NIKO_VIDEO_PROVIDER", "").strip()
    return {
        "chat": {"available": True, "provider": "ollama", "model": os.getenv("OLLAMA_MODEL", "qwen2.5:3b")},
        "documents": {"available": any(item["available"] for item in documents.values()), "formats": documents},
        "image_generation": {
            "available": False,
            "provider_configured": bool(image_provider),
            "status": "provider_adapter_not_implemented",
            "message": "Image generation is not enabled yet; configure and validate a supported provider before advertising it.",
        },
        "video_generation": {
            "available": False,
            "provider_configured": bool(video_provider),
            "status": "provider_adapter_not_implemented",
            "message": "Video generation is not enabled yet; configure and validate a supported provider before advertising it.",
        },
        "web_research": {"available": False, "status": "not_implemented"},
        "social_publishing": {"available": False, "status": "official_integrations_not_configured"},
        "whatsapp": {"available": False, "status": "official_integration_not_configured"},
        "telephony": {"available": False, "status": "provider_not_configured"},
    }
