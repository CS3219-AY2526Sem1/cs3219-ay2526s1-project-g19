import json
import logging
from uuid import UUID
from fastapi import WebSocket
from fastapi.websockets import WebSocketState

from core.redis_client import matching_redis
from schemas.events import SessionCreatedSchema
from schemas.message import MatchingStatus, MatchingEventMessage


logger = logging.getLogger(__name__)


class WebSocketService:
    def __init__(self):
        # Keep local connections for this task instance
        self.ws_connections: dict[UUID, WebSocket] = {}
        # Redis key prefix for tracking active connections across all tasks
        self.redis_key_prefix = "ws:active:"

    def record_ws_connection(
        self,
        user_id: UUID,
        websocket: WebSocket
    ) -> None:
        # Store WebSocket object locally for this task
        self.ws_connections[user_id] = websocket
        # Mark connection as active in Redis with 5 minute TTL
        matching_redis.setex(f"{self.redis_key_prefix}{user_id}", 300, "1")
        logger.info(f"Recorded WebSocket connection for user {user_id}")
        return

    def check_ws_connection(
        self,
        user_id: UUID
    ) -> bool:
        # Check Redis for active connection across all tasks
        is_connected = matching_redis.exists(f"{self.redis_key_prefix}{user_id}") > 0
        logger.info(f"Checking WebSocket for {user_id}: {is_connected}")
        return is_connected

    async def close_ws_connection(
        self,
        user_id: UUID
    ) -> None:
        # Remove from Redis tracking
        matching_redis.delete(f"{self.redis_key_prefix}{user_id}")

        # Close local WebSocket connection if it exists in this task
        if user_id in self.ws_connections:
            logger.info(f"Closing websocket of {user_id}")
            ws = self.ws_connections[user_id]
            if ws.client_state == WebSocketState.CONNECTED:
                await ws.close()
            self.ws_connections.pop(user_id)
        return

    async def send_timeout(
        self,
        user_id: UUID
    ) -> None:
        logger.info(f"Sending timeout message to user {user_id} ")
        message = MatchingEventMessage(status=MatchingStatus.TIMEOUT)
        if user_id in self.ws_connections:
            await self.ws_connections[user_id].send_json(json.loads(message.model_dump_json()))
        return

    async def send_relax_lang(
        self,
        user_id: UUID
    ) -> None:
        logger.info(f"Sending relax language message to user {user_id}")
        message = MatchingEventMessage(status=MatchingStatus.RELAX_LANGUAGE)
        if user_id in self.ws_connections:
            await self.ws_connections[user_id].send_json(json.loads(message.model_dump_json()))
        return

    async def send_session_created(
        self,
        session_created: SessionCreatedSchema
    ):
        logger.info(f"Sending session created message to users {session_created.user_id_list}")
        for user_id in session_created.user_id_list:
            if user_id in self.ws_connections:
                message = MatchingEventMessage(
                    status=MatchingStatus.SUCCESS,
                    session=session_created
                )
                await self.ws_connections[user_id].send_json(
                    json.loads(message.model_dump_json())
                )
                await self.close_ws_connection(user_id=user_id)
        return


websocket_service = WebSocketService()
