from datetime import datetime
from uuid import UUID
from pydantic import BaseModel


class ActiveSessionSchema(BaseModel):
    id: UUID
    started_at: datetime
    ended_at: datetime | None
    question_id: UUID
    language: str
    matched_user_id: UUID


class SessionHistorySchema(ActiveSessionSchema):
    question_title: str
    question_statement_md: str
    topics: list[str]
    difficulty: str
    company_tags: list[str]
