from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase import Client
from supabase_auth.errors import AuthApiError

from app.errors import APIError
from app.schemas.auth import AuthUser
from app.services.supabase_client import get_supabase_client


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    client: Annotated[Client, Depends(get_supabase_client)],
) -> AuthUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise APIError(401, "Authentication is required.", "AUTHENTICATION_REQUIRED")

    try:
        response = client.auth.get_user(credentials.credentials)
    except AuthApiError as exc:
        raise APIError(401, "Access token is invalid or expired.", "INVALID_ACCESS_TOKEN") from exc

    if response is None or response.user is None or response.user.email is None:
        raise APIError(401, "Access token is invalid or expired.", "INVALID_ACCESS_TOKEN")

    return AuthUser(user_id=str(response.user.id), email=response.user.email)
