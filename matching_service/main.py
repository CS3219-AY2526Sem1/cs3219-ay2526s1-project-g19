import asyncio
from contextlib import asynccontextmanager
import json
import logging.config
from pathlib import Path
from fastapi import APIRouter, Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uvicorn
import logging
from kafka.kafka_client import kafka_client
from core.security import get_current_user, get_user_from_ws
from schemas.matching import VALID_LANGUAGE_LIST, MatchUserRequestSchema, MatchingCriteriaSchema
from service.redis_controller import redis_controller
from service.matching import matching_service
from service.websocket import websocket_service
from uuid import UUID
from middleware.fixed_prefix import FixedPrefixMiddleware
from config import settings

with open("log_config.json", "r") as f:
    config = json.load(f)
logging.config.dictConfig(config)
logger = logging.getLogger(__name__)

SERVICE_PREFIX = os.getenv("SERVICE_PREFIX", "/matching-service-api")
if SERVICE_PREFIX and not SERVICE_PREFIX.startswith("/"):
    SERVICE_PREFIX = "/" + SERVICE_PREFIX
SERVICE_PREFIX = SERVICE_PREFIX.rstrip("/")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Running events on start...")
    expiry_event_listener = asyncio.create_task(redis_controller.start_expiry_listener())
    session_created_listener = asyncio.create_task(redis_controller.start_session_created_listener())
    yield
    logger.info("Cleaning up events on shutdown...")
    expiry_event_listener.cancel()
    session_created_listener.cancel()
    kafka_client.shutdown()

router = APIRouter(prefix="/api", redirect_slashes=False)
app = FastAPI(
    redirect_slashes=False,
    lifespan=lifespan,
    docs_url="/api/docs"
)
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


async def health_check():
    """Health check endpoint for ALB"""
    return {"status": "healthy"}

app.add_api_route(
    "/health",
    endpoint=health_check,
    methods=["GET"],
    include_in_schema=False,
)


@app.get("/", include_in_schema=False)
async def root_status():
    """Legacy landing endpoint that previously returned 404."""
    return {"ok": True}

router.add_api_route(
    "/health",
    endpoint=health_check,
    methods=["GET"],
    include_in_schema=False,
)


@router.post("/match", status_code=status.HTTP_202_ACCEPTED, responses={
    202: {"description": "Accepted"},
    400: {"description": "WebSocket not connected"},
    409: {"description": "User already in queue"}
})
async def match_users(
    criteria: MatchingCriteriaSchema,
    user_id=Depends(get_current_user)
):
    # check if ws connection is set up
    if not websocket_service.check_ws_connection(user_id=user_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="WebSocket connection required. Please connect to WebSocket before joining queue."
        )
    res = await matching_service.match_user(
        user_id=user_id,
        criteria=criteria
    )
    return res


@router.delete("/match", responses={
    200: {"description": "OK"},
    404: {"description": "User not in queue"}
})
async def cancel_matching(user_id=Depends(get_current_user)):
    if not websocket_service.check_ws_connection(user_id=user_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User {user_id} not in queue"
        )
    logger.info(f"Cancelling match for user {user_id}")
    await websocket_service.close_ws_connection(user_id=user_id)
    return f"Matching for user {user_id} cancelled"


@router.get("/languages", response_model=list[str])
async def get_languages():
    return VALID_LANGUAGE_LIST


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    user_id = await get_user_from_ws(websocket)
    if not user_id:
        return
    logger.info(f"Connecting ws for {user_id}")
    websocket_service.record_ws_connection(user_id=user_id, websocket=websocket)
    await websocket.accept()
    try:
        while True:
            try:
                await websocket.receive_text()
            except (WebSocketDisconnect, RuntimeError):
                break
    finally:
        await redis_controller.remove_from_queue(user_id=user_id)
        await websocket_service.close_ws_connection(user_id=user_id)


app.include_router(router)


if __name__=="__main__":
    logger.info("Starting matching service...")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.environment == "development"
    )
    logger.info("Stopping matching service...")
