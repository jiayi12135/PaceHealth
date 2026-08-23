from datetime import datetime, timedelta, timezone
from typing import Annotated, Any

from fastapi import Depends
from supabase import Client

from app.schemas.workout import WorkoutCompletionCreate, WorkoutCompletionResponse
from app.services.supabase_client import get_supabase_client


def _to_response(row: dict[str, Any]) -> WorkoutCompletionResponse:
    return WorkoutCompletionResponse(
        completion_id=row["id"],
        plan_id=row["plan_id"],
        day=row["day"],
        status=row["status"],
        reason=row.get("reason"),
        duration_seconds=row.get("duration_seconds"),
        exercise_log=row.get("exercise_log"),
        feedback=row.get("feedback"),
        completed_at=row["completed_at"],
    )


class WorkoutService:
    """Persistence for workout_completions: both finished sessions (duration) and
    skipped ones (reason). Recent rows also feed the AI chat context so the coach
    can react to adherence — see routers/ai.py."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def create(self, user_id: str, payload: WorkoutCompletionCreate) -> WorkoutCompletionResponse:
        result = (
            self.client.table("workout_completions")
            .insert(
                {
                    "user_id": user_id,
                    "plan_id": str(payload.plan_id),
                    "day": payload.day,
                    "status": payload.status,
                    "reason": payload.reason,
                    "duration_seconds": payload.duration_seconds,
                    "exercise_log": [entry.model_dump(by_alias=False) for entry in payload.exercise_log] if payload.exercise_log else None,
                    "feedback": payload.feedback.model_dump(by_alias=False) if payload.feedback else None,
                }
            )
            .execute()
        )
        return _to_response(result.data[0])

    def list_recent(self, user_id: str, days: int = 14) -> list[WorkoutCompletionResponse]:
        since = datetime.now(timezone.utc) - timedelta(days=days)
        result = (
            self.client.table("workout_completions")
            .select("*")
            .eq("user_id", user_id)
            .gte("completed_at", since.isoformat())
            .order("completed_at", desc=True)
            .execute()
        )
        return [_to_response(row) for row in (result.data or [])]


def get_workout_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> WorkoutService:
    return WorkoutService(client)
