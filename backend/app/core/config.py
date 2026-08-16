from functools import lru_cache
from pathlib import Path

from pydantic import HttpUrl, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Environment-backed settings for the PaceHealth API."""

    app_name: str = "PaceHealth API"
    app_version: str = "0.1.0"
    supabase_url: HttpUrl | None = None
    supabase_secret_key: SecretStr | None = None
    anthropic_api_key: SecretStr | None = None

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
