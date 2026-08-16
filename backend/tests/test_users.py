from unittest.mock import Mock

from fastapi.testclient import TestClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.schemas.auth import AuthUser
from app.schemas.user import PersonalInfoData, ProfileData, UserProfileResponse
from app.services.profile_service import get_profile_service


USER_ID = "11111111-1111-1111-1111-111111111111"
PROFILE_JSON = {
    "profile": {
        "name": "Test User",
        "age": 28,
        "sex": "female",
        "heightCm": 165,
        "currentWeightKg": 68,
        "targetWeightKg": 60,
        "goal": "lose_weight",
        "lifestyle": "sedentary desk job",
        "exerciseFrequencyPerWeek": 3,
        "exerciseDurationMinutes": 45,
        "exerciseLocation": "home",
    },
    "personalInfo": {
        "availableEquipment": ["dumbbells"],
        "postureIssues": [],
        "injuries": [],
        "surgeryHistory": [],
        "exercisesToAvoid": [],
    },
}


def _profile_response() -> UserProfileResponse:
    return UserProfileResponse(
        user_id=USER_ID,
        profile=ProfileData.model_validate(PROFILE_JSON["profile"]),
        personal_info=PersonalInfoData.model_validate(PROFILE_JSON["personalInfo"]),
    )


def _override_dependencies(profile_service: Mock) -> None:
    app.dependency_overrides[get_current_user] = lambda: AuthUser(
        user_id=USER_ID, email="user@example.com"
    )
    app.dependency_overrides[get_profile_service] = lambda: profile_service


def test_get_my_profile_returns_saved_data() -> None:
    profile_service = Mock()
    profile_service.get.return_value = _profile_response()
    _override_dependencies(profile_service)

    try:
        response = TestClient(app).get("/users/me")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["userId"] == USER_ID
    assert response.json()["profile"]["currentWeightKg"] == 68
    profile_service.get.assert_called_once_with(USER_ID)


def test_get_my_profile_returns_not_found() -> None:
    profile_service = Mock()
    profile_service.get.return_value = None
    _override_dependencies(profile_service)

    try:
        response = TestClient(app).get("/users/me")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json()["data"]["errorCode"] == "PROFILE_NOT_FOUND"


def test_put_my_profile_saves_authenticated_user() -> None:
    profile_service = Mock()
    profile_service.upsert.return_value = _profile_response()
    _override_dependencies(profile_service)

    try:
        response = TestClient(app).put("/users/me", json=PROFILE_JSON)
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["personalInfo"]["availableEquipment"] == ["dumbbells"]
    called_user_id, payload = profile_service.upsert.call_args.args
    assert called_user_id == USER_ID
    assert payload.profile.goal == "lose_weight"


def test_put_my_profile_validates_payload() -> None:
    profile_service = Mock()
    _override_dependencies(profile_service)
    invalid_payload = {**PROFILE_JSON, "profile": {**PROFILE_JSON["profile"], "age": 5}}

    try:
        response = TestClient(app).put("/users/me", json=invalid_payload)
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    profile_service.upsert.assert_not_called()
