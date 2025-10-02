from dataclasses import dataclass
from typing import Optional, Dict, Any
import time

@dataclass
class CodeChangeData:
    """Schema for code change events."""
    code: str
    type: str = "receive"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "type": self.type,
            "code": self.code
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'CodeChangeData':
        """Create CodeChangeData from dictionary."""
        return cls(
            code=data.get("code", ""),
            type=data.get("type", "receive")
        )

@dataclass
class CursorData:
    """Schema for cursor position updates."""
    user_id: str
    line: int = 1
    ch: int = 0
    room: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "userId": self.user_id,
            "line": self.line,
            "ch": self.ch
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any], user_id: str) -> 'CursorData':
        """Create CursorData from dictionary."""
        return cls(
            user_id=user_id,
            line=data.get("line", 1),
            ch=data.get("ch", 0),
            room=data.get("room")
        )

@dataclass
class ErrorData:
    """Schema for error messages."""
    message: str
    error_type: str = "validation_error"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "message": self.message,
            "error_type": self.error_type
        }

@dataclass
class RoomJoinData:
    """Schema for room join events."""
    room: str
    user_id: str
    cached_code: Optional[str] = None

    @classmethod
    def from_request(cls, data: Dict[str, Any], user_id: str) -> 'RoomJoinData':
        """Create RoomJoinData from request data."""
        return cls(
            room=data.get("room", ""),
            user_id=user_id,
            cached_code=None
        )
