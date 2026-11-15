"""Provider execution policy guards.

These guards are intentionally independent of any paid provider. They make
availability and budget decisions before an adapter can start external work.
"""
from __future__ import annotations

from dataclasses import dataclass


class ProviderPolicyError(RuntimeError):
    pass


@dataclass(frozen=True)
class ProviderPolicy:
    enabled: bool
    max_concurrent: int = 1
    max_estimated_cost_cents: int | None = None


@dataclass(frozen=True)
class ProviderRequest:
    provider_name: str
    estimated_cost_cents: int | None = None


class ProviderPolicyGuard:
    def __init__(self, policies: dict[str, ProviderPolicy]) -> None:
        self._policies = policies
        self._active: dict[str, int] = {}

    def acquire(self, request: ProviderRequest) -> None:
        policy = self._policies.get(request.provider_name)
        if policy is None or not policy.enabled:
            raise ProviderPolicyError("This provider is disabled by server policy.")
        if (policy.max_estimated_cost_cents is not None
                and request.estimated_cost_cents is not None
                and request.estimated_cost_cents > policy.max_estimated_cost_cents):
            raise ProviderPolicyError("The request exceeds the configured cost limit.")
        active = self._active.get(request.provider_name, 0)
        if active >= policy.max_concurrent:
            raise ProviderPolicyError("The provider concurrency limit has been reached.")
        self._active[request.provider_name] = active + 1

    def release(self, provider_name: str) -> None:
        active = self._active.get(provider_name, 0)
        if active <= 1:
            self._active.pop(provider_name, None)
        else:
            self._active[provider_name] = active - 1
