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
    # Supabase Storage bucket that equipment/ingredient photos are uploaded to before
    # their public URL is handed to Claude's vision API. Must be created as a public
    # bucket in the Supabase dashboard (or via the Storage API) ahead of time.
    scan_storage_bucket: str = "scans"
    # Optional. Powers app/services/exercise_image_service.py (thumbnail photo per
    # exercise on the Plan screen). Free key at pexels.com/api. If unset, exercises
    # just render without a photo — nothing else depends on this being set.
    pexels_api_key: SecretStr | None = None

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
