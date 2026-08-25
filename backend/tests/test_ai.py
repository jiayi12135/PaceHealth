from datetime import date, timedelta
from types import SimpleNamespace
from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.schemas.auth import AuthUser
from app.schemas.user import PersonalInfoData, ProfileData, UserProfileResponse
from app.services.ai.models import (
    ChatMessage,
    Exercise,
    MealPlanResponse,
    Recipe,
    WorkoutPlan,
)
from app.services.ai.report_calculator import ReportStats
from app.services.chat_service import get_chat_service
from app.services.plan_service import get_plan_service
from app.services.profile_service import get_profile_service
from app.services.report_service import get_report_service
from app.services.weight_service import get_weight_service
from app.services.workout_service import get_workout_service


USER_ID = "11111111-1111-1111-1111-111111111111"


def _profile_response() -> UserProfileResponse:
    return UserProfileResponse(
        user_id=USER_ID,
        profile=ProfileData(
            name="Test User",
            age=28,
            sex="female",
            height_cm=165,
            start_weight_kg=68,
            target_weight_kg=60,
            goal="lose_weight",
            lifestyle="sedentary desk job",
            exercise_frequency_per_week=3,
            exercise_duration_minutes=45,
            exercise_habit=["dancing", "swimming"],
            exercise_location="home",
        ),
        personal_info=PersonalInfoData(
            available_equipment=["dumbbells"],
            posture_issues=[],
            injuries=["mild lower back pain"],
            surgery_history=[],
            exercises_to_avoid=[],
        ),
    )


def _override_auth() -> None:
    app.dependency_overrides[get_current_user] = lambda: AuthUser(
        user_id=USER_ID, email="user@example.com"
    )


class TestGeneratePlan:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_generates_saves_and_returns_plan(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        plan_service = Mock()
        plan_service.save.return_value = ("plan-123", "2026-08-23T00:00:00+00:00")
        workout_service = Mock()
        workout_service.list_recent.return_value = []
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_plan_service] = lambda: plan_service
        app.dependency_overrides[get_workout_service] = lambda: workout_service

        ai_plan = WorkoutPlan(
            planName="Balanced starter plan",
            goal="lose_weight",
            weeklyFrequency=3,
            exercises=[
                Exercise(
                    day="Day 1",
                    exerciseName="Bodyweight Squat",
                    sets=3,
                    reps=12,
                    duration=None,
                    restSeconds=60,
                    reason="Builds lower-body strength safely.",
                    instructions="Stand with feet shoulder-width apart, lower your hips back and down, then push through your heels to stand.",
                    videoUrl=None,
                )
            ],
        )

        with patch("app.routers.ai.generate_workout_plan", return_value=ai_plan) as mock_generate:
            response = TestClient(app).post("/ai/generate-plan")

        assert response.status_code == 201
        body = response.json()
        assert body["planId"] == "plan-123"
        assert body["planName"] == "Balanced starter plan"
        assert body["exercises"][0]["exerciseName"] == "Bodyweight Squat"

        mock_generate.assert_called_once()
        called_profile, called_personal_info = mock_generate.call_args.args
        assert called_profile.startWeightKg == 68
        assert called_profile.exerciseHabit == ["dancing", "swimming"]
        assert called_personal_info.injuries == ["mild lower back pain"]

        # 现在generate_plan会先(best-effort)查一遍Pexels缩略图,把结果一起传给save()
        # 存下来(这样重启后GET /ai/plan读回来的计划也有图,不用再查一次)——沙箱里
        # 出站网络本来就被挡住,所以这里查到的必然是全None,断言的时候不用管具体查到
        # 了什么图,只要确认save()有拿到一个"动作名->url"形状的第三个参数就行。
        plan_service.save.assert_called_once()
        save_args = plan_service.save.call_args.args
        assert save_args[0] == USER_ID
        assert save_args[1] == ai_plan
        assert save_args[2] == {"Bodyweight Squat": None}

    def test_requires_a_saved_profile(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = None
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_plan_service] = lambda: Mock()

        response = TestClient(app).post("/ai/generate-plan")

        assert response.status_code == 404
        assert response.json()["data"]["errorCode"] == "PROFILE_NOT_FOUND"


class TestChat:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_replies_and_saves_the_exchange(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        chat_service = Mock()
        chat_service.get_recent_history.return_value = [
            ChatMessage(role="user", message="Hi"),
            ChatMessage(role="assistant", message="Hello! How can I help?"),
        ]
        weight_service = Mock()
        weight_service.list.return_value = []
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_chat_service] = lambda: chat_service
        app.dependency_overrides[get_weight_service] = lambda: weight_service
        workout_service = Mock()
        workout_service.list_recent.return_value = []
        app.dependency_overrides[get_workout_service] = lambda: workout_service

        with patch("app.routers.ai.generate_chat_reply", return_value="Sure, here's a tip.") as mock_chat:
            response = TestClient(app).post("/ai/chat", json={"message": "Any tips for squats?"})

        assert response.status_code == 200
        assert response.json() == {"reply": "Sure, here's a tip."}

        mock_chat.assert_called_once()
        message_arg, history_arg, profile_arg, personal_info_arg, recent_progress_arg, adherence_arg = mock_chat.call_args.args
        assert adherence_arg is None
        assert message_arg == "Any tips for squats?"
        assert len(history_arg) == 2
        assert profile_arg is not None
        assert personal_info_arg is not None
        # Fewer than 2 weight records this week -> not enough data, so no progress is passed.
        assert recent_progress_arg is None

        chat_service.append_exchange.assert_called_once_with(
            USER_ID, "Any tips for squats?", "Sure, here's a tip."
        )

    def test_works_without_a_saved_profile(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = None
        chat_service = Mock()
        chat_service.get_recent_history.return_value = []
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_chat_service] = lambda: chat_service
        app.dependency_overrides[get_weight_service] = lambda: Mock()
        no_workouts = Mock()
        no_workouts.list_recent.return_value = []
        app.dependency_overrides[get_workout_service] = lambda: no_workouts

        with patch("app.routers.ai.generate_chat_reply", return_value="Happy to help!") as mock_chat:
            response = TestClient(app).post("/ai/chat", json={"message": "What is progressive overload?"})

        assert response.status_code == 200
        _, _, profile_arg, personal_info_arg, recent_progress_arg, _ = mock_chat.call_args.args
        assert profile_arg is None
        assert personal_info_arg is None
        assert recent_progress_arg is None

    def test_includes_recent_progress_when_enough_weight_data(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        chat_service = Mock()
        chat_service.get_recent_history.return_value = []
        weight_service = Mock()
        weight_service.list.return_value = [
            SimpleNamespace(weight_kg=68.0, recorded_at=date.today() - timedelta(days=6)),
            SimpleNamespace(weight_kg=67.2, recorded_at=date.today()),
        ]
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_chat_service] = lambda: chat_service
        app.dependency_overrides[get_weight_service] = lambda: weight_service
        workout_service = Mock()
        workout_service.list_recent.return_value = []
        app.dependency_overrides[get_workout_service] = lambda: workout_service

        with patch("app.routers.ai.generate_chat_reply", return_value="Nice progress!") as mock_chat:
            response = TestClient(app).post("/ai/chat", json={"message": "How am I doing?"})

        assert response.status_code == 200
        _, _, _, _, recent_progress_arg, _ = mock_chat.call_args.args
        assert recent_progress_arg is not None
        assert recent_progress_arg.deltaKg == -0.8


class TestReport:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_saves_and_returns_the_report(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        weight_service = Mock()
        weight_service.list.return_value = []
        report_service = Mock()
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_weight_service] = lambda: weight_service
        app.dependency_overrides[get_report_service] = lambda: report_service

        stats = ReportStats(
            has_enough_data=True,
            start_weight_kg=68.0,
            end_weight_kg=67.2,
            delta_kg=-0.8,
            progress_to_goal_percent=10.0,
            projected_weeks_to_goal=7.7,
        )

        with (
            patch("app.services.ai_bridge.calculate_report_stats", return_value=stats),
            patch("app.routers.ai.generate_report_summary", return_value="Great progress this week!") as mock_summary,
        ):
            response = TestClient(app).post("/ai/report", json={"periodType": "weekly"})

        assert response.status_code == 200
        body = response.json()
        assert body["hasEnoughData"] is True
        assert body["deltaKg"] == -0.8
        assert body["summary"] == "Great progress this week!"

        mock_summary.assert_called_once()
        report_service.save.assert_called_once()
        called_args = report_service.save.call_args.args
        assert called_args[0] == USER_ID
        assert called_args[1] == "weekly"

    def test_requires_a_saved_profile(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = None
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_weight_service] = lambda: Mock()
        app.dependency_overrides[get_report_service] = lambda: Mock()

        response = TestClient(app).post("/ai/report", json={"periodType": "monthly"})

        assert response.status_code == 404
        assert response.json()["data"]["errorCode"] == "PROFILE_NOT_FOUND"


class TestGenerateMealPlan:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def _meal_plan(self) -> MealPlanResponse:
        return MealPlanResponse(
            planName="High-protein starter meals",
            goal="lose_weight",
            dailyCalorieTarget=1600,
            recipes=[
                Recipe(
                    mealType="lunch",
                    recipeName="Egg and spinach scramble",
                    ingredientsUsed=["egg", "spinach"],
                    instructions="Whisk and cook over medium heat.",
                    estimatedCalories=350,
                    estimatedProteinG=24.0,
                    reason="High protein, easy to make with what you have.",
                )
            ],
            adjustmentNote=None,
        )

    def test_without_recent_progress(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_weight_service] = lambda: Mock()

        with patch("app.routers.ai.generate_meal_plan", return_value=self._meal_plan()) as mock_generate:
            response = TestClient(app).post(
                "/ai/generate-meal-plan",
                json={"availableIngredients": ["egg", "spinach"], "dietaryRestrictions": []},
            )

        assert response.status_code == 200
        assert response.json()["recipes"][0]["recipeName"] == "Egg and spinach scramble"

        _, _, _, recent_progress_arg = mock_generate.call_args.args
        assert recent_progress_arg is None

    def test_includes_recent_progress_when_requested(self) -> None:
        _override_auth()
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        weight_service = Mock()
        weight_service.list.return_value = []
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_weight_service] = lambda: weight_service

        stats = ReportStats(
            has_enough_data=True,
            start_weight_kg=68.0,
            end_weight_kg=68.1,
            delta_kg=0.1,
            progress_to_goal_percent=12.0,
            projected_weeks_to_goal=None,
        )

        with (
            patch("app.services.ai_bridge.calculate_report_stats", return_value=stats),
            patch("app.routers.ai.generate_meal_plan", return_value=self._meal_plan()) as mock_generate,
        ):
            response = TestClient(app).post(
                "/ai/generate-meal-plan",
                json={"includeRecentProgress": True},
            )

        assert response.status_code == 200
        _, _, _, recent_progress_arg = mock_generate.call_args.args
        assert recent_progress_arg is not None
        assert recent_progress_arg.deltaKg == 0.1
        assert recent_progress_arg.progressToGoalPercent == 12.0
