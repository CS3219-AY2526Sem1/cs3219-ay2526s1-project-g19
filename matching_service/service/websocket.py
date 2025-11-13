import json
import logging
from uuid import UUID
from fastapi import WebSocket
from fastapi.websockets import WebSocketState

from schemas.events import SessionCreatedSchema
from schemas.message import MatchingStatus, MatchingEventMessage


logger = logging.getLogger(__name__)


class WebSocketService:
    def __init__(self):
        self.ws_connections: dict[UUID, WebSocket] = {}

    def record_ws_connection(
        self,
        user_id: UUID,
        websocket: WebSocket
    ) -> None:
        self.ws_connections[user_id] = websocket
        return

    def check_ws_connection(
        self,
        user_id: UUID
    ) -> bool:
        logger.info(f"Current websocket connections: {self.ws_connections}")
        return user_id in self.ws_connections

    async def close_ws_connection(
        self,
        user_id: UUID
    ) -> None:
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
