from datetime import date
from uuid import UUID

from pydantic import Field

from app.schemas.base import APIModel


class WeightRecordCreate(APIModel):
    weight_kg: float = Field(gt=0, le=1000)
    recorded_at: date


class WeightRecordResponse(WeightRecordCreate):
    weight_log_id: UUID
