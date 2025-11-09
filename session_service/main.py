import json
import logging
import logging.config
import os
from uuid import UUID
from fastapi import APIRouter, Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.security import get_current_user
from sqlalchemy.ext.asyncio import AsyncSession
import uvicorn
from config import settings
from middleware.fixed_prefix import FixedPrefixMiddleware
from models.session import Session
from pg_db.core import get_db_session
from schemas.session import ActiveSessionSchema, SessionHistorySchema
from service.session import session_service


with open("log_config.json", "r") as f:
    config = json.load(f)
logging.config.dictConfig(config)
logger = logging.getLogger(__name__)

SERVICE_PREFIX = os.getenv("SERVICE_PREFIX", "/matching-service-api")
if SERVICE_PREFIX and not SERVICE_PREFIX.startswith("/"):
    SERVICE_PREFIX = "/" + SERVICE_PREFIX
SERVICE_PREFIX = SERVICE_PREFIX.rstrip("/")

router = APIRouter(
    prefix="/api/session",
    redirect_slashes=False
)
app = FastAPI(redirect_slashes=False, docs_url="/api/docs")
allowed_origins = [origin.strip() for origin in os.getenv("CORS_ALLOW_ORIGINS", "*").split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if allowed_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
if SERVICE_PREFIX:
    app.add_middleware(FixedPrefixMiddleware, prefix=SERVICE_PREFIX)


@router.get("", response_model=ActiveSessionSchema | None)
async def get_session(
    user_id=Depends(get_current_user),
    db_session: AsyncSession = Depends(get_db_session)
):
    return await session_service.get_active_session(
        user_id=user_id,
        db_session=db_session
    )


@router.post("/end")
async def end_session(
    session_id: UUID
):
    return await session_service.end_session(
        session_id=session_id
    )


@router.get("/history", response_model=list[SessionHistorySchema])
async def get_history(
    user_id: UUID,
    size: int = 10,
    page: int = 1,
    db_session: AsyncSession = Depends(get_db_session)
):
    return await session_service.get_history(
        user_id=user_id,
        size=size,
        page=page,
        db_session=db_session
    )


app.include_router(router=router)

if __name__=="__main__":
    logger.info("Starting session service...")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.environment == "development"
    )
    logger.info("Stopping session service...")
