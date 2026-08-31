from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field

from app.schemas.base import APIModel


# Per-exercise record within one workout session — the granular data behind the
# day-level status/reason fields below. exerciseName is a free-text match against
# the plan's exercise_name (no exercise ID exists yet), good enough since it's only
# used to build a human-readable adherence note for the AI coach (see routers/ai.py),
# not for any strict joins.
class ExerciseLogEntry(APIModel):
    exercise_name: str = Field(min_length=1, max_length=200)
    status: Literal["completed", "skipped"]
    estimated_duration_seconds: int | None = Field(default=None, ge=0, le=24 * 3600)
    actual_duration_seconds: int | None = Field(default=None, ge=0, le=24 * 3600)
    # Reason code from the fixed option set shown in the skip sheet (e.g. "too_difficult",
    # "pain_discomfort", ...), or "other" with the free-text note below.
    skip_reason: str | None = Field(default=None, max_length=50)
    skip_reason_note: str | None = Field(default=None, max_length=300)


# Answers from the contextual end-of-workout feedback form. Only collected when the
# session looked unusual (see _looks_unusual in the frontend) — never a mandatory form.
class WorkoutFeedback(APIModel):
    time_reason: str | None = Field(default=None, max_length=50)
    time_reason_note: str | None = Field(default=None, max_length=300)
    finished_quickly_reason: str | None = Field(default=None, max_length=50)


class WorkoutCompletionCreate(APIModel):
    plan_id: UUID
    day: str = Field(min_length=1, max_length=100)
    status: Literal["completed", "skipped"] = "completed"
    # Why the session was skipped ("Too tired", "No time", ...). Only meaningful
    # for skips; the AI coach reads recent reasons to adjust its advice.
    reason: str | None = Field(default=None, max_length=500)
    duration_seconds: int | None = Field(default=None, ge=0, le=24 * 3600)
    # Per-exercise breakdown + contextual feedback from the new swipe-through workout
    # session screen. Both optional so older clients / existing tests that only send
    # the day-level fields keep working unchanged.
    exercise_log: list[ExerciseLogEntry] | None = None
    feedback: WorkoutFeedback | None = None
    # Only set by the client's auto-backfill (a scheduled day went by with no completion
    # and no explicit skip) so the record lands on the day it was actually missed instead
    # of "now". Normal completes/skips from the app leave this null and the DB default
    # (now()) applies.
    completed_at: datetime | None = None


class WorkoutCompletionResponse(WorkoutCompletionCreate):
    completion_id: UUID
    completed_at: datetime
