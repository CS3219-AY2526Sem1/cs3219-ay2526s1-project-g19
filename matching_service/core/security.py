import logging
from fastapi import Depends, HTTPException, WebSocket, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from uuid import UUID
from config import settings

logger = logging.getLogger(__name__)


security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> UUID:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
        user_id_str = payload.get("user_id")
        if user_id_str is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token missing user_id",
            )
        return UUID(user_id_str)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

async def get_user_from_ws(websocket: WebSocket) -> UUID:
    token = websocket.query_params.get("token")

    if not token:
        await websocket.close(code=1008)
        return None

    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
        user_id_str = payload.get("user_id")
        if not user_id_str:
            await websocket.close(code=1008)
            return None
        return UUID(user_id_str)
    except JWTError:
        await websocket.close(code=1008)
        return None
