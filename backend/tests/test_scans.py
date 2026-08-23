from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

from app.dependencies.auth import get_current_user
from app.main import app
from app.schemas.auth import AuthUser
from app.schemas.user import PersonalInfoData, ProfileData, UserProfileResponse
from app.services.ai.models import DetectedIngredient, EquipmentIdentifyResponse, FoodScanResult, IngredientIdentifyResponse
from app.services.food_scan_service import get_food_scan_service
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


class TestFoodScan:
    def teardown_method(self) -> None:
        app.dependency_overrides.clear()

    def test_uploads_estimates_and_saves(self) -> None:
        _override_auth()
        storage_service = Mock()
        storage_service.upload_image.return_value = PUBLIC_URL
        scan_service = Mock()
        scan_service.save.return_value = {"id": "scan-1", "created_at": "2026-08-21T10:00:00+00:00"}
        app.dependency_overrides[get_storage_service] = lambda: storage_service
        app.dependency_overrides[get_food_scan_service] = lambda: scan_service

        ai_result = FoodScanResult(
            recognized=True,
            confidence=0.8,
            foodName="Chicken salad bowl",
            description="Grilled chicken over greens.",
            portionEstimate="One medium bowl, ~350g",
            estimatedCalories=420,
            estimatedProteinG=35.0,
            estimatedCarbsG=20.0,
            estimatedFatG=18.0,
            notRecognizedMessage=None,
        )

        with patch("app.routers.scans.estimate_food", return_value=ai_result) as mock_estimate:
            response = TestClient(app).post(
                "/food/scan",
                files={"image": ("lunch.jpg", FAKE_IMAGE_BYTES, "image/jpeg")},
            )

        assert response.status_code == 200
        body = response.json()
        assert body["foodName"] == "Chicken salad bowl"
        assert body["estimatedCalories"] == 420
        assert body["scanId"] == "scan-1"

        mock_estimate.assert_called_once_with(PUBLIC_URL)
        scan_service.save.assert_called_once_with(USER_ID, PUBLIC_URL, ai_result)

    def test_deletes_a_scan(self) -> None:
        _override_auth()
        scan_service = Mock()
        scan_service.delete.return_value = True
        app.dependency_overrides[get_food_scan_service] = lambda: scan_service

        response = TestClient(app).delete("/food/scans/scan-1")

        assert response.status_code == 204
        scan_service.delete.assert_called_once_with(USER_ID, "scan-1")

    def test_deleting_a_missing_scan_returns_404(self) -> None:
        _override_auth()
        scan_service = Mock()
        scan_service.delete.return_value = False
        app.dependency_overrides[get_food_scan_service] = lambda: scan_service

        response = TestClient(app).delete("/food/scans/does-not-exist")

        assert response.status_code == 404
        assert response.json()["data"]["errorCode"] == "SCAN_NOT_FOUND"

    def test_today_log_sums_calories(self) -> None:
        _override_auth()
        scan_service = Mock()
        scan_service.list_for_day.return_value = [
            {
                "id": "scan-1",
                "food_name": "Oatmeal",
                "confidence": 0.9,
                "estimated_calories": 300,
                "estimated_protein_g": 10.0,
                "estimated_carbs_g": 50.0,
                "estimated_fat_g": 5.0,
                "ai_result": {"description": "Bowl of oatmeal", "portionEstimate": "1 bowl", "notRecognizedMessage": None},
                "created_at": "2026-08-21T08:00:00+00:00",
            },
            {
                "id": "scan-2",
                "food_name": "Salad",
                "confidence": 0.85,
                "estimated_calories": 250,
                "estimated_protein_g": 8.0,
                "estimated_carbs_g": 20.0,
                "estimated_fat_g": 10.0,
                "ai_result": {"description": "Green salad", "portionEstimate": "1 plate", "notRecognizedMessage": None},
                "created_at": "2026-08-21T12:00:00+00:00",
            },
        ]
        app.dependency_overrides[get_food_scan_service] = lambda: scan_service

        response = TestClient(app).get("/food/scans/today")

        assert response.status_code == 200
        body = response.json()
        assert body["totalCalories"] == 550
        assert len(body["scans"]) == 2
