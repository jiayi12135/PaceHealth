from datetime import date
from unittest.mock import Mock
from uuid import UUID

from fastapi.testclient import TestClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.schemas.auth import AuthUser
from app.schemas.weight import WeightRecordResponse
from app.services.weight_service import get_weight_service


USER_ID = "11111111-1111-1111-1111-111111111111"
WEIGHT_LOG_ID = UUID("22222222-2222-2222-2222-222222222222")


def _weight_response() -> WeightRecordResponse:
    return WeightRecordResponse(
        weight_log_id=WEIGHT_LOG_ID,
        weight_kg=67.2,
        recorded_at=date(2026, 8, 14),
    )


def _override_dependencies(weight_service: Mock) -> None:
    app.dependency_overrides[get_current_user] = lambda: AuthUser(
        user_id=USER_ID, email="user@example.com"
    )
    app.dependency_overrides[get_weight_service] = lambda: weight_service


def test_create_weight_record_uses_authenticated_user() -> None:
    weight_service = Mock()
    weight_service.create.return_value = _weight_response()
    _override_dependencies(weight_service)

    try:
        response = TestClient(app).post(
            "/weights",
            json={"weightKg": 67.2, "recordedAt": "2026-08-14"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json() == {
        "weightKg": 67.2,
        "recordedAt": "2026-08-14",
        "weightLogId": str(WEIGHT_LOG_ID),
    }
    called_user_id, payload = weight_service.create.call_args.args
    assert called_user_id == USER_ID
    assert payload.recorded_at == date(2026, 8, 14)


def test_list_weight_records_passes_date_range() -> None:
    weight_service = Mock()
    weight_service.list.return_value = [_weight_response()]
    _override_dependencies(weight_service)

    try:
        response = TestClient(app).get(
            "/weights?from=2026-08-01&to=2026-08-31"
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()[0]["weightLogId"] == str(WEIGHT_LOG_ID)
    weight_service.list.assert_called_once_with(
        USER_ID, date(2026, 8, 1), date(2026, 8, 31)
    )


def test_list_weight_records_rejects_reverse_date_range() -> None:
    weight_service = Mock()
    _override_dependencies(weight_service)

    try:
        response = TestClient(app).get(
            "/weights?from=2026-08-31&to=2026-08-01"
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 400
    assert response.json()["data"]["errorCode"] == "INVALID_DATE_RANGE"
    weight_service.list.assert_not_called()


def test_delete_weight_record_returns_no_content() -> None:
    weight_service = Mock()
    weight_service.delete.return_value = True
    _override_dependencies(weight_service)

    try:
        response = TestClient(app).delete(f"/weights/{WEIGHT_LOG_ID}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 204
    weight_service.delete.assert_called_once_with(USER_ID, WEIGHT_LOG_ID)


def test_delete_weight_record_returns_not_found() -> None:
    weight_service = Mock()
    weight_service.delete.return_value = False
    _override_dependencies(weight_service)

    try:
        response = TestClient(app).delete(f"/weights/{WEIGHT_LOG_ID}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json()["data"]["errorCode"] == "WEIGHT_NOT_FOUND"


def test_create_weight_record_validates_weight() -> None:
    weight_service = Mock()
    _override_dependencies(weight_service)

    try:
        response = TestClient(app).post(
            "/weights",
            json={"weightKg": -1, "recordedAt": "2026-08-14"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    weight_service.create.assert_not_called()
