from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.schemas.auth import AuthUser
from app.schemas.user import PersonalInfoData, ProfileData, UserProfileResponse
from app.services.ai.models import DetectedIngredient, EquipmentIdentifyResponse, IngredientIdentifyResponse
from app.services.profile_service import get_profile_service
from app.services.scan_service import get_equipment_scan_service
from app.services.storage_service import StorageService, get_storage_service


USER_ID = "11111111-1111-1111-1111-111111111111"
FAKE_IMAGE_BYTES = b"\xff\xd8\xff\xe0fake-jpeg-bytes"
PUBLIC_URL = "https://xxx.supabase.co/storage/v1/object/public/scans/fake.jpg"


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
            exercise_habit=[],
            exercise_location="home",
        ),
        personal_info=PersonalInfoData(),
    )


def _override_auth() -> None:
    app.dependency_overrides[get_current_user] = lambda: AuthUser(
        user_id=USER_ID, email="user@example.com"
    )


class TestEquipmentScan:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_uploads_identifies_and_saves(self) -> None:
        _override_auth()
        storage_service = Mock()
        storage_service.upload_image.return_value = PUBLIC_URL
        profile_service = Mock()
        profile_service.get.return_value = _profile_response()
        scan_service = Mock()
        app.dependency_overrides[get_storage_service] = lambda: storage_service
        app.dependency_overrides[get_profile_service] = lambda: profile_service
        app.dependency_overrides[get_equipment_scan_service] = lambda: scan_service

        ai_result = EquipmentIdentifyResponse(
            recognized=True,
            confidence=0.92,
            equipmentName="Resistance Band",
            description="A stretchy band for strength training.",
            targetMuscles=["Glutes"],
            usageInstructions="Loop it around your legs.",
            safetyNotes="Check for tears before use.",
            personalizedWarning=None,
            notRecognizedMessage=None,
        )

        with patch("app.routers.scans.identify_equipment", return_value=ai_result) as mock_identify:
            response = TestClient(app).post(
                "/equipment/scan",
                files={"image": ("band.jpg", FAKE_IMAGE_BYTES, "image/jpeg")},
            )

        assert response.status_code == 200
        body = response.json()
        assert body["equipmentName"] == "Resistance Band"
        assert body["recognized"] is True

        storage_service.upload_image.assert_called_once()
        called_user_id = storage_service.upload_image.call_args.args[0]
        assert called_user_id == USER_ID

        mock_identify.assert_called_once()
        assert mock_identify.call_args.args[0] == PUBLIC_URL

        scan_service.save.assert_called_once_with(USER_ID, PUBLIC_URL, ai_result)

    def test_rejects_unsupported_image_type(self) -> None:
        _override_auth()
        # Use a real StorageService (with a mocked Supabase client underneath) so the
        # content-type validation in upload_image actually runs instead of being
        # short-circuited by a bare Mock.
        app.dependency_overrides[get_storage_service] = lambda: StorageService(Mock(), "scans")
        app.dependency_overrides[get_profile_service] = lambda: Mock()
        app.dependency_overrides[get_equipment_scan_service] = lambda: Mock()

        response = TestClient(app).post(
            "/equipment/scan",
            files={"image": ("notes.txt", b"hello", "text/plain")},
        )

        assert response.status_code == 400
        assert response.json()["data"]["errorCode"] == "UNSUPPORTED_IMAGE_TYPE"


class TestIngredientScan:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_uploads_and_identifies_without_persisting(self) -> None:
        _override_auth()
        storage_service = Mock()
        storage_service.upload_image.return_value = PUBLIC_URL
        app.dependency_overrides[get_storage_service] = lambda: storage_service

        ai_result = IngredientIdentifyResponse(
            recognized=True,
            confidence=0.85,
            ingredients=[DetectedIngredient(name="egg", quantity="6")],
            notRecognizedMessage=None,
        )

        with patch("app.routers.scans.identify_ingredients", return_value=ai_result) as mock_identify:
            response = TestClient(app).post(
                "/ingredients/scan",
                files={"image": ("fridge.jpg", FAKE_IMAGE_BYTES, "image/jpeg")},
            )

        assert response.status_code == 200
        body = response.json()
        assert body["ingredients"][0]["name"] == "egg"
        mock_identify.assert_called_once_with(PUBLIC_URL)
