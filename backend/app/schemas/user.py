from pydantic import Field

from app.schemas.base import APIModel


class ProfileData(APIModel):
    name: str = Field(min_length=1, max_length=100)
    age: int = Field(ge=13, le=120)
    sex: str = Field(min_length=1, max_length=30)
    height_cm: float = Field(gt=0, le=300)
<<<<<<< Updated upstream
    current_weight_kg: float = Field(gt=0, le=1000)
=======
    # Renamed from current_weight_kg per team decision: this is the weight the user had
    # when they *set* their goal, and it does not move with daily weight-record check-ins
    # (see docs/DATABASE_SCHEMA_GUIDE.md Decision 1 and docs/TEAM_INTEGRATION_GUIDE.md section 4).
    start_weight_kg: float = Field(gt=0, le=1000)
>>>>>>> Stashed changes
    target_weight_kg: float = Field(gt=0, le=1000)
    goal: str = Field(min_length=1, max_length=100)
    lifestyle: str = Field(min_length=1, max_length=500)
    exercise_frequency_per_week: int = Field(ge=0, le=14)
    exercise_duration_minutes: int = Field(gt=0, le=1440)
<<<<<<< Updated upstream
=======
    # Added per team decision: the user's usual exercise habits (e.g. dancing, swimming),
    # used by the AI service to personalize generated plans.
    exercise_habit: list[str] = Field(default_factory=list)
>>>>>>> Stashed changes
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
