import pytest

from app.provider_policy import (
    ProviderPolicy,
    ProviderPolicyError,
    ProviderPolicyGuard,
    ProviderRequest,
)
from app.video_provider import (
    FakeVideoProvider,
    VideoCapability,
    VideoJobRequest,
    VideoProviderRouter,
)


def test_disabled_provider_is_blocked_before_execution():
    guard = ProviderPolicyGuard({"image": ProviderPolicy(enabled=False)})
    with pytest.raises(ProviderPolicyError, match="disabled"):
        guard.acquire(ProviderRequest("image"))


def test_cost_and_concurrency_limits_are_enforced():
    guard = ProviderPolicyGuard(
        {"image": ProviderPolicy(enabled=True, max_concurrent=1, max_estimated_cost_cents=100)}
    )
    with pytest.raises(ProviderPolicyError, match="cost"):
        guard.acquire(ProviderRequest("image", estimated_cost_cents=101))

    guard.acquire(ProviderRequest("image", estimated_cost_cents=100))
    with pytest.raises(ProviderPolicyError, match="concurrency"):
        guard.acquire(ProviderRequest("image"))
    guard.release("image")
    guard.acquire(ProviderRequest("image"))


@pytest.mark.asyncio
async def test_fake_video_provider_has_real_job_contract_without_external_call():
    provider = VideoProviderRouter([FakeVideoProvider()]).select(VideoCapability.TEXT_TO_VIDEO)
    job = await provider.create_job(VideoJobRequest("A test scene", VideoCapability.TEXT_TO_VIDEO))
    assert job.status == "queued"
    assert job.output_url is None
