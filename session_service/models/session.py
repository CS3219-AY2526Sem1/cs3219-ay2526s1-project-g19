from datetime import datetime
from uuid import UUID, uuid4
from sqlalchemy import Column
from sqlmodel import Field, Relationship, SQLModel
from sqlalchemy.dialects.postgresql import JSONB


class Session(SQLModel, table=True):
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    started_at: datetime = Field(default_factory=datetime.now)
    ended_at: datetime | None = Field(default=None, nullable=True)
    question_id: UUID = Field(nullable=False)
    language: str = Field(nullable=False)

    # Relationships
    session_users: list["SessionUser"] = Relationship(back_populates="session", cascade_delete=True)
    session_metadata: "SessionMetadata" = Relationship(back_populates="session", cascade_delete=True)


class SessionUser(SQLModel, table=True):
    session_id: UUID = Field(foreign_key="session.id", primary_key=True, ondelete="CASCADE")
    user_id: UUID = Field(nullable=False, primary_key=True)

    # Relationships
    session: Session = Relationship(back_populates="session_users")


class SessionMetadata(SQLModel, table=True):
    session_id: UUID = Field(primary_key=True, foreign_key="session.id", ondelete="CASCADE")
    question_title: str = ""
    question_statement_md: str = ""
    topics: list[str] = Field(
        default_factory=list,
        sa_column=Column(
            JSONB,
            nullable=False,
        )
    ) 
    difficulty: str = ""
    company_tags: list[str] = Field(
        default_factory=list,
        sa_column=Column(
            JSONB,
            nullable=False
        )
    )

    # Relationships
    session: Session = Relationship(back_populates="session_metadata")
