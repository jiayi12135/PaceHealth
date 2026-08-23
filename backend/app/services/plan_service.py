from typing import Annotated, Any

from fastapi import Depends
from supabase import Client

from app.schemas.ai import ExerciseResponse, WorkoutPlanResponse
from app.services.ai.models import WorkoutPlan
from app.services.supabase_client import get_supabase_client


class PlanService:
    """Persistence for ai_plans + exercises, populated by POST /ai/generate-plan.

    Fills in the fields the AI service intentionally doesn't generate (planId,
    userId, createdAt — see docs/TEAM_INTEGRATION_GUIDE.md section 3, "需要你补的字段").
    """

    def __init__(self, client: Client) -> None:
        self.client = client

    def save(self, user_id: str, plan: WorkoutPlan, images: dict[str, str | None] | None = None) -> tuple[str, str]:
        """images: exercise_name -> Pexels thumbnail URL, best-effort (see
        app/services/exercise_image_service.py). Passed in already-resolved so it can
        be stored alongside the exercise rows — reloading a saved plan later (e.g.
        GET /ai/plan after a restart) then doesn't need another Pexels round trip and
        the thumbnails stay stable instead of possibly resolving to a different photo.

        Returns (plan_id, created_at) — created_at comes straight back from the insert
        (DB-generated default), the caller needs it so the response can tell the
        frontend when this plan first existed (see WorkoutPlanResponse.created_at).
        """
        images = images or {}
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
        created_at: str = plan_result.data[0]["created_at"]

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
                "instructions": exercise.instructions,
                "video_url": exercise.videoUrl,
                "image_url": images.get(exercise.exerciseName),
            }
            for exercise in plan.exercises
        ]
        if exercise_rows:
            self.client.table("exercises").insert(exercise_rows).execute()

        return plan_id, created_at

    def save_day_assignments(self, user_id: str, plan_id: str, assignments: dict[str, str]) -> bool:
        """Updates day_assignments on a plan the user actually owns. Returns False
        (instead of raising) if plan_id doesn't belong to user_id or doesn't exist —
        the router turns that into a 404, same defense-in-depth as everywhere else
        client-supplied IDs get used for a write."""
        result = (
            self.client.table("ai_plans")
            .update({"day_assignments": assignments})
            .eq("id", plan_id)
            .eq("user_id", user_id)
            .execute()
        )
        return bool(result.data)

    def get_latest(self, user_id: str) -> WorkoutPlanResponse | None:
        """Most recently generated plan for this user, with its exercises — used to
        restore Home/Calendar/Plan after a re-login or restart instead of silently
        showing an empty state (the plan itself only lived in-memory client-side
        before this)."""
        plan_result = (
            self.client.table("ai_plans")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if not plan_result.data:
            return None
        plan_row = plan_result.data[0]

        exercises_result = (
            self.client.table("exercises")
            .select("*")
            .eq("plan_id", plan_row["id"])
            # 按插入顺序(id递增)读回来,尽量还原生成时的动作顺序。
            .order("id")
            .execute()
        )

        return WorkoutPlanResponse(
            plan_id=plan_row["id"],
            plan_name=plan_row["plan_name"],
            goal=plan_row["goal"],
            weekly_frequency=plan_row["weekly_frequency"],
            day_assignments=plan_row.get("day_assignments"),
            created_at=plan_row["created_at"],
            exercises=[
                ExerciseResponse(
                    day=row["day"],
                    exercise_name=row["exercise_name"],
                    sets=row["sets"],
                    reps=row.get("reps"),
                    duration=row.get("duration_seconds"),
                    rest_seconds=row["rest_seconds"],
                    reason=row["reason"],
                    # 老数据(这几列加之前生成的plan)可能是null,给个空字符串兜底,
                    # 不让pydantic校验失败——前端本来就对空instructions有UI兜底。
                    instructions=row.get("instructions") or "",
                    video_url=row.get("video_url"),
                    image_url=row.get("image_url"),
                )
                for row in (exercises_result.data or [])
            ],
        )


def get_plan_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> PlanService:
    return PlanService(client)
