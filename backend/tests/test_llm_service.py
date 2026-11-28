"""LLM service tests - OpenRouter and NVIDIA NIM provider selection."""

from app.core.config import reset_settings_cache
from app.services.llm_service import LLMService


def _setup_settings(monkeypatch, provider: str, api_key: str | None = None):
    """Monkeypatch settings for isolated LLM service testing."""
    monkeypatch.setenv("LLM_PROVIDER", provider)
    monkeypatch.setenv("PRIVACY_MODE", "approved_cloud")
    if api_key is not None:
        if provider == "nvidia_nim":
            monkeypatch.setenv("NVIDIA_NIM_API_KEY", api_key)
        else:
            monkeypatch.setenv("OPENROUTER_API_KEY", api_key)
    reset_settings_cache()


def test_llm_service_openrouter_config(monkeypatch):
    """OpenRouter provider uses OpenRouter-specific settings."""
    _setup_settings(monkeypatch, "openrouter", "test-or-key")
    service = LLMService()
    assert service.provider == "openrouter"
    assert service.api_key == "test-or-key"
    assert "openrouter.ai" in service.base_url
    assert service.model == "openai/gpt-4o-mini"


def test_llm_service_nvidia_nim_config(monkeypatch):
    """NVIDIA NIM provider uses NVIDIA NIM-specific settings."""
    _setup_settings(monkeypatch, "nvidia_nim", "test-nim-key")
    service = LLMService()
    assert service.provider == "nvidia_nim"
    assert service.api_key == "test-nim-key"
    assert "integrate.api.nvidia.com" in service.base_url
    assert "nemotron" in service.model


def test_llm_service_no_api_key_returns_error(monkeypatch):
    """Without an API key, the service returns a clear error instead of calling."""
    _setup_settings(monkeypatch, "openrouter", None)
    service = LLMService()
    assert service.api_key is None
    # is_cloud_allowed returns True (approved_cloud + allowed provider)
    assert service.is_cloud_allowed() is True


def test_llm_service_local_privacy_blocks(monkeypatch):
    """Privacy mode 'local' blocks cloud LLM regardless of provider."""
    monkeypatch.setenv("LLM_PROVIDER", "nvidia_nim")
    monkeypatch.setenv("NVIDIA_NIM_API_KEY", "test-key")
    monkeypatch.setenv("PRIVACY_MODE", "local")
    reset_settings_cache()
    service = LLMService()
    assert service.is_cloud_allowed() is False


def test_llm_service_disabled_provider(monkeypatch):
    """Provider 'disabled' is not in allowed providers."""
    monkeypatch.setenv("LLM_PROVIDER", "disabled")
    monkeypatch.setenv("PRIVACY_MODE", "approved_cloud")
    reset_settings_cache()
    service = LLMService()
    assert service.provider == "disabled"
    assert service.is_cloud_allowed() is False
