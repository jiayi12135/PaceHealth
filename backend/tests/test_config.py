from unittest.mock import Mock, patch

import pytest
from pydantic import SecretStr

from app.core.config import Settings
from app.services.supabase_client import create_supabase_client


def test_settings_accept_supabase_configuration() -> None:
    settings = Settings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        supabase_secret_key=SecretStr("test-secret"),
    )

    assert str(settings.supabase_url) == "https://example.supabase.co/"
    assert settings.supabase_secret_key.get_secret_value() == "test-secret"


def test_supabase_client_requires_configuration() -> None:
    settings = Settings(_env_file=None)

    with pytest.raises(RuntimeError, match="SUPABASE_URL"):
        create_supabase_client(settings)


def test_supabase_client_uses_configured_credentials() -> None:
    settings = Settings(
        _env_file=None,
        supabase_url="https://example.supabase.co",
        supabase_secret_key=SecretStr("test-secret"),
    )
    expected_client = Mock()

    with patch(
        "app.services.supabase_client.create_client", return_value=expected_client
    ) as factory:
        client = create_supabase_client(settings)

    assert client is expected_client
    factory.assert_called_once_with("https://example.supabase.co", "test-secret")
