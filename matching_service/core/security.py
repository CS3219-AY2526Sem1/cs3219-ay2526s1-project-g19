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
    logger.info(f"Token received: {token}")

    if not token:
        logger.warning("No token provided; rejecting connection")
        await websocket.close(code=1008)
        return None

    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=["HS256"])
        logger.info(f"Decoded JWT payload: {payload}")
        user_id_str = payload.get("user_id")
        if not user_id_str:
            logger.warning("JWT missing user_id; rejecting connection")
            await websocket.close(code=1008)
            return None
        return UUID(user_id_str)
    except JWTError as e:
        logger.error(f"JWT decode failed: {e}")
        await websocket.close(code=1008)
        return None
