from typing import Annotated

from pydantic import EmailStr, Field, SecretStr

from app.schemas.base import APIModel


class AuthCredentials(APIModel):
    email: EmailStr
    password: Annotated[SecretStr, Field(min_length=8, max_length=72)]


class AuthUser(APIModel):
    user_id: str
    email: EmailStr


class AuthResponse(APIModel):
    access_token: str | None = None
    refresh_token: str | None = None
    email_confirmation_required: bool
    user: AuthUser
