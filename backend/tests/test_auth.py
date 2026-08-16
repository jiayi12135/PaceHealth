from types import SimpleNamespace
from unittest.mock import Mock

from fastapi.testclient import TestClient
from supabase_auth.errors import AuthApiError

from app.main import app
from app.services.supabase_client import get_supabase_client


def _auth_response(*, session: bool = True) -> SimpleNamespace:
    return SimpleNamespace(
        user=SimpleNamespace(id="11111111-1111-1111-1111-111111111111", email="user@example.com"),
        session=(
            SimpleNamespace(access_token="access-token", refresh_token="refresh-token")
            if session
            else None
        ),
    )


def test_register_returns_user_and_confirmation_state() -> None:
    supabase = Mock()
    supabase.auth.sign_up.return_value = _auth_response(session=False)
    app.dependency_overrides[get_supabase_client] = lambda: supabase

    try:
        response = TestClient(app).post(
            "/auth/register",
            json={"email": "user@example.com", "password": "secure-password"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json() == {
        "accessToken": None,
        "refreshToken": None,
        "emailConfirmationRequired": True,
        "user": {
            "userId": "11111111-1111-1111-1111-111111111111",
            "email": "user@example.com",
        },
    }


def test_login_returns_session_tokens() -> None:
    supabase = Mock()
    supabase.auth.sign_in_with_password.return_value = _auth_response()
    app.dependency_overrides[get_supabase_client] = lambda: supabase

    try:
        response = TestClient(app).post(
            "/auth/login",
            json={"email": "user@example.com", "password": "secure-password"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["accessToken"] == "access-token"
    assert response.json()["refreshToken"] == "refresh-token"
    assert response.json()["emailConfirmationRequired"] is False


def test_login_returns_stable_error_for_invalid_credentials() -> None:
    supabase = Mock()
    supabase.auth.sign_in_with_password.side_effect = AuthApiError(
        "Invalid login credentials", 400, None
    )
    app.dependency_overrides[get_supabase_client] = lambda: supabase

    try:
        response = TestClient(app).post(
            "/auth/login",
            json={"email": "user@example.com", "password": "wrong-password"},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 401
    assert response.json() == {
        "success": False,
        "message": "Email or password is incorrect.",
        "data": {"errorCode": "INVALID_CREDENTIALS"},
    }


def test_auth_rejects_invalid_input() -> None:
    response = TestClient(app).post(
        "/auth/login",
        json={"email": "not-an-email", "password": "short"},
    )

    assert response.status_code == 422
