from typing import Annotated
from uuid import uuid4

from fastapi import Depends
from supabase import Client

from app.core.config import Settings, get_settings
from app.services.supabase_client import get_supabase_client


# Claude's vision API fetches images by URL, so anything we accept here must end up
# as a publicly reachable link, not raw bytes. Only allow content types we know the
# storage bucket + AI vision call can round-trip; anything else is a client error.
_EXTENSION_BY_CONTENT_TYPE = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/heic": "heic",
}


class UnsupportedImageTypeError(ValueError):
    """Raised when the uploaded file's content type isn't an image we can store."""


class StorageService:
    """Uploads user-submitted photos (equipment/ingredient scans) to Supabase Storage
    and returns a public URL, since Claude's vision API reads images by URL rather
    than accepting raw bytes or base64 from us directly."""

    def __init__(self, client: Client, bucket: str) -> None:
        self.client = client
        self.bucket = bucket

    def upload_image(self, user_id: str, file_bytes: bytes, content_type: str | None) -> str:
        extension = _EXTENSION_BY_CONTENT_TYPE.get((content_type or "").lower())
        if extension is None:
            raise UnsupportedImageTypeError(content_type or "unknown")

        path = f"{user_id}/{uuid4()}.{extension}"
        self.client.storage.from_(self.bucket).upload(
            path,
            file_bytes,
            {"content-type": content_type},
        )
        return self.client.storage.from_(self.bucket).get_public_url(path)


def get_storage_service(
    client: Annotated[Client, Depends(get_supabase_client)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> StorageService:
    return StorageService(client, settings.scan_storage_bucket)
