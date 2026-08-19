from typing import Annotated, Any

from fastapi import Depends
from supabase import Client

from app.services.ai.models import WorkoutPlan
from app.services.supabase_client import get_supabase_client


class PlanService:
    """Persistence for ai_plans + exercises, populated by POST /ai/generate-plan.

    Fills in the fields the AI service intentionally doesn't generate (planId,
    userId, createdAt — see docs/TEAM_INTEGRATION_GUIDE.md section 3, "需要你补的字段").
    """

    def __init__(self, client: Client) -> None:
        self.client = client

    def save(self, user_id: str, plan: WorkoutPlan) -> str:
        plan_result = (
            self.client.table("ai_plans")
            .insert(
                {
                    "user_id": user_id,
                    "plan_name": plan.planName,
                    "goal": plan.goal,
                    "weekly_frequency": plan.weeklyFrequency,
                }
            )
            .execute()
        )
        plan_id: str = plan_result.data[0]["id"]

        exercise_rows: list[dict[str, Any]] = [
            {
                "plan_id": plan_id,
                "day": exercise.day,
                "exercise_name": exercise.exerciseName,
                "sets": exercise.sets,
                "reps": exercise.reps,
                "duration_seconds": exercise.duration,
                "rest_seconds": exercise.restSeconds,
                "reason": exercise.reason,
                "video_url": exercise.videoUrl,
            }
            for exercise in plan.exercises
        ]
        if exercise_rows:
            self.client.table("exercises").insert(exercise_rows).execute()

        return plan_id


def get_plan_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> PlanService:
    return PlanService(client)
