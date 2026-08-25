from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from postgrest.exceptions import APIError as PostgrestAPIError

from app.dependencies.auth import get_current_user
from app.errors import APIError
from app.schemas.auth import AuthUser
from app.schemas.workout import WorkoutCompletionCreate, WorkoutCompletionResponse
from app.services.workout_service import WorkoutService, get_workout_service


router = APIRouter(prefix="/workouts", tags=["workouts"])


@router.post("/completions", response_model=WorkoutCompletionResponse, status_code=status.HTTP_201_CREATED)
def record_completion(
    payload: WorkoutCompletionCreate,
    user: Annotated[AuthUser, Depends(get_current_user)],
    workouts: Annotated[WorkoutService, Depends(get_workout_service)],
) -> WorkoutCompletionResponse:
    if payload.status == "skipped" and not (payload.reason or "").strip():
        raise APIError(400, "Please tell us why the workout was skipped.", "SKIP_REASON_REQUIRED")

    try:
        return workouts.create(user.user_id, payload)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to save the workout record.", "WORKOUT_WRITE_FAILED") from exc


@router.get("/completions", response_model=list[WorkoutCompletionResponse])
def list_recent_completions(
    user: Annotated[AuthUser, Depends(get_current_user)],
    workouts: Annotated[WorkoutService, Depends(get_workout_service)],
    days: Annotated[int, Query(ge=1, le=365)] = 14,
) -> list[WorkoutCompletionResponse]:
    try:
        return workouts.list_recent(user.user_id, days)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load workout records.", "WORKOUT_READ_FAILED") from exc
