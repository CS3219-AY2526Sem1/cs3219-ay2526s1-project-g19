import time
from dataclasses import dataclass
from typing import Optional

@dataclass
class MessageData:
    """Schema for chat message data."""
    message: str
    username: str
    created_time: Optional[int] = None

    def __post_init__(self):
        if self.created_time is None:
            self.created_time = int(time.time() * 1000)

    def to_dict(self):
        """Convert to dictionary for JSON serialization."""
        return {
            "message": self.message,
            "username": self.username,
            "__createdtime__": self.created_time
        }

    @classmethod
    def from_dict(cls, data: dict):
        """Create MessageData from dictionary."""
        return cls(
            message=data.get("message", ""),
            username=data.get("username", ""),
            created_time=data.get("__createdtime__")
        )