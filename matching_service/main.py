import asyncio
import json
import logging.config
import os
from pathlib import Path
from fastapi import APIRouter, FastAPI, WebSocket, WebSocketDisconnect, status
from fastapi.responses import HTMLResponse
import uvicorn
import logging
from schemas.matching import MatchUserRequestSchema
from service.matching import matching_service
from service.websocket import websocket_service
from uuid import UUID

with open("log_config.json", "r") as f:
    config = json.load(f)
logging.config.dictConfig(config)
logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api"
)
app = FastAPI()


@app.get("/test_ws")
async def get():
    html_file = Path("ws_test/ws_test_screen.html")
    html_content = html_file.read_text(encoding="utf-8")
    return HTMLResponse(content=html_content)


@router.post("/match", status_code=status.HTTP_201_CREATED, responses={
    201: {},
    409: {"description": "User already in queue"}
})
async def match_users(data: MatchUserRequestSchema):
    # check if ws connection is set up
    if not websocket_service.check_ws_connection(user_id=data.user_id):
        return "Error: connect to websocket first"
    res = await matching_service.match_user(
        user_id=data.user_id,
        criteria=data.criteria
    )
    return res


@router.get("/debug/show")
def debug_show():
    return matching_service.debug_show()


@router.websocket("/ws")
async def websocket_endpoint(user_id: UUID, websocket: WebSocket):
    websocket_service.record_ws_connection(user_id=user_id, websocket=websocket)
    await websocket.accept()
    try:
        while True:
            try:
                await websocket.receive_text()
            except WebSocketDisconnect:
                break
    finally:
        await websocket_service.close_ws_connection(user_id=user_id)


@router.post("/flush")
def flush():
    return matching_service.clear_redis()


app.include_router(router)


if __name__=="__main__":
    logger.info("Starting matching service...")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=os.getenv("ENV", "prd") == "dev"
    )
    logger.info("Stopping matching service...")
