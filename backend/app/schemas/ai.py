"""API-facing request/response shapes for the AI-backed endpoints.

These mirror the plain pydantic models in app/services/ai/models.py (the AI
service's own contract) but go through APIModel so the wire format matches the
rest of this API (camelCase JSON, snake_case Python) and so client-supplied
data is validated the same way as every other endpoint. Routers convert
between the two via app/services/ai_bridge.py.

Note what's deliberately *not* accepted from the client: userId, profile, and
personalInfo are never read from the request body here. Every other endpoint
in this API derives the acting user from the bearer token (see
app/dependencies/auth.py) rather than trusting a client-supplied ID, and the
AI endpoints keep that rule — profile/personalInfo are loaded from the
database for the authenticated user instead of being forwarded verbatim from
the client the way Stephanie's ai-service docs describe for a standalone
service without its own auth layer.
"""

from datetime import date
from typing import Literal

from pydantic import Field

from app.schemas.base import APIModel


# ---------- generate-plan ----------


class ExerciseResponse(APIModel):
    day: str
    exercise_name: str
    sets: int
    reps: int | None = None
    duration: int | None = None
    rest_seconds: int
    reason: str
    video_url: str | None = None
    # Best-effort thumbnail from Pexels (app/services/exercise_image_service.py),
    # keyed off exercise_name. None if PEXELS_API_KEY isn't set or the lookup
    # failed/found nothing — the frontend falls back to an icon in that case.
    image_url: str | None = None


class WorkoutPlanResponse(APIModel):
    plan_id: str
    plan_name: str
    goal: str
    weekly_frequency: int
    exercises: list[ExerciseResponse]


# ---------- chat ----------


class ChatRequest(APIModel):
    message: str = Field(min_length=1, max_length=4000)


class ChatResponse(APIModel):
    reply: str


# ---------- report ----------


class ReportRequest(APIModel):
    period_type: Literal["weekly", "monthly"]


class WeightPointResponse(APIModel):
    weight_kg: float
    recorded_at: date


class ReportResponse(APIModel):
    period_type: Literal["weekly", "monthly"]
    has_enough_data: bool
    initial_weight_kg: float | None = None
    end_weight_kg: float | None = None
    delta_kg: float | None = None
    progress_to_goal_percent: float | None = None
    projected_weeks_to_goal: float | None = None
    summary: str
    weight_records: list[WeightPointResponse]


# ---------- generate-meal-plan ----------


class MealPlanRequest(APIModel):
    available_ingredients: list[str] = Field(default_factory=list)
    dietary_restrictions: list[str] = Field(default_factory=list)
    # Rather than accepting recentProgress numbers straight from the client (which
    # would let a client claim any progress it wants), the client just asks for it
    # and the backend computes the same weekly stats /ai/report would, from the
    # database, and forwards those.
    include_recent_progress: bool = False


class RecipeResponse(APIModel):
    meal_type: str
    recipe_name: str
    ingredients_used: list[str]
    instructions: str
    estimated_calories: int | None = None
    estimated_protein_g: float | None = None
    reason: str


class MealPlanResponse(APIModel):
    plan_name: str
    goal: str
    daily_calorie_target: int | None = None
    recipes: list[RecipeResponse]
    adjustment_note: str | None = None


# ---------- equipment / ingredient scans ----------


class EquipmentScanResponse(APIModel):
    recognized: bool
    confidence: float
    equipment_name: str | None = None
    description: str | None = None
    target_muscles: list[str]
    usage_instructions: str | None = None
    safety_notes: str | None = None
    personalized_warning: str | None = None
    not_recognized_message: str | None = None


class DetectedIngredientResponse(APIModel):
    name: str
    quantity: str | None = None


class IngredientScanResponse(APIModel):
    recognized: bool
    confidence: float
    ingredients: list[DetectedIngredientResponse]
    not_recognized_message: str | None = None


# ---------- food scan (photo -> estimated calories, for the Nutrition tab) ----------


class FoodScanResponse(APIModel):
    scan_id: str | None = None  # None for scans that failed to persist; see routers/scans.py
    recognized: bool
    confidence: float
    food_name: str | None = None
    description: str | None = None
    portion_estimate: str | None = None
    estimated_calories: int | None = None
    estimated_protein_g: float | None = None
    estimated_carbs_g: float | None = None
    estimated_fat_g: float | None = None
    not_recognized_message: str | None = None
    scanned_at: str | None = None


class DailyFoodLogResponse(APIModel):
    date: str
    total_calories: int
    scans: list[FoodScanResponse]
