from typing import Annotated

from fastapi import Depends
from supabase import Client

from app.services.ai.models import ChatMessage
from app.services.supabase_client import get_supabase_client


# /ai/chat itself is stateless (see app/services/ai/router notes carried over from
# Stephanie's ai-service) — the backend is responsible for storing chat_records and
# replaying history on every call. Cap how much history we replay so a long-running
# conversation doesn't silently blow up the AI request's token usage/cost.
CHAT_HISTORY_LIMIT = 40


class ChatService:
    """Persistence for chat_records, backing the stateless AI chat call."""

    def __init__(self, client: Client) -> None:
        self.client = client

    def get_recent_history(self, user_id: str) -> list[ChatMessage]:
        result = (
            self.client.table("chat_records")
            .select("role,message,created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(CHAT_HISTORY_LIMIT)
            .execute()
        )
        chronological_rows = list(reversed(result.data))
        return [ChatMessage(role=row["role"], message=row["message"]) for row in chronological_rows]

    def append_exchange(self, user_id: str, user_message: str, assistant_reply: str) -> None:
        """Save both sides of the exchange. Two separate rows (not one), matching the
        chat_records schema (one row per message, role in {'user','assistant'})."""
        self.client.table("chat_records").insert(
            [
                {"user_id": user_id, "role": "user", "message": user_message},
                {"user_id": user_id, "role": "assistant", "message": assistant_reply},
            ]
        ).execute()


def get_chat_service(
    client: Annotated[Client, Depends(get_supabase_client)],
) -> ChatService:
    return ChatService(client)
