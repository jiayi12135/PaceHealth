"""Photo-upload endpoints. These exist because Claude's vision API reads images
by public URL, not raw bytes — Flutter uploads the photo here, the backend
pushes it to Supabase Storage (using its own service-role credentials, which
Flutter must never hold, per docs/DATABASE_SCHEMA_GUIDE.md's security design),
and only then calls the AI service with the resulting URL.
"""

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, UploadFile, status
from postgrest.exceptions import APIError as PostgrestAPIError

from app.dependencies.auth import get_current_user
from app.errors import APIError
from app.schemas.ai import DailyFoodLogResponse, EquipmentScanResponse, FoodScanResponse, IngredientScanResponse
from app.schemas.auth import AuthUser
from app.services.ai.claude_client import estimate_food, identify_equipment, identify_ingredients
from app.services.ai_bridge import (
    to_ai_personal_info,
    to_equipment_scan_response,
    to_food_scan_response,
    to_ingredient_scan_response,
)
from app.services.ai.models import FoodScanResult
from app.services.food_scan_service import FoodScanService, get_food_scan_service
from app.services.profile_service import ProfileService, get_profile_service
from app.services.scan_service import EquipmentScanService, get_equipment_scan_service
from app.services.storage_service import StorageService, UnsupportedImageTypeError, get_storage_service


router = APIRouter(tags=["scans"])

# Guard against accidentally-huge uploads before they ever reach Supabase Storage
# or get billed as an AI vision call. 8 MB comfortably covers a phone camera photo.
MAX_IMAGE_BYTES = 8 * 1024 * 1024


async def _read_and_upload_image(
    image: UploadFile,
    storage: StorageService,
    user_id: str,
) -> str:
    file_bytes = await image.read()
    if not file_bytes:
        raise APIError(400, "The uploaded image is empty.", "EMPTY_IMAGE")
    if len(file_bytes) > MAX_IMAGE_BYTES:
        raise APIError(400, "The uploaded image is too large (max 8 MB).", "IMAGE_TOO_LARGE")

    try:
        return storage.upload_image(user_id, file_bytes, image.content_type)
    except UnsupportedImageTypeError as exc:
        raise APIError(
            400,
            "Unsupported image type. Use JPEG, PNG, WEBP, or HEIC.",
            "UNSUPPORTED_IMAGE_TYPE",
        ) from exc
    except PostgrestAPIError as exc:
        raise APIError(502, "Failed to upload the image.", "IMAGE_UPLOAD_FAILED") from exc


@router.post("/equipment/scan", response_model=EquipmentScanResponse)
async def scan_equipment(
    image: UploadFile,
    user: Annotated[AuthUser, Depends(get_current_user)],
    storage: Annotated[StorageService, Depends(get_storage_service)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
    scans: Annotated[EquipmentScanService, Depends(get_equipment_scan_service)],
) -> EquipmentScanResponse:
    image_url = await _read_and_upload_image(image, storage, user.user_id)

    try:
        profile = profiles.get(user.user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load the profile.", "PROFILE_READ_FAILED") from exc

    try:
        result = identify_equipment(
            image_url,
            to_ai_personal_info(profile.personal_info) if profile else None,
        )
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "The AI service failed to identify the equipment.", "AI_REQUEST_FAILED") from exc

    try:
        scans.save(user.user_id, image_url, result)
    except PostgrestAPIError as exc:
        raise APIError(502, "Identified the equipment but failed to save the scan.", "SCAN_WRITE_FAILED") from exc

    return to_equipment_scan_response(result)


@router.post("/ingredients/scan", response_model=IngredientScanResponse)
async def scan_ingredients(
    image: UploadFile,
    user: Annotated[AuthUser, Depends(get_current_user)],
    storage: Annotated[StorageService, Depends(get_storage_service)],
) -> IngredientScanResponse:
    # Not persisted to a table yet — see Decision 8 in docs/DATABASE_SCHEMA_GUIDE.md.
    # The result is meant to feed straight into POST /ai/generate-meal-plan.
    image_url = await _read_and_upload_image(image, storage, user.user_id)

    try:
        result = identify_ingredients(image_url)
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "The AI service failed to identify the ingredients.", "AI_REQUEST_FAILED") from exc

    return to_ingredient_scan_response(result)


@router.post("/food/scan", response_model=FoodScanResponse)
async def scan_food(
    image: UploadFile,
    user: Annotated[AuthUser, Depends(get_current_user)],
    storage: Annotated[StorageService, Depends(get_storage_service)],
    scans: Annotated[FoodScanService, Depends(get_food_scan_service)],
) -> FoodScanResponse:
    """Photo of a meal -> estimated calories/macros, logged for the Nutrition tab."""
    image_url = await _read_and_upload_image(image, storage, user.user_id)

    try:
        result: FoodScanResult = estimate_food(image_url)
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "The AI service failed to estimate this food scan.", "AI_REQUEST_FAILED") from exc

    try:
        row = scans.save(user.user_id, image_url, result)
    except PostgrestAPIError as exc:
        raise APIError(502, "Estimated the food but failed to save the scan.", "SCAN_WRITE_FAILED") from exc

    return to_food_scan_response(result, scan_id=row["id"], scanned_at=row["created_at"])


@router.delete("/food/scans/{scan_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_food_scan(
    scan_id: str,
    user: Annotated[AuthUser, Depends(get_current_user)],
    scans: Annotated[FoodScanService, Depends(get_food_scan_service)],
) -> None:
    """Lets the user remove a mis-scanned or duplicate entry from today's log."""
    try:
        deleted = scans.delete(user.user_id, scan_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to delete this scan.", "SCAN_DELETE_FAILED") from exc

    if not deleted:
        raise APIError(404, "Scan not found.", "SCAN_NOT_FOUND")


@router.get("/food/scans/today", response_model=DailyFoodLogResponse)
def get_today_food_log(
    user: Annotated[AuthUser, Depends(get_current_user)],
    scans: Annotated[FoodScanService, Depends(get_food_scan_service)],
) -> DailyFoodLogResponse:
    """Today's logged food scans + running calorie total, for the Nutrition tab."""
    try:
        rows = scans.list_for_day(user.user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load today's food log.", "FOOD_LOG_READ_FAILED") from exc

    responses = [
        FoodScanResponse(
            scan_id=row["id"],
            recognized=row["food_name"] is not None,
            confidence=row["confidence"] or 0.0,
            food_name=row["food_name"],
            description=(row.get("ai_result") or {}).get("description"),
            portion_estimate=(row.get("ai_result") or {}).get("portionEstimate"),
            estimated_calories=row["estimated_calories"],
            estimated_protein_g=row["estimated_protein_g"],
            estimated_carbs_g=row["estimated_carbs_g"],
            estimated_fat_g=row["estimated_fat_g"],
            not_recognized_message=(row.get("ai_result") or {}).get("notRecognizedMessage"),
            scanned_at=row["created_at"],
        )
        for row in rows
    ]
    total_calories = sum(r.estimated_calories or 0 for r in responses)

    return DailyFoodLogResponse(
        date=datetime.now(timezone.utc).date().isoformat(),
        total_calories=total_calories,
        scans=responses,
    )
