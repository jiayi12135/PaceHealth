from typing import Annotated, Any

from fastapi import Depends
from supabase import Client

from app.schemas.user import PersonalInfoData, ProfileData, UserProfileResponse, UserProfileWrite
from app.services.supabase_client import get_supabase_client


class ProfileService:
    """Persistence operations for a user's profile and questionnaire."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def get(self, user_id: str) -> UserProfileResponse | None:
        profile_result = (
            self.client.table("profiles")
            .select("*")
            .eq("user_id", user_id)
            .maybe_single()
            .execute()
        )
        if not profile_result.data:
            return None

        personal_result = (
            self.client.table("user_personal_info")
            .select("*")
            .eq("user_id", user_id)
            .maybe_single()
            .execute()
        )

        return UserProfileResponse(
            user_id=user_id,
            profile=self._profile_from_row(profile_result.data),
            personal_info=self._personal_info_from_row(personal_result.data or {}),
        )

    def upsert(self, user_id: str, payload: UserProfileWrite) -> UserProfileResponse:
        profile_row: dict[str, Any] = {
            "user_id": user_id,
            **payload.profile.model_dump(),
        }
        personal_row: dict[str, Any] = {
            "user_id": user_id,
            **payload.personal_info.model_dump(),
        }

        self.client.table("profiles").upsert(profile_row, on_conflict="user_id").execute()
        self.client.table("user_personal_info").upsert(
            personal_row, on_conflict="user_id"
        ).execute()

        return UserProfileResponse(
            user_id=user_id,
            profile=payload.profile,
            personal_info=payload.personal_info,
        )

    @staticmethod
    def _profile_from_row(row: dict[str, Any]) -> ProfileData:
        fields = ProfileData.model_fields
        return ProfileData.model_validate({key: row[key] for key in fields})

    @staticmethod
    def _personal_info_from_row(row: dict[str, Any]) -> PersonalInfoData:
        return PersonalInfoData.model_validate(
            {key: row.get(key, []) for key in PersonalInfoData.model_fields}
        )


def get_profile_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> ProfileService:
    return ProfileService(client)
