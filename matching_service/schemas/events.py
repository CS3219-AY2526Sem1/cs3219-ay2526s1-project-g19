from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, field_validator


class MatchFoundSchema(BaseModel):
    match_id: UUID
    user_id_list: list[UUID]
    topic: str
    difficulty: str
    language: str
    timestamp: datetime

    class Config:
        json_encoders = {
            UUID: lambda v: str(v),
            datetime: lambda v: int(v.timestamp() * 1000),  # milliseconds
        }

    @field_validator("user_id_list", mode="after")
    @classmethod
    def validate_user_id_list_len(cls, value: list[UUID]) -> list[UUID]:
        if len(value) != 2:
            raise ValueError(f"user_id_list must have 2 items: {value}")
        return value


class SessionCreatedSchema(BaseModel):
    session_id: UUID
    started_at: datetime
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
