from datetime import datetime
from uuid import UUID
from pydantic import BaseModel


class QuestionChosen(BaseModel):
    match_id: UUID
    user_id_list: list[UUID]
    question_id: UUID
    title: str
    statement_md: str
    assets: list[str]
    topics: list[str]
    difficulty: str
    language: str
    company_tags: list[str]
    examples: list[str]
    constraints: list[str]
    timestamp: datetime

    class Config:
        json_encoders = {
            UUID: lambda v: str(v),
            datetime: lambda v: int(v.timestamp() * 1000),  # milliseconds
        }


class SessionCreated(QuestionChosen):
    session_id: UUID
    started_at: datetime


class SessionEnd(BaseModel):
    session_id: UUID
    ended_at: datetime
    timestamp: datetime

    class Config:
        json_encoders = {
            UUID: lambda v: str(v),
            datetime: lambda v: int(v.timestamp() * 1000),  # milliseconds
        }
