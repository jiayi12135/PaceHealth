from pydantic import Field

from app.schemas.base import APIModel


class ProfileData(APIModel):
    name: str = Field(min_length=1, max_length=100)
    age: int = Field(ge=13, le=120)
    sex: str = Field(min_length=1, max_length=30)
    height_cm: float = Field(gt=0, le=300)
    current_weight_kg: float = Field(gt=0, le=1000)
    target_weight_kg: float = Field(gt=0, le=1000)
    goal: str = Field(min_length=1, max_length=100)
    lifestyle: str = Field(min_length=1, max_length=500)
    exercise_frequency_per_week: int = Field(ge=0, le=14)
    exercise_duration_minutes: int = Field(gt=0, le=1440)
    exercise_location: str = Field(min_length=1, max_length=100)


class PersonalInfoData(APIModel):
    available_equipment: list[str] = Field(default_factory=list)
    posture_issues: list[str] = Field(default_factory=list)
    injuries: list[str] = Field(default_factory=list)
    surgery_history: list[str] = Field(default_factory=list)
    exercises_to_avoid: list[str] = Field(default_factory=list)


class UserProfileWrite(APIModel):
    profile: ProfileData
    personal_info: PersonalInfoData


class UserProfileResponse(UserProfileWrite):
    user_id: str
