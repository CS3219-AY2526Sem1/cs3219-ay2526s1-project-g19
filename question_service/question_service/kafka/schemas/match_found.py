from datetime import datetime
from uuid import UUID
from pydantic import BaseModel


class MatchFound(BaseModel):
    match_id: UUID
    user_id_list: list[UUID]
    topic: str
    difficulty: str
    language: str
    timestamp: datetime
