from datetime import date
from typing import Annotated, Any
from uuid import UUID

from fastapi import Depends
from supabase import Client

from app.schemas.weight import WeightRecordCreate, WeightRecordResponse
from app.services.supabase_client import get_supabase_client


class WeightService:
    """Persistence operations for authenticated users' weight records."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def create(
        self, user_id: str, payload: WeightRecordCreate
    ) -> WeightRecordResponse:
        result = (
            self.client.table("weight_records")
            .insert(
                {
                    "user_id": user_id,
                    "weight_kg": payload.weight_kg,
                    "recorded_at": payload.recorded_at.isoformat(),
                }
            )
            .execute()
        )
        return self._from_row(result.data[0])

    def list(
        self,
        user_id: str,
        from_date: date | None = None,
        to_date: date | None = None,
    ) -> list[WeightRecordResponse]:
        query = (
            self.client.table("weight_records")
            .select("id,weight_kg,recorded_at")
            .eq("user_id", user_id)
        )
        if from_date is not None:
            query = query.gte("recorded_at", from_date.isoformat())
        if to_date is not None:
            query = query.lte("recorded_at", to_date.isoformat())

        result = query.order("recorded_at").execute()
        return [self._from_row(row) for row in result.data]

    def delete(self, user_id: str, weight_log_id: UUID) -> bool:
        result = (
            self.client.table("weight_records")
            .delete()
            .eq("id", str(weight_log_id))
            .eq("user_id", user_id)
            .execute()
        )
        return bool(result.data)

    @staticmethod
    def _from_row(row: dict[str, Any]) -> WeightRecordResponse:
        return WeightRecordResponse(
            weight_log_id=row["id"],
            weight_kg=row["weight_kg"],
            recorded_at=row["recorded_at"],
        )


def get_weight_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> WeightService:
    return WeightService(client)
