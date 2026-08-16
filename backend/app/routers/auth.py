from typing import Annotated, Any

from fastapi import APIRouter, Depends, status
from supabase import Client
from supabase_auth.errors import AuthApiError

from app.errors import APIError
from app.schemas.auth import AuthCredentials, AuthResponse, AuthUser
from app.services.supabase_client import get_supabase_client


router = APIRouter(prefix="/auth", tags=["authentication"])


def _build_auth_response(response: Any, *, require_session: bool) -> AuthResponse:
    if response.user is None or response.user.email is None:
        raise APIError(502, "Supabase did not return a user.", "AUTH_PROVIDER_ERROR")

    if require_session and response.session is None:
        raise APIError(401, "Unable to create a login session.", "INVALID_CREDENTIALS")

    return AuthResponse(
        access_token=response.session.access_token if response.session else None,
        refresh_token=response.session.refresh_token if response.session else None,
        email_confirmation_required=response.session is None,
        user=AuthUser(user_id=str(response.user.id), email=response.user.email),
    )


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(
    credentials: AuthCredentials,
    client: Annotated[Client, Depends(get_supabase_client)],
) -> AuthResponse:
    try:
        response = client.auth.sign_up(
            {
                "email": str(credentials.email),
                "password": credentials.password.get_secret_value(),
            }
        )
    except AuthApiError as exc:
        raise APIError(400, "Unable to register this account.", "REGISTRATION_FAILED") from exc

    return _build_auth_response(response, require_session=False)


@router.post("/login", response_model=AuthResponse)
def login(
    credentials: AuthCredentials,
    client: Annotated[Client, Depends(get_supabase_client)],
) -> AuthResponse:
    try:
        response = client.auth.sign_in_with_password(
            {
                "email": str(credentials.email),
                "password": credentials.password.get_secret_value(),
            }
        )
    except AuthApiError as exc:
        raise APIError(401, "Email or password is incorrect.", "INVALID_CREDENTIALS") from exc

    return _build_auth_response(response, require_session=True)
