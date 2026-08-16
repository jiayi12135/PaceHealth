from typing import Annotated

from fastapi import APIRouter, Depends
from postgrest.exceptions import APIError as PostgrestAPIError

from app.dependencies.auth import get_current_user
from app.errors import APIError
from app.schemas.auth import AuthUser
from app.schemas.user import UserProfileResponse, UserProfileWrite
from app.services.profile_service import ProfileService, get_profile_service


router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserProfileResponse)
def get_my_profile(
    user: Annotated[AuthUser, Depends(get_current_user)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
) -> UserProfileResponse:
    try:
        profile = profiles.get(user.user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load the profile.", "PROFILE_READ_FAILED") from exc

    if profile is None:
        raise APIError(404, "Profile has not been created.", "PROFILE_NOT_FOUND")

    return profile


@router.put("/me", response_model=UserProfileResponse)
def upsert_my_profile(
    payload: UserProfileWrite,
    user: Annotated[AuthUser, Depends(get_current_user)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
) -> UserProfileResponse:
    try:
        return profiles.upsert(user.user_id, payload)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to save the profile.", "PROFILE_WRITE_FAILED") from exc
