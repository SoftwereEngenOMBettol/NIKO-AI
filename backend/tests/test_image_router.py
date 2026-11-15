from app.image_provider import (
    ImageCapability,
    ImageProviderDescriptor,
    ImageProviderError,
    ImageProviderRouter,
)


class FakeProvider:
    def __init__(self, configured=True, capabilities=frozenset({ImageCapability.GENERATE})):
        self._descriptor = ImageProviderDescriptor("fake", "fake-1", capabilities, configured)

    @property
    def descriptor(self):
        return self._descriptor


def test_router_selects_only_configured_provider():
    disabled = FakeProvider(configured=False)
    enabled = FakeProvider(configured=True)
    assert ImageProviderRouter([disabled, enabled]).select(ImageCapability.GENERATE) is enabled


def test_router_fails_closed_when_no_provider_is_configured():
    router = ImageProviderRouter([FakeProvider(configured=False)])
    try:
        router.select(ImageCapability.GENERATE)
    except ImageProviderError as exc:
        assert "No configured" in str(exc)
    else:
        raise AssertionError("Expected provider selection to fail closed")
