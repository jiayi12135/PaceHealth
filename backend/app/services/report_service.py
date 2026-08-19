from datetime import date
from typing import Annotated, Literal

from fastapi import Depends
from supabase import Client

from app.services.ai.report_calculator import ReportStats
from app.services.supabase_client import get_supabase_client


class ReportService:
    """Persistence for reports, populated by POST /ai/report (Decision 3 & 5 in
    docs/DATABASE_SCHEMA_GUIDE.md: reports are saved for history, not just returned)."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def save(
        self,
        user_id: str,
        period_type: Literal["weekly", "monthly"],
        period_start: date,
        period_end: date,
        stats: ReportStats,
        summary: str,
    ) -> None:
        self.client.table("reports").insert(
            {
                "user_id": user_id,
                "period_type": period_type,
                "period_start": period_start.isoformat(),
                "period_end": period_end.isoformat(),
                # Numeric fields are all-or-nothing None when hasEnoughData is False;
                # the reports table allows null here (only `summary` is not-null).
                "start_weight_kg": stats.start_weight_kg,
                "end_weight_kg": stats.end_weight_kg,
                "delta_kg": stats.delta_kg,
                "progress_to_goal_percent": stats.progress_to_goal_percent,
                "projected_weeks_to_goal": stats.projected_weeks_to_goal,
                "summary": summary,
            }
        ).execute()


def get_report_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> ReportService:
    return ReportService(client)
