from datetime import date, datetime, time, timedelta, timezone
from typing import Annotated, Any

from fastapi import Depends
from supabase import Client

from app.services.ai.models import FoodScanResult
from app.services.supabase_client import get_supabase_client


class FoodScanService:
    """Persistence for food_scans, populated by POST /food/scan. Used by the
    Nutrition tab to show today's logged food and running calorie total."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def save(self, user_id: str, image_url: str, result: FoodScanResult) -> dict[str, Any]:
        row = (
            self.client.table("food_scans")
            .insert(
                {
                    "user_id": user_id,
                    "image_url": image_url,
                    "food_name": result.foodName,
                    "confidence": result.confidence,
                    "estimated_calories": result.estimatedCalories,
                    "estimated_protein_g": result.estimatedProteinG,
                    "estimated_carbs_g": result.estimatedCarbsG,
                    "estimated_fat_g": result.estimatedFatG,
                    # Store the whole structured response so the app can show the full
                    # detail (description/portionEstimate/notRecognizedMessage) for a
                    # past scan without re-calling Claude, same pattern as equipment_scans.
                    "ai_result": result.model_dump(),
                }
            )
            .execute()
        )
        return row.data[0]

    def list_for_day(self, user_id: str, day: date | None = None) -> list[dict[str, Any]]:
        """Scans created on the given UTC calendar day (defaults to today), newest first."""
        target_day = day or datetime.now(timezone.utc).date()
        start = datetime.combine(target_day, time.min, tzinfo=timezone.utc)
        end = start + timedelta(days=1)
        result = (
            self.client.table("food_scans")
            .select("*")
            .eq("user_id", user_id)
            .gte("created_at", start.isoformat())
            .lt("created_at", end.isoformat())
            .order("created_at", desc=True)
            .execute()
        )
        return result.data


def get_food_scan_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> FoodScanService:
    return FoodScanService(client)
