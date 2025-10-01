from uuid import UUID
from pydantic import BaseModel


class MatchingCriteriaSchema(BaseModel):
    topics: list[str]
    difficulty: list[str]
    primary_lang: str | None = None
    secondary_lang: list[str] = []
    proficiency: int = 0


class MatchUserRequestSchema(BaseModel):
    user_id: UUID
    criteria: MatchingCriteriaSchema
