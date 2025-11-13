from enum import StrEnum
from typing import Self
from uuid import UUID

from pydantic import BaseModel, model_validator

from schemas.events import SessionCreatedSchema


class MatchingStatus(StrEnum):
    SUCCESS = "success"
    TIMEOUT = "timeout"
    RELAX_LANGUAGE = "relax"


class MatchingEventMessage(BaseModel):
    status: MatchingStatus
    session: SessionCreatedSchema | None = None

    @model_validator(mode="after")
    def check_success(self) -> Self:
        if self.status == MatchingStatus.SUCCESS:
            if self.session is None:
                raise ValueError(
                    "Success status message must include a session object"
                )
        return self

    @model_validator(mode="after")
    def check_non_success(self) -> Self:
        if self.status != MatchingStatus.SUCCESS:
            if self.session is not None:
                raise ValueError(
                    "Non-success status message cannot include a session object"
                )
        return self
