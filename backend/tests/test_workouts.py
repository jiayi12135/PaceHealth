from datetime import datetime, timezone
from unittest.mock import Mock

from fastapi.testclient import TestClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.schemas.auth import AuthUser
from app.schemas.workout import WorkoutCompletionResponse
from app.services.workout_service import get_workout_service


USER_ID = "11111111-1111-1111-1111-111111111111"
PLAN_ID = "22222222-2222-2222-2222-222222222222"


def _override_auth() -> None:
    app.dependency_overrides[get_current_user] = lambda: AuthUser(
        user_id=USER_ID, email="user@example.com"
    )


class TestRecordCompletion:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_records_a_completed_workout(self) -> None:
        _override_auth()
        workout_service = Mock()
        workout_service.create.return_value = WorkoutCompletionResponse(
            completion_id="33333333-3333-3333-3333-333333333333",
            plan_id=PLAN_ID,
            day="Day 1",
            status="completed",
            reason=None,
            duration_seconds=1800,
            completed_at=datetime.now(timezone.utc),
        )
        app.dependency_overrides[get_workout_service] = lambda: workout_service

        response = TestClient(app).post(
            "/workouts/completions",
            json={"planId": PLAN_ID, "day": "Day 1", "status": "completed", "durationSeconds": 1800},
        )

        assert response.status_code == 201
        assert response.json()["status"] == "completed"
        workout_service.create.assert_called_once()

    def test_skip_requires_a_reason(self) -> None:
        _override_auth()
        app.dependency_overrides[get_workout_service] = lambda: Mock()

        response = TestClient(app).post(
            "/workouts/completions",
            json={"planId": PLAN_ID, "day": "Day 1", "status": "skipped"},
        )

        assert response.status_code == 400
        assert response.json()["data"]["errorCode"] == "SKIP_REASON_REQUIRED"
