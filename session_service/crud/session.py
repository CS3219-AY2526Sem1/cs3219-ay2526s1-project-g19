from datetime import datetime
from uuid import UUID
from sqlmodel import and_, select
from models.session import Session, SessionUser
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload


class SessionRepo:
    def __init__(self):
        self.model = Session

    async def insert(
        self,
        obj: Session,
        db_session: AsyncSession
    ) -> None:
        db_session.add(obj)
        await db_session.commit()
        return

    async def get_active_session(
        self,
        user_id: UUID,
        db_session: AsyncSession
    ) -> Session:
        query = select(
            self.model
        ).join(
            SessionUser,
            self.model.id == SessionUser.session_id
        ).where(
            SessionUser.user_id == user_id,
            self.model.ended_at.is_(None)
        )
        res = await db_session.execute(query)
        return res.scalar_one_or_none()

    async def end_session(
        self,
        session_id: UUID,
        ended_at: datetime,
        db_session: AsyncSession
    ) -> None:
        query = select(
            self.model
        ).where(
            self.model.id == session_id,
            self.model.ended_at.is_(None)
        )
        res = await db_session.execute(query)
        session = res.scalar_one_or_none()
        if not session:
            return
        session.ended_at = ended_at
        db_session.add(session)
        await db_session.commit()
        await db_session.refresh(session)
        return

    async def get_by_user_id(
        self,
        user_id: UUID,
        db_session: AsyncSession,
        size: int = 10,
        page: int = 1
    ) -> list[tuple[Session, UUID]]:
        su1 = aliased(SessionUser)
        su2 = aliased(SessionUser)

        query = select(
            Session,
            su2.user_id
        ).join(
            su1,
            Session.id == su1.session_id
        ).join(
            su2,
            and_(Session.id == su2.session_id, su2.user_id != user_id)
        ).where(
            su1.user_id == user_id
        ).order_by(
            self.model.started_at
        ).limit(
            size
        ).offset(
            page-1
        ).options(
            selectinload(self.model.session_metadata)
        )
        res = await db_session.execute(query)
        return res.all()


class SessionUserRepo:
    def __init__(self):
        self.model = SessionUser

    async def get_by_session_id(
        self,
        session_id: UUID,
        db_session: AsyncSession
    ) -> list[UUID]:
        query = select(
            self.model.user_id
        ).where(
            self.model.session_id == session_id
        )
        res = await db_session.execute(query)
        return res.scalars().all()


session_repo = SessionRepo()
session_user_repo = SessionUserRepo()
