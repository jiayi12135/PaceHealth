"""Glue between backend's DB-facing schemas/services and the AI service's own
contract models (app/services/ai/models.py). Kept separate from app/services/ai/
so that package can stay a clean, easy-to-diff copy of Stephanie's ai-service
code rather than getting backend-specific mapping logic mixed into it.
"""

from datetime import date, timedelta
from typing import Literal

from app.schemas.ai import (
    DetectedIngredientResponse,
    EquipmentScanResponse,
    ExerciseResponse,
    IngredientScanResponse,
    MealPlanResponse,
    RecipeResponse,
    ReportResponse,
    WeightPointResponse,
    WorkoutPlanResponse,
)
from app.schemas.user import PersonalInfoData, ProfileData
from app.services.ai import models as ai_models
from app.services.ai.report_calculator import ReportStats, calculate_report_stats
from app.services.weight_service import WeightService


# Rolling window ending today, not a calendar week/month — the simplest option for
# the first demo (see docs/DATABASE_SCHEMA_GUIDE.md). `periodType` only changes the
# window length and how the AI summary refers to it ("this week" vs "this month").
PERIOD_DAYS: dict[str, int] = {"weekly": 7, "monthly": 30}


def to_ai_profile(profile: ProfileData) -> ai_models.Profile:
    return ai_models.Profile(
        name=profile.name,
        age=profile.age,
        sex=profile.sex,
        heightCm=profile.height_cm,
        startWeightKg=profile.start_weight_kg,
        targetWeightKg=profile.target_weight_kg,
        goal=profile.goal,
        lifestyle=profile.lifestyle,
        exerciseFrequencyPerWeek=profile.exercise_frequency_per_week,
        exerciseDurationMinutes=profile.exercise_duration_minutes,
        exerciseHabit=profile.exercise_habit,
        exerciseLocation=profile.exercise_location,
    )


def to_ai_personal_info(info: PersonalInfoData) -> ai_models.UserPersonalInfo:
    return ai_models.UserPersonalInfo(
        availableEquipment=info.available_equipment,
        postureIssues=info.posture_issues,
        injuries=info.injuries,
        surgeryHistory=info.surgery_history,
        exercisesToAvoid=info.exercises_to_avoid,
    )


def to_workout_plan_response(plan_id: str, plan: ai_models.WorkoutPlan) -> WorkoutPlanResponse:
    return WorkoutPlanResponse(
        plan_id=plan_id,
        plan_name=plan.planName,
        goal=plan.goal,
        weekly_frequency=plan.weeklyFrequency,
        exercises=[
            ExerciseResponse(
                day=exercise.day,
                exercise_name=exercise.exerciseName,
                sets=exercise.sets,
                reps=exercise.reps,
                duration=exercise.duration,
                rest_seconds=exercise.restSeconds,
                reason=exercise.reason,
                video_url=exercise.videoUrl,
            )
            for exercise in plan.exercises
        ],
    )


def period_date_range(period_type: Literal["weekly", "monthly"], *, today: date | None = None) -> tuple[date, date]:
    end = today or date.today()
    start = end - timedelta(days=PERIOD_DAYS[period_type] - 1)
    return start, end


def compute_report_stats(
    weight_service: WeightService,
    profile: ProfileData,
    user_id: str,
    period_type: Literal["weekly", "monthly"],
) -> tuple[date, date, list[ai_models.WeightPoint], ReportStats]:
    """Load this period's weight records for the user and run the same
    code-computed stats /ai/report uses. Shared with /ai/generate-meal-plan's
    optional recentProgress so both features draw on one source of truth
    instead of the client being able to hand the AI arbitrary progress numbers.
    """
    start, end = period_date_range(period_type)
    records = weight_service.list(user_id, start, end)
    weight_points = [
        ai_models.WeightPoint(weightKg=record.weight_kg, recordedAt=record.recorded_at) for record in records
    ]
    stats = calculate_report_stats(weight_points, to_ai_profile(profile))
    return start, end, weight_points, stats


def to_report_response(
    period_type: Literal["weekly", "monthly"],
    stats: ReportStats,
    summary: str,
    weight_records: list[ai_models.WeightPoint],
) -> ReportResponse:
    return ReportResponse(
        period_type=period_type,
        has_enough_data=stats.has_enough_data,
        initial_weight_kg=stats.start_weight_kg,
        end_weight_kg=stats.end_weight_kg,
        delta_kg=stats.delta_kg,
        progress_to_goal_percent=stats.progress_to_goal_percent,
        projected_weeks_to_goal=stats.projected_weeks_to_goal,
        summary=summary,
        weight_records=[
            WeightPointResponse(weight_kg=point.weightKg, recorded_at=point.recordedAt) for point in weight_records
        ],
    )


def to_meal_plan_response(plan: ai_models.MealPlanResponse) -> MealPlanResponse:
    return MealPlanResponse(
        plan_name=plan.planName,
        goal=plan.goal,
        daily_calorie_target=plan.dailyCalorieTarget,
        recipes=[
            RecipeResponse(
                meal_type=recipe.mealType,
                recipe_name=recipe.recipeName,
                ingredients_used=recipe.ingredientsUsed,
                instructions=recipe.instructions,
                estimated_calories=recipe.estimatedCalories,
                estimated_protein_g=recipe.estimatedProteinG,
                reason=recipe.reason,
            )
            for recipe in plan.recipes
        ],
        adjustment_note=plan.adjustmentNote,
    )


def to_equipment_scan_response(result: ai_models.EquipmentIdentifyResponse) -> EquipmentScanResponse:
    return EquipmentScanResponse(
        recognized=result.recognized,
        confidence=result.confidence,
        equipment_name=result.equipmentName,
        description=result.description,
        target_muscles=result.targetMuscles,
        usage_instructions=result.usageInstructions,
        safety_notes=result.safetyNotes,
        personalized_warning=result.personalizedWarning,
        not_recognized_message=result.notRecognizedMessage,
    )


def to_ingredient_scan_response(result: ai_models.IngredientIdentifyResponse) -> IngredientScanResponse:
    return IngredientScanResponse(
        recognized=result.recognized,
        confidence=result.confidence,
        ingredients=[
            DetectedIngredientResponse(name=item.name, quantity=item.quantity) for item in result.ingredients
        ],
        not_recognized_message=result.notRecognizedMessage,
    )
