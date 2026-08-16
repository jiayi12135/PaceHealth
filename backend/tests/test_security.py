from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from fastapi.security import HTTPAuthorizationCredentials
from supabase_auth.errors import AuthApiError

from app.dependencies.auth import get_current_user
from app.errors import APIError


def test_get_current_user_accepts_valid_bearer_token() -> None:
    client = Mock()
    client.auth.get_user.return_value = SimpleNamespace(
        user=SimpleNamespace(
            id="11111111-1111-1111-1111-111111111111",
            email="user@example.com",
        )
    )

    user = get_current_user(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials="valid-token"),
        client,
    )

    assert user.user_id == "11111111-1111-1111-1111-111111111111"
    client.auth.get_user.assert_called_once_with("valid-token")


def test_get_current_user_rejects_missing_token() -> None:
    with pytest.raises(APIError) as error:
        get_current_user(None, Mock())

    assert error.value.status_code == 401
    assert error.value.error_code == "AUTHENTICATION_REQUIRED"


def test_get_current_user_rejects_invalid_token() -> None:
    client = Mock()
    client.auth.get_user.side_effect = AuthApiError("invalid token", 401, None)

    with pytest.raises(APIError) as error:
        get_current_user(
            HTTPAuthorizationCredentials(scheme="Bearer", credentials="invalid-token"),
            client,
        )

    assert error.value.status_code == 401
    assert error.value.error_code == "INVALID_ACCESS_TOKEN"
