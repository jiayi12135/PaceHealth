from typing import Annotated

from fastapi import Depends
from supabase import Client, create_client

from app.core.config import Settings, get_settings


def create_supabase_client(settings: Settings) -> Client:
    """Create a backend-only Supabase client from validated settings."""
    if settings.supabase_url is None or settings.supabase_secret_key is None:
        raise RuntimeError(
            "SUPABASE_URL and SUPABASE_SECRET_KEY must be configured in backend/.env"
        )

    return create_client(
        str(settings.supabase_url).rstrip("/"),
        settings.supabase_secret_key.get_secret_value(),
    )


def get_supabase_client(
    settings: Annotated[Settings, Depends(get_settings)],
) -> Client:
    return create_supabase_client(settings)
