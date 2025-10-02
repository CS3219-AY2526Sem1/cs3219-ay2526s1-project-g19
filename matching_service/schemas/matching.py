from enum import StrEnum
from typing import Self
from uuid import UUID
from pydantic import BaseModel, model_validator


class MatchingCriteriaSchema(BaseModel):
    topics: list[str]
    difficulty: list[str]
    primary_lang: str | None = None
    secondary_lang: list[str] = []
    proficiency: int = 0


class MatchUserRequestSchema(BaseModel):
    user_id: UUID
    criteria: MatchingCriteriaSchema


class MatchingStatus(StrEnum):
    SUCCESS = "success"
    TIMEOUT = "timeout"


class MatchedCriteriaSchema(BaseModel):
    topic: str
    difficulty: str
    language: str = ""


class MatchingEventMessage(BaseModel):
    status: MatchingStatus
    matched_user_id: UUID | None
    criteria: MatchedCriteriaSchema | None

    @model_validator(mode="after")
    def check_success(self) -> Self:
        if self.status == MatchingStatus.SUCCESS:
            if self.matched_user_id == None or self.criteria == None:
                raise ValueError(f"Success status message must have matched user id and criteria")
        return self

    @model_validator(mode="after")
    def check_timeout(self) -> Self:
        if self.status == MatchingStatus.TIMEOUT:
            if self.matched_user_id or self.criteria:
                raise ValueError(f"Timeout status message cannot have matched user id or criteria")
        return self
