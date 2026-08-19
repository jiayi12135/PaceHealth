from typing import Annotated

from fastapi import Depends
from supabase import Client

from app.services.ai.models import EquipmentIdentifyResponse
from app.services.supabase_client import get_supabase_client


class EquipmentScanService:
    """Persistence for equipment_scans, populated by POST /equipment/scan."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def save(self, user_id: str, image_url: str, result: EquipmentIdentifyResponse) -> None:
        self.client.table("equipment_scans").insert(
            {
                "user_id": user_id,
                "image_url": image_url,
                "equipment_name": result.equipmentName,
                "confidence": result.confidence,
                # Store the whole structured response so we can replay/debug past
                # scans without re-calling Claude, per docs/DATABASE_SCHEMA_GUIDE.md.
                "ai_result": result.model_dump(),
            }
        ).execute()


def get_equipment_scan_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> EquipmentScanService:
    return EquipmentScanService(client)
